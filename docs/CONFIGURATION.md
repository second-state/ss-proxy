# Configuration Guide

This document provides detailed information about ss-proxy configuration options and usage.

English | [简体中文](CONFIGURATION.zh.md)

- [Configuration Guide](#configuration-guide)
  - [Command Line Arguments](#command-line-arguments)
    - [Available Arguments](#available-arguments)
    - [Configuration Priority](#configuration-priority)
  - [Usage Examples](#usage-examples)
    - [1. Using Default Configuration](#1-using-default-configuration)
    - [2. Custom Port and Database Path](#2-custom-port-and-database-path)
    - [3. Using Short Options](#3-using-short-options)
    - [4. Configuration via Environment Variables](#4-configuration-via-environment-variables)
    - [5. Mixed Usage (CLI arguments take precedence over environment variables)](#5-mixed-usage-cli-arguments-take-precedence-over-environment-variables)
    - [6. Running Compiled Binary Directly](#6-running-compiled-binary-directly)
    - [7. View Help Information](#7-view-help-information)
  - [Logging Configuration](#logging-configuration)
    - [Setting Log Level](#setting-log-level)
    - [Log Level Description](#log-level-description)
    - [Advanced Control with RUST\_LOG](#advanced-control-with-rust_log)
  - [Performance Tuning](#performance-tuning)
    - [1. Request Timeout Setting](#1-request-timeout-setting)
    - [2. Database Location](#2-database-location)
    - [3. Network Binding](#3-network-binding)
  - [Production Deployment Recommendations](#production-deployment-recommendations)
    - [1. Using systemd Service (Linux)](#1-using-systemd-service-linux)
    - [2. Using Docker](#2-using-docker)
    - [3. Configuration File Management](#3-configuration-file-management)
  - [Troubleshooting](#troubleshooting)
    - [1. Check Configuration](#1-check-configuration)
    - [2. Enable Verbose Logging](#2-enable-verbose-logging)
    - [3. Test Database Connection](#3-test-database-connection)
    - [4. Check Port Usage](#4-check-port-usage)

## Command Line Arguments

ss-proxy supports configuration via command-line arguments and environment variables.

### Available Arguments

| Argument | Short | Environment Variable | Default | Description |
|----------|-------|---------------------|---------|-------------|
| `--host` | `-H` | `SS_PROXY_HOST` | `0.0.0.0` | Listen address |
| `--port` | `-p` | `SS_PROXY_PORT` | `8080` | Listen port |
| `--db-path` | `-d` | `SS_PROXY_DB_PATH` | `./sessions.db` | Database file path |
| `--timeout` | `-t` | `SS_PROXY_TIMEOUT` | `30` | Request timeout (seconds) |
| `--log-level` | `-l` | `SS_PROXY_LOG_LEVEL` | `info` | Log level (trace/debug/info/warn/error) |
| `--help` | `-h` | - | - | Show help information |
| `--version` | `-V` | - | - | Show version information |

### Configuration Priority

Configuration loading order (highest to lowest priority):

1. Command-line arguments
2. Environment variables
3. Default values

## Usage Examples

### 1. Using Default Configuration

```bash
cargo run --release
```

The server will start at `0.0.0.0:8080` using `./sessions.db` database.

### 2. Custom Port and Database Path

```bash
cargo run --release -- --port 9090 --db-path /data/sessions.db
```

### 3. Using Short Options

```bash
cargo run --release -- -p 9090 -d /data/sessions.db -l debug
```

### 4. Configuration via Environment Variables

```bash
export SS_PROXY_PORT=9090
export SS_PROXY_DB_PATH=/data/sessions.db
export SS_PROXY_LOG_LEVEL=debug
cargo run --release
```

### 5. Mixed Usage (CLI arguments take precedence over environment variables)

```bash
export SS_PROXY_PORT=8080
cargo run --release -- --port 9090  # Actually uses 9090
```

### 6. Running Compiled Binary Directly

```bash
# Build
cargo build --release

# Run
./target/release/ss-proxy --port 9090 --log-level debug

# Or use environment variables
SS_PROXY_PORT=9090 ./target/release/ss-proxy
```

### 7. View Help Information

```bash
cargo run --release -- --help
```

## Logging Configuration

### Setting Log Level

Via `--log-level` argument or `SS_PROXY_LOG_LEVEL` environment variable:

```bash
# Verbose logging
cargo run --release -- --log-level debug

# Show errors only
cargo run --release -- --log-level error

# Using environment variable
SS_PROXY_LOG_LEVEL=trace cargo run --release
```

### Log Level Description

- `trace`: Most detailed logs, includes all details
- `debug`: Debug information for development and troubleshooting
- `info`: General information (default level)
- `warn`: Warning information
- `error`: Error information

### Advanced Control with RUST_LOG

For more fine-grained log control, use the `RUST_LOG` environment variable:

```bash
# Show only ss-proxy debug logs
RUST_LOG=ss_proxy=debug cargo run --release

# Show logs from multiple modules
RUST_LOG=ss_proxy=debug,tower_http=info cargo run --release

# Show trace logs from all dependencies
RUST_LOG=trace cargo run --release
```

## Performance Tuning

### 1. Request Timeout Setting

Adjust timeout based on downstream server response time:

```bash
# Increase timeout to 60 seconds (for slow APIs)
cargo run --release -- --timeout 60

# Reduce timeout to 10 seconds (for fast APIs)
cargo run --release -- --timeout 10
```

### 2. Database Location

Place database on high-performance storage:

```bash
# Use SSD path
cargo run --release -- --db-path /ssd/data/sessions.db

# Use in-memory database (data lost on restart)
cargo run --release -- --db-path :memory:
```

### 3. Network Binding

Choose appropriate bind address based on deployment environment:

```bash
# Local access only
cargo run --release -- --host 127.0.0.1

# Allow access from all network interfaces (production)
cargo run --release -- --host 0.0.0.0

# Bind to specific network interface
cargo run --release -- --host 192.168.1.100
```

## Production Deployment Recommendations

### 1. Using systemd Service (Linux)

Create service file `/etc/systemd/system/ss-proxy.service`:

```ini
[Unit]
Description=SS Proxy Server
After=network.target

[Service]
Type=simple
User=ssProxy
WorkingDirectory=/opt/ss-proxy
Environment="SS_PROXY_PORT=8080"
Environment="SS_PROXY_DB_PATH=/var/lib/ss-proxy/sessions.db"
Environment="SS_PROXY_LOG_LEVEL=info"
ExecStart=/opt/ss-proxy/ss-proxy
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ss-proxy
sudo systemctl start ss-proxy
sudo systemctl status ss-proxy
```

### 2. Using Docker

Create `Dockerfile`:

```dockerfile
FROM rust:1.90 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/ss-proxy /usr/local/bin/
COPY --from=builder /app/migrations /migrations
WORKDIR /data
EXPOSE 8080
CMD ["ss-proxy", "--host", "0.0.0.0", "--port", "8080", "--db-path", "/data/sessions.db"]
```

Run container:

```bash
docker build -t ss-proxy .
docker run -d -p 8080:8080 -v /path/to/data:/data ss-proxy
```

### 3. Configuration File Management

Although ss-proxy doesn't use configuration files, you can manage environment variables via scripts:

Create `config.env`:

```bash
SS_PROXY_HOST=0.0.0.0
SS_PROXY_PORT=8080
SS_PROXY_DB_PATH=/var/lib/ss-proxy/sessions.db
SS_PROXY_TIMEOUT=30
SS_PROXY_LOG_LEVEL=info
```

Use configuration file:

```bash
# Load configuration and run
export $(cat config.env | xargs) && ./ss-proxy
```

## Troubleshooting

### 1. Check Configuration

```bash
# View version and help
./ss-proxy --version
./ss-proxy --help
```

### 2. Enable Verbose Logging

```bash
# Use debug level to see detailed information
./ss-proxy --log-level debug
```

### 3. Test Database Connection

```bash
# Check if database file exists
ls -la sessions.db

# Test database connection
sqlite3 sessions.db 'SELECT COUNT(*) FROM sessions;'
```

### 4. Check Port Usage

```bash
# Linux/macOS
lsof -i :8080

# Or use netstat
netstat -tuln | grep 8080
```
