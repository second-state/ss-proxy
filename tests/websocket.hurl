# WebSocket Proxy Tests
# Test suite for ss-proxy WebSocket proxy functionality

# =============================================================================
# WebSocket Echo Test - Text Message
# =============================================================================
GET http://localhost:8080/ws/test-ws
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 101
[Asserts]
header "Upgrade" == "websocket"
header "Connection" contains "Upgrade"

# Note: Due to Hurl limitations with WebSocket message testing,
# actual WebSocket message exchange is tested in the Rust integration tests.
# This test only verifies the WebSocket upgrade handshake.

# =============================================================================
# WebSocket Error Case - Session Not Found (404)
# =============================================================================
GET http://localhost:8080/ws/nonexistent-session
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 404

# =============================================================================
# WebSocket Error Case - Inactive Session (503)
# =============================================================================
GET http://localhost:8080/ws/test-inactive
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 503
