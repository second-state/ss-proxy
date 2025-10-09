#!/bin/bash

# Quick script to stop Docker test services for ss-proxy integration tests

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Stopping Docker test services for ss-proxy...${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found."
    exit 1
fi

# Check if docker-compose.test.yml exists
if [ ! -f "docker-compose.test.yml" ]; then
    echo "❌ docker-compose.test.yml not found in current directory"
    exit 1
fi

# Stop and remove services
docker-compose -f docker-compose.test.yml down

echo ""
echo -e "${GREEN}✅ Docker test services stopped${NC}"
echo ""
echo "To start services again:"
echo "  ./scripts/start-test-services.sh"
echo ""
