# Database Guide

This document provides detailed information about ss-proxy's database structure and common operations.

English | [简体中文](DATABASE.zh.md)

- [Database Guide](#database-guide)
  - [Database Structure](#database-structure)
    - [sessions Table](#sessions-table)
    - [Indexes](#indexes)
  - [Initialize Database](#initialize-database)
    - [Method 1: Using Shell Script (Recommended)](#method-1-using-shell-script-recommended)
    - [Method 2: Direct sqlite3 Command](#method-2-direct-sqlite3-command)
  - [Common Database Operations](#common-database-operations)
    - [Interactive Mode (Recommended)](#interactive-mode-recommended)
    - [Using SQL Files (Recommended for Batch Operations)](#using-sql-files-recommended-for-batch-operations)
    - [Single-Line Commands (Simple Queries)](#single-line-commands-simple-queries)
  - [Session Status Description](#session-status-description)
  - [Example: Creating Test Sessions](#example-creating-test-sessions)
  - [Data Maintenance](#data-maintenance)
    - [View Table Structure](#view-table-structure)
    - [Backup Database](#backup-database)
    - [Restore Database](#restore-database)
  - [Performance Optimization Tips](#performance-optimization-tips)

## Database Structure

### sessions Table

| Field | Type | Constraint | Description |
|-------|------|-----------|-------------|
| `session_id` | TEXT | PRIMARY KEY | Session ID (primary key) |
| `downstream_server_url` | TEXT | NOT NULL | Downstream server URL |
| `downstream_server_status` | TEXT | NOT NULL | Downstream server status |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation time |
| `updated_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update time |

### Indexes

- `idx_session_status`: Index on `downstream_server_status`
- `idx_created_at`: Index on `created_at`

## Initialize Database

### Method 1: Using Shell Script (Recommended)

```bash
# Add execute permission
chmod +x init_db.sh

# Run initialization (creates ./sessions.db by default)
./init_db.sh

# Or specify custom database path
./init_db.sh /path/to/custom.db
```

### Method 2: Direct sqlite3 Command

```bash
# Create database and execute initialization script
sqlite3 sessions.db < migrations/init.sql

# Or specify custom path
sqlite3 /path/to/custom.db < migrations/init.sql
```

## Common Database Operations

### Interactive Mode (Recommended)

Enter SQLite interactive command line:

```bash
sqlite3 sessions.db
```

Execute operations in interactive mode:

```sql
-- Query all sessions
SELECT * FROM sessions;

-- Query by session_id
SELECT * FROM sessions WHERE session_id = 'session_001';

-- Query sessions with specific status
SELECT * FROM sessions WHERE downstream_server_status = 'active';

-- Insert data
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_001', 'http://localhost:8080', 'active');

-- Update data
UPDATE sessions SET downstream_server_status = 'inactive'
WHERE session_id = 'session_001';

-- Delete data
DELETE FROM sessions WHERE session_id = 'session_001';

-- Exit
.quit
```

### Using SQL Files (Recommended for Batch Operations)

Create an SQL file (e.g., `query.sql`):

```sql
SELECT * FROM sessions WHERE downstream_server_status = 'active';
```

Execute SQL file:

```bash
sqlite3 sessions.db < query.sql
```

### Single-Line Commands (Simple Queries)

For simple read-only queries, use single-line commands:

```bash
# Query all sessions (using single quotes)
sqlite3 sessions.db 'SELECT * FROM sessions;'

# Count sessions
sqlite3 sessions.db 'SELECT COUNT(*) FROM sessions;'
```

**Note**: For complex SQL statements (especially INSERT/UPDATE with commas), use interactive mode or SQL file method to avoid shell parsing issues.

## Session Status Description

The proxy server checks downstream server status and only forwards requests to servers with the following statuses:

- `active` - Active status
- `online` - Online status
- `ready` - Ready status

Other statuses (like `inactive`) will return `503 Service Unavailable`.

## Example: Creating Test Sessions

```sql
-- HTTP/HTTPS session example
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_100', 'https://httpbin.org', 'active');

-- WebSocket session example
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_200', 'wss://echo.websocket.org', 'active');
```

## Data Maintenance

### View Table Structure

```bash
sqlite3 sessions.db '.schema sessions'
```

### Backup Database

```bash
# Backup database
cp sessions.db sessions.db.backup

# Or use SQLite export
sqlite3 sessions.db '.dump' > sessions_backup.sql
```

### Restore Database

```bash
# Restore from backup
cp sessions.db.backup sessions.db

# Or restore from SQL file
sqlite3 sessions.db < sessions_backup.sql
```

## Performance Optimization Tips

1. **Regular cleanup of expired sessions**: Delete session records no longer in use
2. **Use indexes**: Existing indexes optimize common queries
3. **Batch operations**: Use transactions for large data operations

```sql
-- Batch insert example
BEGIN TRANSACTION;
INSERT INTO sessions VALUES ('session_001', 'http://backend1.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sessions VALUES ('session_002', 'http://backend2.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
INSERT INTO sessions VALUES ('session_003', 'http://backend3.com', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
COMMIT;
```
