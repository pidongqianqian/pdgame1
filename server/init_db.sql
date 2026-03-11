CREATE TABLE IF NOT EXISTS rooms (
    id          SERIAL PRIMARY KEY,
    room_code   VARCHAR(6)  UNIQUE NOT NULL,
    room_name   VARCHAR(64) NOT NULL,
    host_ip     VARCHAR(45) NOT NULL,
    host_lan_ip VARCHAR(45) NOT NULL DEFAULT '',
    host_port   INTEGER     NOT NULL DEFAULT 7777,
    max_players INTEGER     NOT NULL DEFAULT 4,
    cur_players INTEGER     NOT NULL DEFAULT 1,
    status      VARCHAR(16) NOT NULL DEFAULT 'waiting',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    heartbeat   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms (status);
CREATE INDEX IF NOT EXISTS idx_rooms_heartbeat ON rooms (heartbeat);
