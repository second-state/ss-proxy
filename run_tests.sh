#!/bin/bash

# Test helper script for local testing
# Run integration tests locally before pushing to GitHub

set -e

echo "🧪 SS-Proxy Local Test Suite"
echo "================================"

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
echo -e "${GREEN}✅ Database initialized${NC}"

echo ""
echo "🚀 Step 3: Starting server..."
./target/release/ss-proxy --port 8080 --log-level debug &
SERVER_PID=$!
echo $SERVER_PID > /tmp/ss-proxy.pid
echo -e "${GREEN}Server started with PID: $SERVER_PID${NC}"

# Wait for server to be ready
echo ""
echo "⏳ Waiting for server to be ready..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Server is ready!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Server failed to start${NC}"
        exit 1
    fi
    sleep 1
done

echo ""
echo "🧪 Step 4: Running Hurl tests..."
echo "--------------------------------"

echo ""
echo "Testing HTTP/HTTPS endpoints..."
if hurl --test --color tests/http.hurl; then
    echo -e "${GREEN}✅ HTTP tests passed${NC}"
else
    echo -e "${RED}❌ HTTP tests failed${NC}"
    exit 1
fi

echo ""
echo "Testing WebSocket endpoints..."
if hurl --test --color tests/websocket.hurl; then
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
if cargo test --test integration --release -- --test-threads=1 --nocapture; then
    echo -e "${GREEN}✅ Rust integration tests passed${NC}"
else
    echo -e "${RED}❌ Rust integration tests failed${NC}"
    exit 1
fi

echo ""
echo "================================"
echo -e "${GREEN}🎉 All tests passed!${NC}"
echo "================================"
