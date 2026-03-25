"""
像素深渊 - 云房间服务
FastAPI + PostgreSQL
"""

import os
import random
import string
import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone

import asyncpg
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from udp_relay import relay_manager

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/pdgame",
)

ROOM_TTL_SECONDS = int(os.getenv("ROOM_TTL_SECONDS", "120"))
CLEANUP_INTERVAL = 30

pool: asyncpg.Pool | None = None


def _gen_code(length: int = 6) -> str:
    chars = string.ascii_uppercase + string.digits
    return "".join(random.choices(chars, k=length))


async def _cleanup_stale_rooms():
    """periodically remove rooms that haven't sent heartbeat."""
    while True:
        await asyncio.sleep(CLEANUP_INTERVAL)
        if pool is None:
            continue
        cutoff = datetime.now(timezone.utc) - timedelta(seconds=ROOM_TTL_SECONDS)
        stale = await pool.fetch(
            "SELECT room_code FROM rooms WHERE heartbeat < $1", cutoff
        )
        for row in stale:
            relay_manager.destroy(row["room_code"])
        await pool.execute("DELETE FROM rooms WHERE heartbeat < $1", cutoff)
        await relay_manager.cleanup_stale()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)

    with open(os.path.join(os.path.dirname(__file__), "init_db.sql")) as f:
        await pool.execute(f.read())

    task = asyncio.create_task(_cleanup_stale_rooms())
    yield
    task.cancel()
    await pool.close()


app = FastAPI(title="像素深渊 Cloud Rooms", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Models ──────────────────────────────────────────────────────

class CreateRoomReq(BaseModel):
    room_name: str = Field(max_length=64, default="像素深渊")
    host_lan_ip: str = Field(default="", max_length=45)
    host_port: int = Field(default=7777, ge=1024, le=65535)
    max_players: int = Field(default=4, ge=2, le=8)


class RoomOut(BaseModel):
    room_code: str
    room_name: str
    host_ip: str
    host_lan_ip: str
    host_port: int
    max_players: int
    cur_players: int
    status: str
    relay_port: int = 0
    created_at: str


# ── Endpoints ───────────────────────────────────────────────────

@app.post("/api/rooms", response_model=RoomOut, status_code=201)
async def create_room(body: CreateRoomReq, request: Request):
    host_ip = request.headers.get("X-Forwarded-For", request.client.host)
    if "," in host_ip:
        host_ip = host_ip.split(",")[0].strip()

    for _ in range(10):
        code = _gen_code()
        relay_port = await relay_manager.create(code)
        if relay_port is None:
            raise HTTPException(503, "无可用中继端口")
        try:
            row = await pool.fetchrow(
                """INSERT INTO rooms
                   (room_code, room_name, host_ip, host_lan_ip, host_port, max_players, relay_port)
                   VALUES ($1, $2, $3, $4, $5, $6, $7)
                   RETURNING *""",
                code, body.room_name, host_ip, body.host_lan_ip,
                body.host_port, body.max_players, relay_port,
            )
            return _row_to_out(row)
        except asyncpg.UniqueViolationError:
            relay_manager.destroy(code)
            continue

    raise HTTPException(500, "无法生成唯一房间码")


@app.get("/api/rooms", response_model=list[RoomOut])
async def list_rooms():
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=ROOM_TTL_SECONDS)
    rows = await pool.fetch(
        """SELECT * FROM rooms
           WHERE status IN ('waiting', 'playing')
             AND heartbeat >= $1
           ORDER BY created_at DESC
           LIMIT 50""",
        cutoff,
    )
    return [_row_to_out(r) for r in rows]


@app.get("/api/rooms/{code}", response_model=RoomOut)
async def get_room(code: str):
    row = await pool.fetchrow("SELECT * FROM rooms WHERE room_code = $1", code.upper())
    if not row:
        raise HTTPException(404, "房间不存在")
    return _row_to_out(row)


@app.post("/api/rooms/{code}/heartbeat")
async def heartbeat(code: str):
    result = await pool.execute(
        "UPDATE rooms SET heartbeat = NOW() WHERE room_code = $1",
        code.upper(),
    )
    if result == "UPDATE 0":
        raise HTTPException(404, "房间不存在")
    return {"ok": True}


@app.put("/api/rooms/{code}/join")
async def join_room(code: str):
    row = await pool.fetchrow("SELECT * FROM rooms WHERE room_code = $1", code.upper())
    if not row:
        raise HTTPException(404, "房间不存在")
    if row["status"] == "closed":
        raise HTTPException(410, "房间已关闭")
    if row["cur_players"] >= row["max_players"]:
        raise HTTPException(409, "房间已满")
    await pool.execute(
        "UPDATE rooms SET cur_players = cur_players + 1, status = 'waiting' WHERE room_code = $1",
        code.upper(),
    )
    return _row_to_out(
        await pool.fetchrow("SELECT * FROM rooms WHERE room_code = $1", code.upper())
    )


@app.put("/api/rooms/{code}/leave")
async def leave_room(code: str):
    row = await pool.fetchrow("SELECT * FROM rooms WHERE room_code = $1", code.upper())
    if not row:
        raise HTTPException(404, "房间不存在")
    new_count = max(0, row["cur_players"] - 1)
    if new_count == 0:
        relay_manager.destroy(code.upper())
        await pool.execute("DELETE FROM rooms WHERE room_code = $1", code.upper())
    else:
        await pool.execute(
            "UPDATE rooms SET cur_players = $1 WHERE room_code = $2",
            new_count, code.upper(),
        )
    return {"ok": True}


@app.put("/api/rooms/{code}/status")
async def update_status(code: str, request: Request):
    body = await request.json()
    new_status = body.get("status", "waiting")
    if new_status not in ("waiting", "playing", "closed", "offline"):
        raise HTTPException(400, "无效状态")
    if new_status in ("closed", "offline"):
        relay_manager.destroy(code.upper())
    result = await pool.execute(
        "UPDATE rooms SET status = $1, heartbeat = NOW() WHERE room_code = $2",
        new_status, code.upper(),
    )
    if result == "UPDATE 0":
        raise HTTPException(404, "房间不存在")
    return {"ok": True}


@app.delete("/api/rooms/{code}")
async def delete_room(code: str):
    relay_manager.destroy(code.upper())
    await pool.execute("DELETE FROM rooms WHERE room_code = $1", code.upper())
    return {"ok": True}


@app.get("/api/ping")
async def ping():
    return {"pong": True, "time": datetime.now(timezone.utc).isoformat()}


# ── Helpers ─────────────────────────────────────────────────────

def _row_to_out(row) -> dict:
    return {
        "room_code": row["room_code"],
        "room_name": row["room_name"],
        "host_ip": row["host_ip"],
        "host_lan_ip": row.get("host_lan_ip", ""),
        "host_port": row["host_port"],
        "max_players": row["max_players"],
        "cur_players": row["cur_players"],
        "status": row["status"],
        "relay_port": row.get("relay_port", 0),
        "created_at": row["created_at"].isoformat(),
    }
