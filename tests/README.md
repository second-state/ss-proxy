# Integration Tests

This directory contains integration tests for the ss-proxy server.

- [Integration Tests](#integration-tests)
  - [Test Structure](#test-structure)
  - [Test Coverage](#test-coverage)
    - [1. Hurl Tests (`*.hurl`)](#1-hurl-tests-hurl)
    - [2. Rust Integration Tests (`integration.rs`)](#2-rust-integration-tests-integrationrs)
  - [Running Tests](#running-tests)
    - [Option 1: Run All Tests Locally](#option-1-run-all-tests-locally)
    - [Option 2: Run Rust Integration Tests Only](#option-2-run-rust-integration-tests-only)
    - [Option 3: Run Hurl Tests Only](#option-3-run-hurl-tests-only)
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
├── websocket.hurl       # WebSocket handshake tests (Hurl format)
├── integration.rs       # Rust integration tests (comprehensive)
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

**WebSocket Tests** (`websocket.hurl`):

- ✅ WebSocket upgrade handshake
- ✅ Error cases (session not found, inactive session)

### 2. Rust Integration Tests (`integration.rs`)

Comprehensive tests using Rust:

**HTTP Tests**:

- Health check
- HTTP proxy with GET/POST requests
- Query parameters handling
- Custom headers
- Session not found (404)
- Inactive session (503)

**WebSocket Tests**:

- Text message echo
- Binary message echo
- Multiple messages
- Connection errors

## Running Tests

### Option 1: Run All Tests Locally

```bash
./run_tests.sh
```

This script will:

1. Build the project
2. Initialize test database
3. Start the server
4. Run Hurl tests
5. Run Rust integration tests
6. Clean up

### Option 2: Run Rust Integration Tests Only

```bash
# Run with default port 8080
cargo test --test integration -- --test-threads=1

# Run with custom port (if 8080 is occupied)
TEST_PORT=9090 cargo test --test integration -- --test-threads=1

# Run with verbose output
TEST_PORT=9090 cargo test --test integration -- --test-threads=1 --nocapture

# Run specific test
TEST_PORT=9090 cargo test --test integration test_health_check -- --nocapture
```

**Note**: The `TEST_PORT` environment variable allows you to use a different port if 8080 is already occupied.

### Option 3: Run Hurl Tests Only

```bash
# 1. Start the server
./init_db.sh
sqlite3 sessions.db < tests/fixtures.sql
cargo run --release -- --port 8080 &

# 2. Wait for server to start
sleep 3

# 3. Run tests
hurl --test tests/http.hurl
hurl --test tests/websocket.hurl

# 4. Stop server
killall ss-proxy
```

## CI/CD Integration

Tests are automatically run on GitHub Actions when:

- Code is pushed to `main`, `dev`, or feature branches
- Pull requests are opened or updated

See `.github/workflows/test.yml` for the complete CI configuration.

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

Edit `http.hurl` or `websocket.hurl`:

```hurl
# New HTTP test
GET http://localhost:8080/test-http/new-endpoint
HTTP 200
[Asserts]
jsonpath "$.result" == "expected"
```

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
