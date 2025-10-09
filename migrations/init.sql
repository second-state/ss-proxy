-- ss-proxy 数据库初始化脚本
-- 功能：创建 sessions 表用于存储会话和下游服务器信息

-- 创建 sessions 表
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY NOT NULL,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_session_status
ON sessions(downstream_server_status);

-- 创建索引以提高按创建时间查询的性能
CREATE INDEX IF NOT EXISTS idx_created_at
ON sessions(created_at);

-- 显示创建成功的信息
SELECT '✅ sessions 表创建成功' AS status;

-- 显示表结构
.schema sessions
