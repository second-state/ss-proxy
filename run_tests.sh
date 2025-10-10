#!/bin/bash

# Test helper script for local testing with Docker services
# Run integration tests locally before pushing to GitHub

set -e

# Get port from environment variable or use default
PORT=${TEST_PORT:-8080}
USE_DOCKER_SERVICES=${USE_DOCKER_SERVICES:-true}

echo "🧪 SS-Proxy Local Test Suite"
echo "================================"
echo "Test port: $PORT"
echo "Use Docker services: $USE_DOCKER_SERVICES"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to start Docker test services
start_docker_services() {
    echo ""
    echo -e "${BLUE}🐳 Starting Docker test services...${NC}"

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
        echo "   Visit: https://docs.docker.com/get-docker/"
        return 1
    fi

    # Start services
    docker-compose -f docker-compose.test.yml up -d

    # Wait for services to be healthy
    echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
    local max_wait=60
    local elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        # Check if all services are healthy
        local httpbin_health=$(docker inspect ss-proxy-test-httpbin --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
        local json_health=$(docker inspect ss-proxy-test-json --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
        local ws_health=$(docker inspect ss-proxy-test-ws --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")

        if [ "$httpbin_health" = "healthy" ] && [ "$json_health" = "healthy" ] && [ "$ws_health" = "healthy" ]; then
            echo -e "${GREEN}✅ All Docker services are ready!${NC}"
            echo "  📡 httpbin:   http://localhost:8888"
            echo "  📊 json-api:  http://localhost:8889"
            echo "  🔌 ws-echo:   ws://localhost:8890"
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo -e "${RED}❌ Docker services failed to start within ${max_wait}s${NC}"
    docker-compose -f docker-compose.test.yml logs
    return 1
}

# Function to stop Docker test services
stop_docker_services() {
    if [ "$USE_DOCKER_SERVICES" = true ]; then
        echo ""
        echo -e "${BLUE}🐳 Stopping Docker test services...${NC}"
        docker-compose -f docker-compose.test.yml down
        echo -e "${GREEN}✅ Docker services stopped${NC}"
    fi
}

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

# Clean up server process (but keep Docker services running)
cleanup_server() {
    if [ ! -z "$SERVER_PID" ]; then
        echo -e "${YELLOW}🛑 Stopping server (PID: $SERVER_PID)${NC}"
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    rm -f /tmp/ss-proxy.pid
}

# Clean up everything (server + Docker services)
cleanup_all() {
    cleanup_server
    stop_docker_services
}

trap cleanup_all EXIT

# Start Docker services if enabled
if [ "$USE_DOCKER_SERVICES" = true ]; then
    if ! start_docker_services; then
        echo -e "${RED}❌ Failed to start Docker services${NC}"
        exit 1
    fi
fi

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

# Verify test services are accessible (if using Docker)
if [ "$USE_DOCKER_SERVICES" = true ]; then
    echo ""
    echo "🔍 Verifying test services are accessible..."

    if curl -f http://localhost:8888/get > /dev/null 2>&1; then
        echo -e "${GREEN}✅ httpbin service is accessible${NC}"
    else
        echo -e "${RED}❌ httpbin service is not accessible${NC}"
        exit 1
    fi

    if curl -f http://localhost:8889/posts > /dev/null 2>&1; then
        echo -e "${GREEN}✅ json-api service is accessible${NC}"
    else
        echo -e "${RED}❌ json-api service is not accessible${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ ws-echo service is running${NC}"
fi

echo ""
echo "🧪 Step 4: Running Hurl tests..."
echo "--------------------------------"

echo ""
echo "Testing HTTP/HTTPS endpoints..."
if hurl --test --color --variable port=$PORT tests/http.hurl; then
    echo -e "${GREEN}✅ HTTP tests passed${NC}"
else
    echo -e "${RED}❌ HTTP tests failed${NC}"
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
cleanup_server
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
