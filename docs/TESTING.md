# Testing Guide

This document provides detailed information about ss-proxy's test suite, execution methods, and CI/CD configuration.

English | [简体中文](TESTING.zh.md)

- [Testing Guide](#testing-guide)
  - [Prerequisites](#prerequisites)
  - [Test Architecture](#test-architecture)
  - [Running Tests](#running-tests)
    - [Method 1: Using Docker Services (Recommended)](#method-1-using-docker-services-recommended)
    - [Method 2: Manually Manage Services](#method-2-manually-manage-services)
    - [Method 3: Run Individual Test Suites](#method-3-run-individual-test-suites)
  - [Streaming Tests](#streaming-tests)
    - [Test Coverage](#test-coverage)
  - [Test Services](#test-services)
  - [Test Case Details](#test-case-details)
    - [1. HTTP/HTTPS Proxy Tests](#1-httphttps-proxy-tests)
    - [2. WebSocket Proxy Tests](#2-websocket-proxy-tests)
    - [3. Health Check Tests](#3-health-check-tests)
    - [4. Streaming Tests](#4-streaming-tests)
  - [Code Coverage](#code-coverage)
  - [Docker Testing Advantages](#docker-testing-advantages)
  - [CI/CD](#cicd)
    - [Test Workflow (`.github/workflows/test.yml`)](#test-workflow-githubworkflowstestyml)
    - [Build Workflow (`.github/workflows/build.yml`)](#build-workflow-githubworkflowsbuildyml)
  - [Manual Testing](#manual-testing)
    - [Test HTTP Proxy](#test-http-proxy)
    - [Test WebSocket Proxy](#test-websocket-proxy)
    - [Test Streaming](#test-streaming)
  - [Troubleshooting](#troubleshooting)
    - [Test Failure Diagnosis](#test-failure-diagnosis)
    - [Port Conflicts](#port-conflicts)
    - [Clean Test Environment](#clean-test-environment)
  - [Performance Testing](#performance-testing)
    - [Using Apache Bench](#using-apache-bench)
    - [Using wrk](#using-wrk)
    - [Using k6 (Recommended for Complex Scenarios)](#using-k6-recommended-for-complex-scenarios)
  - [Contributing Tests](#contributing-tests)

## Prerequisites

- **Docker and Docker Compose** (for test services)
- **Hurl** (for API testing)
- **Rust Toolchain**

## Test Architecture

ss-proxy uses a multi-layered testing strategy:

1. **Unit Tests**: Test individual functions and modules
2. **Integration Tests**: Test complete HTTP/HTTPS and WebSocket proxy functionality
3. **API Tests**: End-to-end API testing using Hurl
4. **Streaming Tests**: Verify streaming response support (SSE, LLM API, etc.)

## Running Tests

### Method 1: Using Docker Services (Recommended)

This method uses local Docker containers to provide all test dependencies, without relying on unstable external services:

```bash
# Run all tests (automatically start/stop services)
./run_tests.sh

# Or use custom port
TEST_PORT=10086 ./run_tests.sh
```

The test script will:

1. Build the project
2. Start Docker test services (httpbin, json-api, ws-echo)
3. Initialize test database
4. Run Hurl API tests
5. Run Rust integration tests
6. Automatically stop services when complete

### Method 2: Manually Manage Services

```bash
# Start test services
./scripts/start-test-services.sh

# Run tests (skip Docker service management)
USE_DOCKER_SERVICES=false ./run_tests.sh

# Stop test services
./scripts/stop-test-services.sh
```

### Method 3: Run Individual Test Suites

```bash
# Run Rust unit tests only
cargo test

# Run Rust integration tests only (includes HTTP + WebSocket tests)
cargo test --test integration

# Run Hurl HTTP API tests only (requires services running)
hurl --test --variable port=8080 tests/http.hurl

# Run streaming tests
./test_streaming.sh
```

**Note**: WebSocket tests are only available in Rust integration tests (`tests/integration.rs`) because Hurl does not support WebSocket message protocol.

## Streaming Tests

Streaming tests verify ss-proxy's support for streaming responses, including streaming output from LLM APIs (like OpenAI):

```bash
# Run complete streaming test suite
./test_streaming.sh

# Use custom ports
TEST_PROXY_PORT=9090 TEST_MOCK_PORT=10087 ./test_streaming.sh
```

### Test Coverage

- ✅ Non-streaming request forwarding (`stream=false`)
- ✅ Streaming request forwarding (`stream=true`)
- ✅ SSE (Server-Sent Events) format validation
- ✅ Time To First Byte (TTFB) performance testing
- ✅ Integrity verification (all data chunks correctly forwarded)

See: [Streaming Test Documentation](../tests/STREAMING_TEST_README.md)

## Test Services

The test suite uses the following Docker services (all running locally):

| Service | Port | Purpose | Replaces |
|---------|------|---------|----------|
| **httpbin** | 8888 | HTTP test service | httpbin.org |
| **json-api** | 8889 | REST API test service | jsonplaceholder.typicode.com |
| **ws-echo** | 8890 | WebSocket echo service | echo.websocket.org |

All services are automatically managed by `run_tests.sh` when `USE_DOCKER_SERVICES=true` (default).

## Test Case Details

### 1. HTTP/HTTPS Proxy Tests

**Test Files**: `tests/http.hurl`, `tests/integration.rs`

**Test Scenarios**:

- ✅ GET request forwarding
- ✅ POST request forwarding
- ✅ Query parameter preservation
- ✅ Custom headers forwarding
- ✅ Session not found error handling
- ✅ Session unavailable error handling

### 2. WebSocket Proxy Tests

**Test File**: `tests/integration.rs`

**Test Scenarios**:

- ✅ Text message echo
- ✅ Binary message echo
- ✅ Multiple consecutive message forwarding
- ✅ Session not found error handling

### 3. Health Check Tests

**Test Files**: `tests/http.hurl`, `tests/integration.rs`

**Test Scenarios**:

- ✅ `/health` endpoint returns 200 OK

### 4. Streaming Tests

**Test Files**: `tests/streaming_test.hurl`, `test_streaming.sh`

**Test Scenarios**:

- ✅ Non-streaming response forwarding
- ✅ SSE streaming response forwarding
- ✅ Time to first byte testing
- ✅ Data integrity verification

## Code Coverage

Run test coverage analysis:

```bash
# Install tarpaulin (if not installed)
cargo install cargo-tarpaulin

# Generate coverage report
cargo tarpaulin --out Html --output-dir coverage

# View report
open coverage/index.html
```

## Docker Testing Advantages

✅ **Stable**: No dependency on external services
✅ **Fast**: Local network, no internet latency
✅ **Reliable**: Consistent test environment
✅ **Offline**: Can test without internet connection
✅ **CI/CD Ready**: Includes GitHub Actions integration

## CI/CD

The project includes GitHub Actions workflows that automatically:

### Test Workflow (`.github/workflows/test.yml`)

- Runs all tests on push/PR
- Two independent test jobs:
  - `test`: HTTP/HTTPS and WebSocket proxy tests
  - `streaming-test`: Streaming response tests
- Uses service containers for test dependencies
- Caches Rust dependencies to speed up builds

### Build Workflow (`.github/workflows/build.yml`)

- Runs code linting and format checks
- Builds binaries for multiple platforms

## Manual Testing

### Test HTTP Proxy

```bash
# 1. Start proxy server
cargo run --release

# 2. Insert test data in database
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_100', 'https://httpbin.org', 'active');
EOF

# 3. Test requests
curl http://localhost:8080/session_100/get
curl -X POST http://localhost:8080/session_100/post -d '{"test":"data"}'
```

### Test WebSocket Proxy

```bash
# 1. Start proxy server
cargo run --release

# 2. Insert test data in database
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_200', 'wss://echo.websocket.org', 'active');
EOF

# 3. Test with wscat (install: npm install -g wscat)
wscat -c ws://localhost:8080/ws/session_200
```

### Test Streaming

```bash
# 1. Start test services and proxy
./test_streaming.sh

# 2. Manually test streaming endpoint
curl -N http://localhost:8080/session_streaming/stream
```

## Troubleshooting

### Test Failure Diagnosis

1. **Check Docker service status**

   ```bash
   docker-compose -f docker-compose.test.yml ps
   ```

2. **View service logs**

   ```bash
   docker-compose -f docker-compose.test.yml logs httpbin
   docker-compose -f docker-compose.test.yml logs ws-echo
   ```

3. **Manually test services**

   ```bash
   # Test httpbin
   curl http://localhost:8888/get

   # Test ws-echo
   wscat -c ws://localhost:8890
   ```

4. **Enable verbose logging**

   ```bash
   SS_PROXY_LOG_LEVEL=debug ./run_tests.sh
   ```

### Port Conflicts

If default ports are already in use:

```bash
# Use custom port
TEST_PORT=10086 ./run_tests.sh
```

### Clean Test Environment

```bash
# Stop all test services
docker-compose -f docker-compose.test.yml down

# Clean test databases
rm -f test_sessions_*.db

# Clean Docker resources
docker system prune -f
```

## Performance Testing

While the project doesn't include dedicated performance tests, you can use the following tools for benchmarking:

### Using Apache Bench

```bash
# Test HTTP proxy performance
ab -n 1000 -c 10 http://localhost:8080/test-http/get
```

### Using wrk

```bash
# Install wrk
# macOS: brew install wrk
# Ubuntu: sudo apt install wrk

# Run benchmark
wrk -t4 -c100 -d30s http://localhost:8080/test-http/get
```

### Using k6 (Recommended for Complex Scenarios)

```bash
# Install k6
# macOS: brew install k6
# Ubuntu: snap install k6

# Create test script load-test.js
# Run load test
k6 run load-test.js
```

## Contributing Tests

If you're adding new features, please ensure:

1. ✅ Add corresponding unit tests
2. ✅ Add integration tests (if applicable)
3. ✅ Update Hurl test files (if API is affected)
4. ✅ Run complete test suite to ensure passing
5. ✅ Update test documentation

Test file locations:

- Unit tests: In corresponding source files (`#[cfg(test)]` modules)
- Integration tests: `tests/integration.rs`
- API tests: `tests/*.hurl`
- Test data: `tests/fixtures.sql`, `tests/mock-data/`
