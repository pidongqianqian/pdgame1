# 像素深渊 - 云房间服务

## 部署步骤

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 创建数据库

```bash
psql -U postgres -c "CREATE DATABASE pdgame;"
```

数据库表会在服务启动时自动创建。

### 3. 配置环境变量

```bash
export DATABASE_URL="postgresql://用户名:密码@localhost:5432/pdgame"
export ROOM_TTL_SECONDS=120   # 房间心跳超时（秒）
```

### 4. 启动服务

```bash
uvicorn main:app --host 0.0.0.0 --port 8080
```

生产环境建议（注意：UDP 中继要求单 worker，不能用多 worker）：

```bash
uvicorn main:app --host 0.0.0.0 --port 8080 --workers 1
```

### 5. 防火墙

确保云服务器开放以下端口：
- **8080** (TCP) — API 服务
- **9000-9399** (UDP) — UDP 中继端口范围（每个房间占 4 个端口，最多支持 100 个并发房间）

### 架构说明

服务由两部分组成，运行在同一进程内：

1. **FastAPI HTTP 服务** — 房间管理 REST API（创建/查询/加入/心跳）
2. **UDP 透明中继** (`udp_relay.py`) — 为每个云房间动态分配 4 个 UDP 端口，在主机和加入者之间透明转发 ENet 数据包，解决 NAT 穿透问题

数据流：
```
加入者 ENet → 中继(BASE+0) → 中继(BASE+1..3) → 主机桥接 → 主机 ENet(:7777)
```

### API 接口

| 方法   | 路径                        | 说明         |
|--------|-----------------------------|--------------|
| GET    | `/api/ping`                 | 健康检查     |
| POST   | `/api/rooms`                | 创建房间     |
| GET    | `/api/rooms`                | 列出房间     |
| GET    | `/api/rooms/{code}`         | 房间详情     |
| PUT    | `/api/rooms/{code}/join`    | 加入房间     |
| PUT    | `/api/rooms/{code}/leave`   | 离开房间     |
| POST   | `/api/rooms/{code}/heartbeat` | 心跳保活   |
| PUT    | `/api/rooms/{code}/status`  | 更新状态     |
| DELETE | `/api/rooms/{code}`         | 删除房间     |
