# ss-proxy

A high-performance proxy server built with Rust, supporting HTTP/HTTPS and WebSocket protocol forwarding, using SQLite database to manage sessions and downstream server information.

- [ss-proxy](#ss-proxy)
  - [📋 System Requirements](#-system-requirements)
  - [✨ Features](#-features)
  - [📦 Quick Start](#-quick-start)
    - [1. Clone the Project](#1-clone-the-project)
    - [2. Initialize Database](#2-initialize-database)
    - [Method 1: Using Shell Script (Recommended)](#method-1-using-shell-script-recommended)
    - [Method 2: Using sqlite3 Command Directly](#method-2-using-sqlite3-command-directly)
  - [Database Structure](#database-structure)
    - [sessions Table](#sessions-table)
    - [Indexes](#indexes)
  - [Common Database Operations](#common-database-operations)
    - [Interactive Operations (Recommended)](#interactive-operations-recommended)
    - [Using SQL Files (Recommended for Batch Operations)](#using-sql-files-recommended-for-batch-operations)
    - [Single-Line Commands (Simple Queries)](#single-line-commands-simple-queries)
  - [🚀 Running the Proxy Server](#-running-the-proxy-server)
    - [Command Line Arguments](#command-line-arguments)
      - [Available Parameters](#available-parameters)
      - [Usage Examples](#usage-examples)
    - [Configuration Priority](#configuration-priority)
    - [Build and Run](#build-and-run)
  - [📖 Usage Examples](#-usage-examples)
    - [1. HTTP/HTTPS Proxy](#1-httphttps-proxy)
    - [2. WebSocket Proxy](#2-websocket-proxy)
    - [3. Health Check](#3-health-check)
  - [🔧 Routing Rules](#-routing-rules)
  - [🛡️ Server Status](#️-server-status)
  - [📊 Error Handling](#-error-handling)
  - [🧪 Testing](#-testing)
    - [Prerequisites](#prerequisites)
    - [Running Tests](#running-tests)
      - [Option 1: With Docker Services (Recommended)](#option-1-with-docker-services-recommended)
      - [Option 2: Manual Service Management](#option-2-manual-service-management)
      - [Option 3: Individual Test Suites](#option-3-individual-test-suites)
    - [Test Services](#test-services)
    - [Benefits of Docker-Based Testing](#benefits-of-docker-based-testing)
    - [CI/CD](#cicd)
  - [📝 Logging](#-logging)
  - [🛠️ Development Guide](#️-development-guide)
    - [Code Linting and Formatting](#code-linting-and-formatting)
    - [Common Commands](#common-commands)

## 📋 System Requirements

- **Rust**: 1.90.0+ (supports Edition 2024)
- **SQLite**: 3.x
- **Operating System**: Linux / macOS / Windows

> **Note**: The project uses `rust-toolchain.toml` to automatically manage the Rust version. When you first clone the project, `rustup` will automatically download and install Rust 1.90.0. See [RUST_TOOLCHAIN.md](./RUST_TOOLCHAIN.md) for details.

## ✨ Features

- 🚀 **High-Performance Async Proxy**: Built on Tokio and Axum
- 🔄 **Protocol Support**: Supports HTTP/HTTPS and WebSocket proxying
- 💾 **Session Management**: Uses SQLite database to store session information
- 🎯 **Dynamic Routing**: Dynamically forwards to different downstream servers based on session_id
- ⚡ **Connection Pooling**: Built-in database connection pool and HTTP client connection pool
- 📊 **Status Check**: Supports downstream server status validation

## 📦 Quick Start

### 1. Clone the Project

```bash
git clone https://github.com/second-state/ss-proxy.git
cd ss-proxy
```

When you enter the project directory, `rustup` will automatically install Rust 1.90.0 (if not already installed).

### 2. Initialize Database

### Method 1: Using Shell Script (Recommended)

```bash
# Add execute permission to the script
chmod +x init_db.sh

# Run initialization (creates ./sessions.db by default)
./init_db.sh

# Or specify a custom database path
./init_db.sh /path/to/custom.db
```

### Method 2: Using sqlite3 Command Directly

```bash
# Create database and execute initialization script
sqlite3 sessions.db < migrations/init.sql

# Or specify a custom path
sqlite3 /path/to/custom.db < migrations/init.sql
```

## Database Structure

### sessions Table

| Field Name | Type | Constraint | Description |
|--------|------|------|------|
| `session_id` | TEXT | PRIMARY KEY | Session ID (Primary Key) |
| `downstream_server_url` | TEXT | NOT NULL | Downstream Server URL |
| `downstream_server_status` | TEXT | NOT NULL | Downstream Server Status |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Creation Time |
| `updated_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Update Time |

### Indexes

- `idx_session_status`: Index based on `downstream_server_status`
- `idx_created_at`: Index based on `created_at`

## Common Database Operations

### Interactive Operations (Recommended)

Enter SQLite interactive command line:

```bash
sqlite3 sessions.db
```

Execute operations in interactive environment:

```sql
-- Query all sessions
SELECT * FROM sessions;

-- Query by session_id
SELECT * FROM sessions WHERE session_id = 'your-session-id';

-- Query sessions with specific status
SELECT * FROM sessions WHERE downstream_server_status = 'active';

-- Insert data
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session-001', 'http://localhost:8080', 'active');

-- Update data
UPDATE sessions SET downstream_server_status = 'inactive'
WHERE session_id = 'session-001';

-- Delete data
DELETE FROM sessions WHERE session_id = 'session-001';

-- Exit
.quit
```

### Using SQL Files (Recommended for Batch Operations)

Create an SQL file (e.g., `query.sql`):

```sql
SELECT * FROM sessions WHERE downstream_server_status = 'active';
```

Execute the SQL file:

```bash
sqlite3 sessions.db < query.sql
```

### Single-Line Commands (Simple Queries)

For simple read-only queries, you can use single-line commands:

```bash
# Query all sessions (using single quotes)
sqlite3 sessions.db 'SELECT * FROM sessions;'

# Count sessions
sqlite3 sessions.db 'SELECT COUNT(*) FROM sessions;'
```

**Note**: For complex SQL statements (especially INSERT/UPDATE statements with commas), it's recommended to use interactive mode or SQL file method to avoid shell parsing issues.

## 🚀 Running the Proxy Server

### Command Line Arguments

ss-proxy supports configuration via command line arguments and environment variables:

#### Available Parameters

| Parameter | Short Option | Environment Variable | Default | Description |
|------|--------|----------|--------|------|
| `--host` | `-H` | `SS_PROXY_HOST` | `0.0.0.0` | Listening address |
| `--port` | `-p` | `SS_PROXY_PORT` | `8080` | Listening port |
| `--db-path` | `-d` | `SS_PROXY_DB_PATH` | `./sessions.db` | Database file path |
| `--timeout` | `-t` | `SS_PROXY_TIMEOUT` | `30` | Request timeout (seconds) |
| `--log-level` | `-l` | `SS_PROXY_LOG_LEVEL` | `info` | Log level (trace/debug/info/warn/error) |
| `--help` | `-h` | - | - | Show help information |
| `--version` | `-V` | - | - | Show version information |

#### Usage Examples

**1. Using Default Configuration**

```bash
cargo run --release
```

**2. Custom Port and Database Path**

```bash
cargo run --release -- --port 9090 --db-path /data/sessions.db
```

**3. Using Short Options**

```bash
cargo run --release -- -p 9090 -d /data/sessions.db -l debug
```

**4. Configuration via Environment Variables**

```bash
export SS_PROXY_PORT=9090
export SS_PROXY_DB_PATH=/data/sessions.db
export SS_PROXY_LOG_LEVEL=debug
cargo run --release
```

**5. Mixed Usage (CLI arguments have higher priority than environment variables)**

```bash
export SS_PROXY_PORT=8080
cargo run --release -- --port 9090  # Actually uses 9090
```

**6. Running Compiled Binary Directly**

```bash
# Compile
cargo build --release

# Run
./target/release/ss-proxy --port 9090 --log-level debug

# Or using environment variables
SS_PROXY_PORT=9090 ./target/release/ss-proxy
```

**7. View Help Information**

```bash
cargo run --release -- --help
```

### Configuration Priority

Configuration loading order (from highest to lowest priority):
1. Command line arguments
2. Environment variables
3. Default values

### Build and Run

```bash
# Build the project
cargo build --release

# Run the server (using default configuration: 0.0.0.0:8080)
cargo run --release
```

## 📖 Usage Examples

### 1. HTTP/HTTPS Proxy

Assuming there's a session in the database:

```sql
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('my-api', 'https://httpbin.org', 'active');
```

Access the proxy:

```bash
# Forward to https://httpbin.org/get
curl http://localhost:8080/my-api/get

# Forward to https://httpbin.org/post
curl -X POST http://localhost:8080/my-api/post -d '{"key":"value"}'

# Forward to https://httpbin.org/anything/path/to/resource
curl http://localhost:8080/my-api/anything/path/to/resource
```

### 2. WebSocket Proxy

Assuming there's a session in the database:

```sql
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('ws-session', 'ws://echo.websocket.org', 'active');
```

Connect to WebSocket:

```bash
# Test using wscat (install with: npm install -g wscat)
wscat -c ws://localhost:8080/ws/ws-session

# Send message
> Hello WebSocket!
< Hello WebSocket!  # Echo
```

### 3. Health Check

```bash
curl http://localhost:8080/health
# Output: OK
```

## 🔧 Routing Rules

| Path Pattern | Description | Example |
|---------|------|------|
| `/health` | Health check endpoint | `GET /health` |
| `/ws/:session_id` | WebSocket proxy | `ws://localhost:8080/ws/session-001` |
| `/:session_id/*path` | HTTP/HTTPS proxy | `http://localhost:8080/session-001/api/data` |

## 🛡️ Server Status

The proxy server checks the status of downstream servers and only forwards requests to servers with the following statuses:

- `active`
- `online`
- `ready`

Other statuses (such as `inactive`) will return `503 Service Unavailable`.

## 📊 Error Handling

| HTTP Status Code | Description |
|------------|------|
| `200-5xx` | Original response from downstream server |
| `404` | session_id does not exist |
| `503` | Downstream server unavailable (status is not active) |
| `502` | Unable to connect to downstream server |

## 🧪 Testing

### Prerequisites

- **Docker and Docker Compose** (for test services)
- **Hurl** (for API testing)
- **Rust toolchain**

### Running Tests

#### Option 1: With Docker Services (Recommended)

This uses local Docker containers for all test dependencies, eliminating reliance on unstable external services:

```bash
# Run all tests with Docker services (automatically starts/stops services)
./run_tests.sh

# Or with custom port
TEST_PORT=10086 ./run_tests.sh
```

The test script will:
1. Build the project
2. Start Docker test services (httpbin, json-api, ws-echo)
3. Initialize the test database
4. Run Hurl API tests
5. Run Rust integration tests
6. Automatically stop services on completion

#### Option 2: Manual Service Management

```bash
# Start test services
./scripts/start-test-services.sh

# Run tests (skips Docker service management)
USE_DOCKER_SERVICES=false ./run_tests.sh

# Stop test services
./scripts/stop-test-services.sh
```

#### Option 3: Individual Test Suites

```bash
# Rust unit tests only
cargo test

# Rust integration tests only (includes HTTP + WebSocket tests)
cargo test --test integration

# Hurl HTTP API tests only (requires services running)
hurl --test --variable port=8080 tests/http.hurl
```

**Note:** WebSocket tests are only available in Rust integration tests (`tests/integration.rs`), as Hurl doesn't support WebSocket message protocol.

### Test Services

The test suite uses the following Docker services (all run locally):

| Service | Port | Purpose | Replaces |
|---------|------|---------|----------|
| **httpbin** | 8888 | HTTP testing service | httpbin.org |
| **json-api** | 8889 | REST API testing service | jsonplaceholder.typicode.com |
| **ws-echo** | 8890 | WebSocket echo service | echo.websocket.org |

All services are automatically managed by `run_tests.sh` when `USE_DOCKER_SERVICES=true` (default).

### Benefits of Docker-Based Testing

✅ **Stable**: No dependency on external services
✅ **Fast**: Local network, no internet latency
✅ **Reliable**: Consistent test environment
✅ **Offline**: Tests work without internet connection
✅ **CI/CD Ready**: GitHub Actions integration included

### CI/CD

The project includes a GitHub Actions workflow (`.github/workflows/test.yml`) that automatically:
- Runs all tests on push/PR
- Uses service containers for test dependencies
- Caches Rust dependencies for faster builds
- Runs linting and formatting checks
- Builds binaries for multiple platforms

## 📝 Logging

Set environment variables to control log level:

```bash
# Detailed logging
RUST_LOG=debug cargo run

# Show errors only
RUST_LOG=error cargo run

# Default (info level)
cargo run
```

## 🛠️ Development Guide

### Code Linting and Formatting

```bash
# Code linting
cargo clippy

# Format code
cargo fmt

# Check formatting (without modifying)
cargo fmt --check
```

### Common Commands

```bash
# Quick check (without building binary)
cargo check

# Development build
cargo build

# Release build (optimized)
cargo build --release

# Run project
cargo run

# Run tests
cargo test

# Clean build artifacts
cargo clean
```
