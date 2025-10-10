# 数据库操作指南

本文档详细介绍 ss-proxy 的数据库结构和常用操作。

[English](DATABASE.md) | 简体中文

- [数据库操作指南](#数据库操作指南)
  - [数据库结构](#数据库结构)
    - [sessions 表](#sessions-表)
    - [索引](#索引)
  - [初始化数据库](#初始化数据库)
    - [方法 1: 使用 Shell 脚本（推荐）](#方法-1-使用-shell-脚本推荐)
    - [方法 2: 直接使用 sqlite3 命令](#方法-2-直接使用-sqlite3-命令)
  - [常用数据库操作](#常用数据库操作)
    - [交互式操作（推荐）](#交互式操作推荐)
    - [使用 SQL 文件（推荐用于批量操作）](#使用-sql-文件推荐用于批量操作)
    - [单行命令（简单查询）](#单行命令简单查询)
  - [会话状态说明](#会话状态说明)
  - [示例：创建测试会话](#示例创建测试会话)
  - [数据维护](#数据维护)
    - [查看表结构](#查看表结构)
    - [备份数据库](#备份数据库)
    - [恢复数据库](#恢复数据库)
  - [性能优化建议](#性能优化建议)

## 数据库结构

### sessions 表

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| `session_id` | TEXT | PRIMARY KEY | 会话 ID（主键） |
| `downstream_server_url` | TEXT | NOT NULL | 下游服务器 URL |
| `downstream_server_status` | TEXT | NOT NULL | 下游服务器状态 |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 更新时间 |

### 索引

- `idx_session_status`: 基于 `downstream_server_status` 的索引
- `idx_created_at`: 基于 `created_at` 的索引

## 初始化数据库

### 方法 1: 使用 Shell 脚本（推荐）

```bash
# 添加脚本执行权限
chmod +x init_db.sh

# 运行初始化（默认创建 ./sessions.db）
./init_db.sh

# 或指定自定义数据库路径
./init_db.sh /path/to/custom.db
```

### 方法 2: 直接使用 sqlite3 命令

```bash
# 创建数据库并执行初始化脚本
sqlite3 sessions.db < migrations/init.sql

# 或指定自定义路径
sqlite3 /path/to/custom.db < migrations/init.sql
```

## 常用数据库操作

### 交互式操作（推荐）

进入 SQLite 交互式命令行：

```bash
sqlite3 sessions.db
```

在交互环境中执行操作：

```sql
-- 查询所有会话
SELECT * FROM sessions;

-- 根据 session_id 查询
SELECT * FROM sessions WHERE session_id = 'session_001';

-- 查询特定状态的会话
SELECT * FROM sessions WHERE downstream_server_status = 'active';

-- 插入数据
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_001', 'http://localhost:8080', 'active');

-- 更新数据
UPDATE sessions SET downstream_server_status = 'inactive'
WHERE session_id = 'session_001';

-- 删除数据
DELETE FROM sessions WHERE session_id = 'session_001';

-- 退出
.quit
```

### 使用 SQL 文件（推荐用于批量操作）

创建 SQL 文件（例如 `query.sql`）：

```sql
SELECT * FROM sessions WHERE downstream_server_status = 'active';
```

执行 SQL 文件：

```bash
sqlite3 sessions.db < query.sql
```

### 单行命令（简单查询）

对于简单的只读查询，可以使用单行命令：

```bash
# 查询所有会话（使用单引号）
sqlite3 sessions.db 'SELECT * FROM sessions;'

# 统计会话数量
sqlite3 sessions.db 'SELECT COUNT(*) FROM sessions;'
```

**注意**: 对于复杂的 SQL 语句（特别是包含逗号的 INSERT/UPDATE 语句），建议使用交互模式或 SQL 文件方式，避免 shell 解析问题。

## 会话状态说明

代理服务器会检查下游服务器的状态，只有以下状态的服务器才会转发请求：

- `active` - 活跃状态
- `online` - 在线状态
- `ready` - 就绪状态

其他状态（如 `inactive`）将返回 `503 Service Unavailable`。

## 示例：创建测试会话

```sql
-- HTTP/HTTPS 会话示例
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_100', 'https://httpbin.org', 'active');

-- WebSocket 会话示例
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_200', 'wss://echo.websocket.org', 'active');
```

## 数据维护

### 查看表结构

```bash
sqlite3 sessions.db '.schema sessions'
```

### 备份数据库

```bash
# 备份数据库
cp sessions.db sessions.db.backup

# 或使用 SQLite 导出
sqlite3 sessions.db '.dump' > sessions_backup.sql
```

### 恢复数据库

```bash
# 从备份恢复
cp sessions.db.backup sessions.db

# 或从 SQL 文件恢复
sqlite3 sessions.db < sessions_backup.sql
```

## 性能优化建议

1. **定期清理过期会话**: 删除不再使用的会话记录
2. **使用索引**: 现有索引已优化常见查询
3. **批量操作**: 使用事务处理大量数据

```sql
-- 批量插入示例
BEGIN TRANSACTION;
INSERT INTO sessions VALUES ('session_001', 'http://backend1.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sessions VALUES ('session_002', 'http://backend2.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sessions VALUES ('session_003', 'http://backend3.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
COMMIT;
```
