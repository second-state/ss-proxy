# ss-proxy

A high-performance proxy server built with Rust, supporting HTTP/HTTPS and WebSocket protocol forwarding, with SQLite database for session and downstream server management.

English | [简体中文](README.zh.md)

- [ss-proxy](#ss-proxy)
  - [System Requirements](#system-requirements)
  - [Features](#features)
  - [Quick Start](#quick-start)
    - [1. Clone the Repository](#1-clone-the-repository)
    - [2. Initialize Database](#2-initialize-database)
    - [3. Add Test Session](#3-add-test-session)
    - [4. Start Proxy Server](#4-start-proxy-server)
    - [5. Test Proxy](#5-test-proxy)
  - [Quick Examples](#quick-examples)
    - [HTTP Proxy](#http-proxy)
    - [WebSocket Proxy](#websocket-proxy)
  - [Routing Rules](#routing-rules)
  - [Error Handling](#error-handling)
  - [Development Guide](#development-guide)
    - [Code Checking and Formatting](#code-checking-and-formatting)
    - [Common Commands](#common-commands)
    - [Running Tests](#running-tests)
  - [Documentation](#documentation)

## System Requirements

- **Rust**: 1.90.0+ (Edition 2024 support)
- **SQLite**: 3.x
- **OS**: Linux / macOS / Windows

> **Note**: The project uses `rust-toolchain.toml` to automatically manage the Rust version. When you first clone the project, `rustup` will automatically download and install Rust 1.90.0.

## Features

- 🚀 **High-Performance Async Proxy**: Built on Tokio and Axum
- 🔄 **Protocol Support**: HTTP/HTTPS and WebSocket proxying
- 🌊 **Streaming**: Native support for streaming responses (SSE, LLM API, chunked encoding)
- 💾 **Session Management**: SQLite database for session storage
- 🎯 **Dynamic Routing**: Route to different downstream servers based on session_id
- ⚡ **Connection Pooling**: Built-in database and HTTP client connection pools
- 📊 **Health Checks**: Downstream server status validation

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/second-state/ss-proxy.git
cd ss-proxy
```

After entering the project directory, `rustup` will automatically install Rust 1.90.0 (if not already installed).

### 2. Initialize Database

```bash
# Add execute permission and run
chmod +x init_db.sh
./init_db.sh
```

This will create the `./sessions.db` database file. For database structure and detailed operations, see [Database Guide](docs/DATABASE.md).

### 3. Add Test Session

```bash
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_001', 'https://httpbin.org', 'active');
EOF
```

### 4. Start Proxy Server

```bash
# Use default configuration (0.0.0.0:8080)
cargo run --release

# Or customize port
cargo run --release -- --port 9090
```

For more configuration options, see [Configuration Guide](docs/CONFIGURATION.md).

### 5. Test Proxy

```bash
# Test HTTP proxy
curl http://localhost:8080/session_001/get

# Test health check
curl http://localhost:8080/health
```

## Quick Examples

### HTTP Proxy

```bash
curl http://localhost:8080/session_001/get
```

### WebSocket Proxy

```bash
wscat -c ws://localhost:8080/ws/session_001
```

> 💡 **Tip**: Want complete end-to-end examples? Check out the [Complete Tutorial Examples](docs/EXAMPLES.md) with detailed steps and multiple test scenarios.

> 💡 **Tip**: For more examples (POST requests, streaming, query parameters, etc.), see [Routing Rules Guide](docs/ROUTING.md).

## Routing Rules

ss-proxy supports HTTP/HTTPS and WebSocket proxying with different forwarding behaviors:

- **HTTP/HTTPS**: session_id is only used to query the database and does not appear in the downstream URL
- **WebSocket**: session_id is appended to the downstream WebSocket URL path

For detailed routing rules, forwarding behavior, and examples, see [Routing Rules Guide](docs/ROUTING.en.md).

## Error Handling

| HTTP Status Code | Description |
|-----------------|-------------|
| `200-5xx` | Original response from downstream server |
| `404` | session_id does not exist |
| `503` | Downstream server unavailable (status not active) |
| `502` | Cannot connect to downstream server |

## Development Guide

### Code Checking and Formatting

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
# Quick check (without generating binary)
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

### Running Tests

```bash
# Run all tests (recommended)
./run_tests.sh

# Run unit tests only
cargo test

# Run integration tests only
cargo test --test integration
```

For detailed testing guide, see [Testing Documentation](docs/TESTING.md).

## Documentation

- � [Complete Tutorial Examples](docs/EXAMPLES.md) - End-to-end examples and test scenarios
- �📖 [Database Guide](docs/DATABASE.md) - Database structure and operations
- ⚙️ [Configuration Guide](docs/CONFIGURATION.md) - Configuration options and deployment
- 🧪 [Testing Guide](docs/TESTING.md) - Test suite and CI/CD workflows
- 🔀 [Routing Rules Guide](docs/ROUTING.md) - Routing rules and request forwarding behavior
