# Integration Tests

This directory contains integration tests for the ss-proxy server.

- [Integration Tests](#integration-tests)
  - [Test Structure](#test-structure)
  - [Test Coverage](#test-coverage)
    - [1. Hurl Tests (`*.hurl`)](#1-hurl-tests-hurl)
    - [2. Rust Integration Tests (`integration.rs`)](#2-rust-integration-tests-integrationrs)
  - [WebSocket Testing Strategy](#websocket-testing-strategy)
    - [Why No WebSocket Hurl Tests?](#why-no-websocket-hurl-tests)
    - [Complete WebSocket Coverage via Rust Tests](#complete-websocket-coverage-via-rust-tests)
    - [WebSocket Handshake Example](#websocket-handshake-example)
  - [Test Isolation Architecture](#test-isolation-architecture)
  - [Running Tests](#running-tests)
    - [Option 1: Run All Tests Locally](#option-1-run-all-tests-locally)
    - [Option 2: Run Rust Integration Tests Only](#option-2-run-rust-integration-tests-only)
    - [Option 3: Run Hurl HTTP Tests Only](#option-3-run-hurl-http-tests-only)
  - [CI/CD Integration](#cicd-integration)
  - [Test Data](#test-data)
  - [Requirements](#requirements)
  - [Writing New Tests](#writing-new-tests)
    - [Adding Hurl Tests](#adding-hurl-tests)
    - [Adding Rust Tests](#adding-rust-tests)
  - [Troubleshooting](#troubleshooting)
    - [Server fails to start](#server-fails-to-start)
    - [Tests timeout](#tests-timeout)
    - [Database errors](#database-errors)
  - [External Dependencies](#external-dependencies)

## Test Structure

```console
tests/
├── fixtures.sql          # Test database fixtures
├── http.hurl            # HTTP/HTTPS API tests (Hurl format)
├── integration.rs       # Rust integration tests (comprehensive)
├── mock-data/
│   └── ws-echo.py       # WebSocket echo server for testing
└── README.md           # This file
```

## Test Coverage

### 1. Hurl Tests (`*.hurl`)

Fast API tests using [Hurl](https://hurl.dev/):

**HTTP/HTTPS Tests** (`http.hurl`):

- ✅ Health check endpoint
- ✅ GET requests with query parameters
- ✅ POST requests with JSON body
- ✅ PUT requests
- ✅ DELETE requests
- ✅ Custom headers forwarding
- ✅ Multi-segment paths
- ✅ JSON API proxying (jsonplaceholder)
- ✅ Error cases (404, 503)

**Note:** WebSocket tests are **not** included in Hurl tests because Hurl doesn't support WebSocket message protocol (see WebSocket Testing Strategy below).

### 2. Rust Integration Tests (`integration.rs`)

Comprehensive tests using Rust with **complete test isolation** (each test uses independent server and database):

**HTTP Tests** (8 tests):

- Health check
- HTTP proxy with GET/POST requests
- Query parameters handling
- Custom headers
- Session not found (404)
- Inactive session (503)

**WebSocket Tests** (4 tests):

- Text message echo
- Binary message echo
- Multiple messages sequence
- Session not found error (404)

## WebSocket Testing Strategy

### Why No WebSocket Hurl Tests?

**Hurl doesn't support WebSocket message protocol.**

While Hurl can perform the WebSocket upgrade handshake (HTTP 101 response), it cannot:
- ❌ Send WebSocket frames (text/binary messages)
- ❌ Receive WebSocket frames
- ❌ Properly close WebSocket connections

This causes 300-second timeouts in CI/CD when attempting WebSocket message tests with Hurl.

### Complete WebSocket Coverage via Rust Tests

All WebSocket functionality is thoroughly tested in `integration.rs`:

| Test Function | Coverage |
|--------------|----------|
| `test_websocket_echo` | Text message echo |
| `test_websocket_binary_message` | Binary message handling |
| `test_websocket_multiple_messages` | Message sequences |
| `test_websocket_session_not_found` | Error handling (404) |

These Rust tests use `tokio-tungstenite` which provides **complete WebSocket protocol support**, including:
- ✅ Handshake (HTTP Upgrade)
- ✅ Text frames
- ✅ Binary frames
- ✅ Close frames
- ✅ Ping/Pong frames

### WebSocket Handshake Example

For reference, here's what a WebSocket handshake looks like:

**Request (HTTP):**
```http
GET /ws/test-session-id HTTP/1.1
Host: localhost:8080
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

**Response (HTTP 101):**
```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

After the handshake, the connection switches from HTTP to **WebSocket binary protocol** for bidirectional message exchange. This is what Hurl cannot handle.

## Test Isolation Architecture

Each Rust integration test uses **complete isolation**:

- **Independent server** - Spawned on a unique port (atomic counter starting from 8080)
- **Isolated database** - Separate SQLite file per test (`test_sessions_{port}.db`)
- **Automatic cleanup** - Server process killed and database deleted after test

This ensures:

- ✅ No test interference or state pollution
- ✅ Parallel test execution capability
- ✅ Reliable and reproducible results
- ✅ Fast cleanup without manual intervention

**Implementation:** `TestServer` struct in `integration.rs` with `Drop` trait for automatic cleanup.

## Running Tests

### Option 1: Run All Tests Locally

```bash
./run_tests.sh
```

This script will:

1. Build the project
2. Run Rust integration tests (11 tests with isolated servers)
3. Run Hurl HTTP tests
4. Report results

**Note:** WebSocket Hurl tests are skipped (Hurl limitation).

### Option 2: Run Rust Integration Tests Only

```bash
# Run all integration tests
cargo test --test integration

# Run with verbose output
cargo test --test integration -- --nocapture

# Run specific test
cargo test --test integration test_websocket_echo -- --nocapture

# Run only WebSocket tests
cargo test --test integration websocket -- --nocapture
```

**Note:** Tests use atomic port allocation, so no `TEST_PORT` variable needed.

### Option 3: Run Hurl HTTP Tests Only

```bash
# Start a server manually
./init_db.sh
sqlite3 sessions.db < tests/fixtures.sql
cargo run --release -- --port 8080 &

# Wait for server to start
sleep 3

# Run HTTP tests
hurl --test tests/http.hurl --variable port=8080

# Stop server
killall ss-proxy
```

## CI/CD Integration

Tests are automatically run on GitHub Actions when:

- Code is pushed to any branch
- Pull requests are opened or updated

The workflow:

1. Runs Rust integration tests (complete WebSocket + HTTP coverage)
2. Runs Hurl HTTP tests (HTTP API validation)
3. Provides mock services: httpbin, json-api, ws-echo
4. **Skips WebSocket Hurl tests** (not supported by Hurl)

See `.github/workflows/test.yml` for the complete CI configuration.

Test execution time: **~5 seconds** (vs 300+ seconds with WebSocket Hurl timeouts)

## Test Data

Test sessions are defined in `fixtures.sql`:

| Session ID | Downstream URL | Status | Purpose |
|------------|---------------|--------|---------|
| `test-http` | `https://httpbin.org` | active | HTTP/HTTPS testing |
| `test-json` | `https://jsonplaceholder.typicode.com` | active | JSON API testing |
| `test-ws` | `wss://echo.websocket.org` | active | WebSocket testing |
| `test-inactive` | `https://httpbin.org` | inactive | Error case testing |

## Requirements

- **Rust**: 1.90.0+
- **Hurl**: 5.0.1+ (for Hurl tests)
- **SQLite**: 3.x

Install Hurl:

```bash
# macOS
brew install hurl

# Linux (Ubuntu/Debian)
# Download from https://github.com/Orange-OpenSource/hurl/releases
curl -LO https://github.com/Orange-OpenSource/hurl/releases/download/5.0.1/hurl_5.0.1_amd64.deb
sudo dpkg -i hurl_5.0.1_amd64.deb
```

## Writing New Tests

### Adding Hurl Tests

Edit `http.hurl` to add new HTTP API tests:

```hurl
# New HTTP test
GET http://localhost:8080/test-http/new-endpoint
HTTP 200
[Asserts]
jsonpath "$.result" == "expected"
```

**Note:** Only HTTP tests should be added to Hurl. For WebSocket tests, use Rust integration tests (see below).

### Adding Rust Tests

Edit `integration.rs`:

```rust
#[tokio::test]
async fn test_new_feature() {
    setup_test_server();
    let _guard = ServerGuard;

    let client = reqwest::Client::new();
    let response = client
        .get("http://localhost:8080/test-http/endpoint")
        .send()
        .await
        .expect("Failed to send request");

    assert_eq!(response.status(), 200);
}
```

## Troubleshooting

### Server fails to start

- Check if port 8080 is already in use: `lsof -i :8080`
- Kill existing processes: `killall ss-proxy`

### Tests timeout

- Increase timeout in test code
- Check network connectivity to external services (httpbin.org, echo.websocket.org)

### Database errors

- Re-initialize database: `./init_db.sh && sqlite3 sessions.db < tests/fixtures.sql`
- Check database file permissions

## External Dependencies

Tests rely on these public services:

- **httpbin.org**: HTTP request testing
- **jsonplaceholder.typicode.com**: JSON API testing
- **echo.websocket.org**: WebSocket echo server

If these services are unavailable, some tests may fail.
