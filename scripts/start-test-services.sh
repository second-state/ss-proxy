#!/bin/bash

# Quick script to start Docker test services for ss-proxy integration tests
# This starts httpbin, json-api, and ws-echo services in Docker containers

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Starting Docker test services for ss-proxy...${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if docker-compose.test.yml exists
if [ ! -f "docker-compose.test.yml" ]; then
    echo "❌ docker-compose.test.yml not found in current directory"
    exit 1
fi

# Start services
echo "Starting services..."
docker-compose -f docker-compose.test.yml up -d

echo ""
echo -e "${YELLOW}⏳ Waiting for services to be healthy...${NC}"
echo ""

# Wait for services to be healthy with timeout
MAX_WAIT=60
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check health status of all containers
    HTTPBIN_HEALTH=$(docker inspect ss-proxy-test-httpbin --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    JSON_HEALTH=$(docker inspect ss-proxy-test-json --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
    WS_HEALTH=$(docker inspect ss-proxy-test-ws --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")

    echo -e "  httpbin: $HTTPBIN_HEALTH | json-api: $JSON_HEALTH | ws-echo: $WS_HEALTH"

    if [ "$HTTPBIN_HEALTH" = "healthy" ] && [ "$JSON_HEALTH" = "healthy" ] && [ "$WS_HEALTH" = "healthy" ]; then
        echo ""
        echo -e "${GREEN}✅ All services are healthy and ready!${NC}"
        echo ""
        echo "Services available at:"
        echo "  📡 httpbin:   http://localhost:8888"
        echo "  📊 json-api:  http://localhost:8889"
        echo "  🔌 ws-echo:   ws://localhost:8890"
        echo ""
        echo "To test services:"
        echo "  curl http://localhost:8888/get"
        echo "  curl http://localhost:8889/posts"
        echo ""
        echo "To stop services:"
        echo "  ./scripts/stop-test-services.sh"
        echo "  or: docker-compose -f docker-compose.test.yml down"
        echo ""
        exit 0
    fi

    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

echo ""
echo "❌ Services failed to become healthy within ${MAX_WAIT}s"
echo ""
echo "Checking logs..."
docker-compose -f docker-compose.test.yml logs

exit 1
