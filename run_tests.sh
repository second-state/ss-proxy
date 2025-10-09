#!/bin/bash

# Test helper script for local testing
# Run integration tests locally before pushing to GitHub

set -e

# Get port from environment variable or use default
PORT=${TEST_PORT:-8080}

echo "🧪 SS-Proxy Local Test Suite"
echo "================================"
echo "Test port: $PORT"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Hurl is installed
if ! command -v hurl &> /dev/null; then
    echo -e "${YELLOW}⚠️  Hurl not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install hurl
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Please install Hurl from: https://hurl.dev/docs/installation.html"
        exit 1
    fi
fi

# Clean up any existing server process
cleanup() {
    if [ ! -z "$SERVER_PID" ]; then
        echo -e "${YELLOW}🛑 Stopping server (PID: $SERVER_PID)${NC}"
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    rm -f /tmp/ss-proxy.pid
}

trap cleanup EXIT

echo ""
echo "📦 Step 1: Building project..."
cargo build --release

echo ""
echo "🗄️  Step 2: Initializing test database..."
./init_db.sh
sqlite3 sessions.db < tests/fixtures.sql

# Verify test data was loaded
TEST_SESSION_COUNT=$(sqlite3 sessions.db "SELECT COUNT(*) FROM sessions WHERE session_id LIKE 'test-%';")
echo -e "${GREEN}✅ Database initialized with $TEST_SESSION_COUNT test sessions${NC}"

# Add a small delay to ensure database file is fully synced
sleep 1

echo ""
echo "🚀 Step 3: Starting server..."
./target/release/ss-proxy --port $PORT --log-level debug &
SERVER_PID=$!
echo $SERVER_PID > /tmp/ss-proxy.pid
echo -e "${GREEN}Server started with PID: $SERVER_PID on port $PORT${NC}"

# Wait for server to be ready
echo ""
echo "⏳ Waiting for server to be ready..."
for i in {1..30}; do
    if curl -f http://localhost:$PORT/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Server is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Server failed to start${NC}"
        exit 1
    fi
    sleep 1
done

# Additional verification: check if test sessions are loaded in database
echo ""
echo "🔍 Verifying test sessions in database..."
sleep 1  # Give the server a moment to fully establish database connections
DB_TEST_SESSIONS=$(sqlite3 sessions.db "SELECT COUNT(*) FROM sessions WHERE session_id LIKE 'test-%' AND downstream_server_status = 'active';")
if [ "$DB_TEST_SESSIONS" -lt 3 ]; then
    echo -e "${RED}❌ Expected at least 3 active test sessions, found: $DB_TEST_SESSIONS${NC}"
    echo "Database state:"
    sqlite3 -header -column sessions.db "SELECT session_id, downstream_server_status FROM sessions WHERE session_id LIKE 'test-%';"
    exit 1
fi
echo -e "${GREEN}✅ Test sessions verified in database ($DB_TEST_SESSIONS active sessions)${NC}"

echo ""
echo "🧪 Step 4: Running Hurl tests..."
echo "--------------------------------"

# Check if external test services are available
echo ""
echo "🌐 Checking external test services..."

# Check httpbin.org
HTTPBIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://httpbin.org/get 2>/dev/null || echo "000")
if [ "$HTTPBIN_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ httpbin.org is available${NC}"
    HTTPBIN_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  httpbin.org is not available (HTTP $HTTPBIN_STATUS)${NC}"
    HTTPBIN_AVAILABLE=false
fi

# Check jsonplaceholder
JSON_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://jsonplaceholder.typicode.com/posts/1 2>/dev/null || echo "000")
if [ "$JSON_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ jsonplaceholder.typicode.com is available${NC}"
    JSON_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  jsonplaceholder.typicode.com is not available (HTTP $JSON_STATUS)${NC}"
    JSON_AVAILABLE=false
fi

# Decide whether to skip HTTP tests
if [ "$HTTPBIN_AVAILABLE" = false ] && [ "$JSON_AVAILABLE" = false ]; then
    echo -e "${YELLOW}⚠️  All external test services are unavailable${NC}"
    echo -e "${YELLOW}   Skipping HTTP tests (no available external services)${NC}"
    echo -e "${YELLOW}   This is not a problem with ss-proxy itself${NC}"
    SKIP_HTTP_TESTS=true
elif [ "$HTTPBIN_AVAILABLE" = false ] || [ "$JSON_AVAILABLE" = false ]; then
    echo -e "${YELLOW}⚠️  Some external services are unavailable${NC}"
    echo -e "${YELLOW}   HTTP tests may fail or be partially incomplete${NC}"
    echo -e "${YELLOW}   This is not a problem with ss-proxy itself${NC}"
    SKIP_HTTP_TESTS=false
else
    SKIP_HTTP_TESTS=false
fi

echo ""
echo "Testing HTTP/HTTPS endpoints..."
if [ "$SKIP_HTTP_TESTS" = true ]; then
    echo -e "${YELLOW}⏭️  Skipping HTTP tests (external services unavailable)${NC}"
elif hurl --test --color --variable port=$PORT tests/http.hurl; then
    echo -e "${GREEN}✅ HTTP tests passed${NC}"
else
    echo -e "${RED}❌ HTTP tests failed${NC}"
    if [ "$HTTPBIN_AVAILABLE" = false ] || [ "$JSON_AVAILABLE" = false ]; then
        echo -e "${YELLOW}⚠️  Note: Some external services were unavailable during testing${NC}"
    fi
    exit 1
fi

echo ""
echo "Testing WebSocket endpoints..."
if hurl --test --color --variable port=$PORT tests/websocket.hurl; then
    echo -e "${GREEN}✅ WebSocket tests passed${NC}"
else
    echo -e "${RED}❌ WebSocket tests failed${NC}"
    exit 1
fi

echo ""
echo "🛑 Step 5: Stopping server for Rust integration tests..."
cleanup
sleep 2

echo ""
echo "🦀 Step 6: Running Rust integration tests..."
echo "---------------------------------------------"
if TEST_PORT=$PORT cargo test --test integration --release -- --test-threads=1 --nocapture; then
    echo -e "${GREEN}✅ Rust integration tests passed${NC}"
else
    echo -e "${RED}❌ Rust integration tests failed${NC}"
    exit 1
fi

echo ""
echo "================================"
echo -e "${GREEN}🎉 All tests passed!${NC}"
echo "================================"
