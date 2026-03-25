"""
UDP 透明中继 — 为每个云房间提供 NAT 穿透能力

每个房间分配 4 个连续 UDP 端口 (PORTS_PER_ROOM):
  BASE+0  : 客户端接入端口 — 所有加入者的 ENet 流量到达此端口
  BASE+1/2/3 : 主机隧道端口 — 每个加入者对应一条隧道

转发逻辑:
  加入者 → BASE+0 → relay → BASE+1+ch → 主机桥接 → localhost:7777 ENet
  localhost:7777 → 主机桥接 → BASE+1+ch → relay → BASE+0 → 加入者
"""

import asyncio
import logging
import time
from typing import Optional

logger = logging.getLogger("udp_relay")

RELAY_PORT_MIN = 9000
RELAY_PORT_MAX = 9400
PORTS_PER_ROOM = 4
MAX_CLIENTS_PER_ROOM = PORTS_PER_ROOM - 1


# ── asyncio DatagramProtocol 实现 ─────────────────────────────

class _ClientProtocol(asyncio.DatagramProtocol):
    """客户端接入端口 (BASE+0) 的协议"""

    def __init__(self, relay: "RoomRelay"):
        self._relay = relay
        self.transport: Optional[asyncio.DatagramTransport] = None

    def connection_made(self, transport: asyncio.DatagramTransport):
        self.transport = transport

    def datagram_received(self, data: bytes, addr: tuple):
        self._relay._on_client_packet(data, addr)

    def error_received(self, exc: Exception):
        logger.warning("client-port error: %s", exc)


class _TunnelProtocol(asyncio.DatagramProtocol):
    """主机隧道端口 (BASE+1/2/3) 的协议"""

    def __init__(self, relay: "RoomRelay", index: int):
        self._relay = relay
        self._index = index
        self.transport: Optional[asyncio.DatagramTransport] = None

    def connection_made(self, transport: asyncio.DatagramTransport):
        self.transport = transport

    def datagram_received(self, data: bytes, addr: tuple):
        self._relay._on_tunnel_packet(data, addr, self._index)

    def error_received(self, exc: Exception):
        logger.warning("tunnel-%d error: %s", self._index, exc)


# ── 单个房间的中继 ────────────────────────────────────────────

class RoomRelay:
    def __init__(self, room_code: str, base_port: int):
        self.room_code = room_code
        self.base_port = base_port
        self.last_activity = time.time()

        self._client_transport: Optional[asyncio.DatagramTransport] = None
        self._tunnel_transports: dict[int, asyncio.DatagramTransport] = {}

        # channel → host bridge 的 NAT 地址 (ip, port)
        self._host_addrs: dict[int, tuple] = {}
        # client addr → channel index
        self._client_to_ch: dict[tuple, int] = {}
        # channel index → client addr
        self._ch_to_client: dict[int, tuple] = {}
        self._next_ch: int = 0

    async def start(self):
        loop = asyncio.get_running_loop()

        t, _ = await loop.create_datagram_endpoint(
            lambda: _ClientProtocol(self),
            local_addr=("0.0.0.0", self.base_port),
        )
        self._client_transport = t

        for i in range(MAX_CLIENTS_PER_ROOM):
            port = self.base_port + 1 + i
            t, _ = await loop.create_datagram_endpoint(
                lambda idx=i: _TunnelProtocol(self, idx),
                local_addr=("0.0.0.0", port),
            )
            self._tunnel_transports[i] = t

        logger.info(
            "room %s  relay UP  ports %d-%d",
            self.room_code,
            self.base_port,
            self.base_port + MAX_CLIENTS_PER_ROOM,
        )

    def stop(self):
        if self._client_transport:
            self._client_transport.close()
            self._client_transport = None
        for t in self._tunnel_transports.values():
            t.close()
        self._tunnel_transports.clear()
        logger.info("room %s  relay DOWN", self.room_code)

    # ── 转发逻辑 ──────────────────────────────────────────────

    def _on_client_packet(self, data: bytes, addr: tuple):
        """客户端 → 中继 → 主机桥接"""
        self.last_activity = time.time()

        if addr not in self._client_to_ch:
            if self._next_ch >= MAX_CLIENTS_PER_ROOM:
                return
            ch = self._next_ch
            self._next_ch += 1
            self._client_to_ch[addr] = ch
            self._ch_to_client[ch] = addr
            logger.info("room %s  client %s → ch %d", self.room_code, addr, ch)

        ch = self._client_to_ch[addr]
        host_addr = self._host_addrs.get(ch)
        tunnel = self._tunnel_transports.get(ch)
        if host_addr and tunnel:
            tunnel.sendto(data, host_addr)

    def _on_tunnel_packet(self, data: bytes, addr: tuple, channel: int):
        """主机桥接 → 中继 → 客户端"""
        self.last_activity = time.time()
        self._host_addrs[channel] = addr

        client_addr = self._ch_to_client.get(channel)
        if client_addr and self._client_transport:
            self._client_transport.sendto(data, client_addr)


# ── 全局管理器 ────────────────────────────────────────────────

class RelayManager:
    def __init__(self):
        self._available: list[int] = list(
            range(RELAY_PORT_MIN, RELAY_PORT_MAX, PORTS_PER_ROOM)
        )
        self._rooms: dict[str, RoomRelay] = {}

    async def create(self, room_code: str) -> Optional[int]:
        if room_code in self._rooms:
            return self._rooms[room_code].base_port
        if not self._available:
            logger.error("no relay ports available")
            return None

        base = self._available.pop(0)
        relay = RoomRelay(room_code, base)
        try:
            await relay.start()
        except OSError as exc:
            logger.error("bind failed port %d: %s", base, exc)
            self._available.append(base)
            self._available.sort()
            return None

        self._rooms[room_code] = relay
        return base

    def destroy(self, room_code: str):
        relay = self._rooms.pop(room_code, None)
        if relay:
            relay.stop()
            self._available.append(relay.base_port)
            self._available.sort()

    async def cleanup_stale(self, timeout: float = 180.0):
        now = time.time()
        stale = [
            code
            for code, r in self._rooms.items()
            if now - r.last_activity > timeout
        ]
        for code in stale:
            logger.info("stale relay cleaned: %s", code)
            self.destroy(code)

    @property
    def active_count(self) -> int:
        return len(self._rooms)


relay_manager = RelayManager()
