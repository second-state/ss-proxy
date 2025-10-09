# ss-proxy

一个使用 SQLite 存储会话信息的代理服务。

## 数据库初始化

### 方式 1：使用 Shell 脚本（推荐）

```bash
# 给脚本添加执行权限
chmod +x init_db.sh

# 执行初始化（默认创建 ./sessions.db）
./init_db.sh

# 或指定自定义数据库路径
./init_db.sh /path/to/custom.db
```

### 方式 2：直接使用 sqlite3 命令

```bash
# 创建数据库并执行初始化脚本
sqlite3 sessions.db < migrations/init.sql

# 或指定自定义路径
sqlite3 /path/to/custom.db < migrations/init.sql
```

## 数据库结构

### sessions 表

| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| `session_id` | TEXT | PRIMARY KEY | 会话ID（主键） |
| `downstream_server_url` | TEXT | NOT NULL | 下游服务器URL |
| `downstream_server_status` | TEXT | NOT NULL | 下游服务器状态 |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| `updated_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | 更新时间 |

### 索引

- `idx_session_status`: 基于 `downstream_server_status` 的索引
- `idx_created_at`: 基于 `created_at` 的索引

## 常用数据库操作

### 交互式操作（推荐）

进入 SQLite 交互式命令行：

```bash
sqlite3 sessions.db
```

在交互式环境中执行操作：

```sql
-- 查询所有会话
SELECT * FROM sessions;

-- 根据 session_id 查询
SELECT * FROM sessions WHERE session_id = 'your-session-id';

-- 查询特定状态的会话
SELECT * FROM sessions WHERE downstream_server_status = 'active';

-- 插入数据
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session-001', 'http://localhost:8080', 'active');

-- 更新数据
UPDATE sessions SET downstream_server_status = 'inactive'
WHERE session_id = 'session-001';

-- 删除数据
DELETE FROM sessions WHERE session_id = 'session-001';

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

**注意**：对于包含复杂 SQL 语句（特别是带逗号的 INSERT/UPDATE 语句），建议使用交互式模式或 SQL 文件方式，以避免 shell 解析问题。

## 开发

```bash
# 构建项目
cargo build

# 运行项目
cargo run
```
