# Complete Tutorial Examples

This document provides two complete end-to-end examples demonstrating how to use ss-proxy for HTTP and WebSocket proxying. Each example includes detailed steps that you can follow by copying and pasting the commands.

English | [简体中文](EXAMPLES.zh.md)

- [Complete Tutorial Examples](#complete-tutorial-examples)
  - [Prerequisites](#prerequisites)
    - [System Requirements](#system-requirements)
    - [Install Dependencies](#install-dependencies)
  - [Chapter 1: Complete HTTP Proxy Example](#chapter-1-complete-http-proxy-example)
    - [1.1 Clone and Enter Project](#11-clone-and-enter-project)
    - [1.2 Start Test Services](#12-start-test-services)
    - [1.3 Initialize Database](#13-initialize-database)
    - [1.4 Configure HTTP Session](#14-configure-http-session)
    - [1.5 Build and Start Proxy Server](#15-build-and-start-proxy-server)
    - [1.6 Test HTTP Proxy Features](#16-test-http-proxy-features)
    - [1.7 Cleanup](#17-cleanup)
  - [Chapter 2: Complete WebSocket Proxy Example](#chapter-2-complete-websocket-proxy-example)
    - [2.1 Environment Preparation](#21-environment-preparation)
    - [2.2 Configure WebSocket Session](#22-configure-websocket-session)
    - [2.3 Start Proxy Server (if not running)](#23-start-proxy-server-if-not-running)
    - [2.4 Test WebSocket Connection](#24-test-websocket-connection)
    - [2.5 Cleanup](#25-cleanup)
  - [Troubleshooting](#troubleshooting)
    - [Service Startup Failures](#service-startup-failures)
    - [Proxy Connection Failures](#proxy-connection-failures)
    - [WebSocket Connection Issues](#websocket-connection-issues)

## Prerequisites

### System Requirements

Before starting, ensure your system meets the following requirements:

- **Operating System**: macOS, Linux, or Windows (WSL2)
- **Docker**: 20.10+ and Docker Compose
- **Rust**: 1.90.0+ (will be automatically installed by the project)
- **SQLite**: 3.x
- **Other Tools**: curl, websocat (for WebSocket testing)

### Install Dependencies

```bash
# macOS
brew install docker docker-compose sqlite websocat

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose sqlite3

# Install websocat (WebSocket client)
cargo install websocat

# Verify installation
docker --version
docker-compose --version
sqlite3 --version
websocat --version
```

---

## Chapter 1: Complete HTTP Proxy Example

This example demonstrates how to set up ss-proxy and proxy HTTP requests to a test server.

### 1.1 Clone and Enter Project

```bash
# Clone the project
git clone https://github.com/second-state/ss-proxy.git
cd ss-proxy
```

### 1.2 Start Test Services

We use Docker Compose to start local test services, including httpbin (HTTP testing), json-api, and ws-echo (WebSocket testing).

```bash
# Start all test services
docker compose -f docker-compose.test.yml up -d

# Wait for services to start (about 10-15 seconds)
sleep 15

# Verify service status
docker compose -f docker-compose.test.yml ps
```

**Expected output**:

```
NAME                      COMMAND                  SERVICE   STATUS      PORTS
ss-proxy-test-httpbin     "gunicorn -b 0.0.0.0…"   httpbin   Up          0.0.0.0:8888->80/tcp
ss-proxy-test-json        "json-server -H 0.0.…"   json-api  Up          0.0.0.0:8889->80/tcp
ss-proxy-test-ws          "sh -c 'pip install …"   ws-echo   Up          0.0.0.0:8890->8080/tcp
```

**Verify services are accessible**:

```bash
# Test httpbin service
curl http://localhost:8888/get

# Expected JSON response
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get"
}
```

### 1.3 Initialize Database

```bash
# Add execute permission and run initialization script
chmod +x init_db.sh
./init_db.sh

# Verify database is created
ls -lh sessions.db
```

**Expected output**:

```console
================================================
  ss-proxy Database Initialization Tool
================================================

Database path: ./sessions.db

Executing initialization script...
✅ sessions table created successfully
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY NOT NULL,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_session_status
ON sessions(downstream_server_status);
CREATE INDEX idx_created_at
ON sessions(created_at);

================================================
✅ Database initialization successful!
================================================
```

**View database schema**:

```bash
sqlite3 sessions.db '.schema sessions'
```

**Expected output**:

```sql
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY NOT NULL,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_session_status
ON sessions(downstream_server_status);
CREATE INDEX idx_created_at
ON sessions(created_at);
```

### 1.4 Configure HTTP Session

Add an HTTP session configuration to the database, mapping session_id to our test server.

```bash
# Add HTTP test session
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_http_001', 'http://localhost:8888', 'active');
EOF

# Verify session is added
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_http_001';"
```

**Expected output**:

```console
session_http_001|http://localhost:8888|active|2025-10-11 02:28:26|2025-10-11 02:28:26
```

### 1.5 Build and Start Proxy Server

```bash
# Build project (Release mode for better performance)
cargo build --release

# Start proxy server (default port 8080)
cargo run --release &

# Wait for server to start
sleep 3

# Verify server is running
curl http://localhost:8080/health
```

**Expected output**:

```console
OK
```

### 1.6 Test HTTP Proxy Features

Now we can send HTTP requests through the proxy server.

**Test 1: Simple GET Request**

```bash
# Access /get endpoint through proxy
curl http://localhost:8080/session_http_001/get
```

**Expected output**:

```json
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get"
}
```

**Test 2: GET Request with Query Parameters**

```bash
curl "http://localhost:8080/session_http_001/get?name=Alice&age=30"
```

**Expected output**:

```json
{
  "args": {
    "age": "30",
    "name": "Alice"
  },
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get?name=Alice&age=30"
}
```

**Test 3: POST Request**

```bash
curl -X POST http://localhost:8080/session_http_001/post \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "age": 25
  }'
```

**Expected output**:

```json
{
  "args": {},
  "data": "{\n    \"username\": \"testuser\",\n    \"email\": \"test@example.com\",\n    \"age\": 25\n  }",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "80",
    "Content-Type": "application/json",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "json": {
    "age": 25,
    "email": "test@example.com",
    "username": "testuser"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/post"
}
```

**Test 4: Custom Headers**

```bash
curl http://localhost:8080/session_http_001/headers \
  -H "X-Custom-Header: MyValue" \
  -H "Authorization: Bearer token123"
```

**Expected output**:

```json
{
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Authorization": "Bearer token123",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1",
    "X-Custom-Header": "MyValue"
  }
}
```

**Test 5: Streaming Response**

```bash
# Test streaming (simulating SSE or LLM API)
curl http://localhost:8080/session_http_001/stream/10
```

**Expected output**: You will see data streaming line by line rather than all at once.

```console
2025-10-11T02:38:37.142132Z  INFO ss_proxy::proxy::http_proxy: Forwarding request to: GET http://localhost:8888/stream/10
2025-10-11T02:38:37.159392Z  INFO ss_proxy::proxy::http_proxy: Received response from downstream server: 200 OK
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 0}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 1}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 2}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 3}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 4}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 5}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 6}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 7}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 8}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 9}
```

**Test 6: Different HTTP Methods**

```bash
# PUT request
curl -X PUT http://localhost:8080/session_http_001/put \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'

# DELETE request
curl -X DELETE http://localhost:8080/session_http_001/delete

# PATCH request
curl -X PATCH http://localhost:8080/session_http_001/patch \
  -H "Content-Type: application/json" \
  -d '{"key": "updated"}'
```

**Test 7: Error Handling**

```bash
# Test non-existent session
curl http://localhost:8080/non-existent-session/get
```

**Expected output**: Session not found or similar error

```console
Session not found: non-existent-session - no rows returned by a query that expected to return at least one row
```

### 1.7 Cleanup

After testing, clean up all services and resources.

```bash
# Stop proxy server
pkill -f "ss-proxy" || killall ss-proxy

# Stop and remove test services
docker compose -f docker-compose.test.yml down

# (Optional) Delete test database
rm sessions.db

# Verify cleanup
docker ps | grep ss-proxy-test  # Should return no output
```

**🎉 Congratulations! You have successfully completed the HTTP proxy example!**

---

## Chapter 2: Complete WebSocket Proxy Example

This example demonstrates how to use ss-proxy to proxy WebSocket connections.

### 2.1 Environment Preparation

If you completed Chapter 1, the test services should already be running. If not, execute:

```bash
# Ensure you're in the project root directory
cd ss-proxy

# Start test services (if not already started)
docker compose -f docker-compose.test.yml up -d

# Wait for services to be ready
sleep 15

# Verify WebSocket echo service is running
docker ps | grep ss-proxy-test-ws
```

**Initialize database (if not already initialized)**:

```bash
chmod +x init_db.sh
./init_db.sh
```

### 2.2 Configure WebSocket Session

```bash
# Add WebSocket test session
sqlite3 sessions.db <<EOF
INSERT OR REPLACE INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_ws_001', 'ws://localhost:8890', 'active');
EOF

# Verify session is added
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_ws_001';"
```

**Expected output**:

```console
session_ws_001|ws://localhost:8890|active|2025-10-11 02:43:22|2025-10-11 02:43:22
```

### 2.3 Start Proxy Server (if not running)

```bash
# Check if proxy server is running
curl http://localhost:8080/health 2>/dev/null || {
    echo "Proxy server is not running, starting..."
    cargo run --release &
    sleep 3
}

# Verify server is running
curl http://localhost:8080/health
```

**Expected output**:

```console
OK
```

### 2.4 Test WebSocket Connection

We will use the `websocat` tool to test WebSocket connections.

**Test 1: Simple Echo Test**

```bash
# Open WebSocket connection and send messages
# Note: This is an interactive session
websocat ws://localhost:8080/ws/session_ws_001
```

After starting, you can type any text and the server will echo it back.

**Interactive example**:

```console
After connection is established, type:
> Hello WebSocket!

Expected output:
< Hello WebSocket!

Type:
> {"type": "message", "data": "test"}

Expected output:
< {"type": "message", "data": "test"}

Press Ctrl+C to exit
```

**Test 2: Send Message from Script**

```bash
# Send single message and receive response
# Note: sleep is needed to wait for server response
(echo "Test message from script"; sleep 0.5) | websocat ws://localhost:8080/ws/session_ws_001
```

**Expected output**:

```console
Test message from script
```

**Test 3: Send Multiple Messages**

Create a test script:

```bash
# Create test message file
cat > /tmp/ws-test-messages.txt <<EOF
Message 1: Hello
Message 2: WebSocket
Message 3: Proxy
Message 4: Test
EOF

# Send all messages through WebSocket
# Note: sleep is added to wait for all responses
(cat /tmp/ws-test-messages.txt; sleep 1) | websocat ws://localhost:8080/ws/session_ws_001
```

**Expected output**:

```console
Message 1: Hello
Message 2: WebSocket
Message 3: Proxy
Message 4: Test
```

**Test 4: Test JSON Message**

```bash
# Send JSON formatted message
(echo '{"action": "ping", "timestamp": 1234567890}'; sleep 0.5) | \
  websocat ws://localhost:8080/ws/session_ws_001
```

**Expected output**:

```json
{"action": "ping", "timestamp": 1234567890}
```

**Test 5: Test WebSocket Upgrade with curl**

```bash
# Test WebSocket handshake (HTTP upgrade)
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  http://localhost:8080/ws/session_ws_001
```

**Expected output**:

```console
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: ...
```

**Test 6: Long Connection Test**

```bash
# Test long-running connection
# Send one message per second for 10 seconds
(
  for i in {1..10}; do
    echo "Message at second $i"
    sleep 1
  done
) | websocat ws://localhost:8080/ws/session_ws_001
```

**Expected output**: You will receive one echoed message per second for 10 seconds.

**Test 7: Error Handling**

```bash
# Test non-existent session
echo "Test" | websocat ws://localhost:8080/ws/invalid-session 2>&1

# Expected output: Connection failure or error message
```

### 2.5 Cleanup

```bash
# Stop proxy server
pkill -f "ss-proxy" || killall ss-proxy

# Stop test services
docker-compose -f docker-compose.test.yml down

# Clean up temporary files
rm -f /tmp/ws-test-messages.txt

# (Optional) Delete test database
rm -f sessions.db

# Verify cleanup
docker ps | grep ss-proxy-test  # Should return no output
```

**🎉 Congratulations! You have successfully completed the WebSocket proxy example!**

---

## Troubleshooting

### Service Startup Failures

**Issue**: Docker services fail to start

```bash
# Check if Docker is running
docker info

# View service logs
docker-compose -f docker-compose.test.yml logs

# Check port usage
lsof -i :8888
lsof -i :8889
lsof -i :8890

# Force restart services
docker-compose -f docker-compose.test.yml down
docker-compose -f docker-compose.test.yml up -d --force-recreate
```

### Proxy Connection Failures

**Issue**: Cannot connect to proxy server

```bash
# Check if proxy server is running
ps aux | grep ss-proxy

# Check port listening
lsof -i :8080
netstat -an | grep 8080

# View proxy server logs
# (If running in foreground, you can see logs directly)

# Restart proxy
pkill -f ss-proxy
cargo run --release &
```

**Issue**: Session not found error

```bash
# Verify session configuration
sqlite3 sessions.db "SELECT * FROM sessions;"

# Check session_id spelling
# Ensure session_id in URL exactly matches the database
```

### WebSocket Connection Issues

**Issue**: websocat command not found

```bash
# Install websocat
cargo install websocat

# Or use npm to install wscat
npm install -g wscat

# Test with wscat
wscat -c ws://localhost:8080/ws/session_ws_001
```

**Issue**: WebSocket connection closes immediately

```bash
# Check downstream WebSocket service
docker logs ss-proxy-test-ws

# Test downstream service directly
websocat ws://localhost:8890

# If direct connection succeeds, issue may be in proxy configuration
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_ws_001';"
```

---

**Related Documentation**:

- [README](../README.md) - Project overview
- [Configuration Guide](CONFIGURATION.md) - Detailed configuration instructions
- [Database Operations](DATABASE.md) - Database management
- [Routing Rules](ROUTING.md) - Routing configuration
- [Testing Guide](TESTING.md) - Test suite description
