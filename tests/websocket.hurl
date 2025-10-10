# WebSocket Proxy Tests
# Test suite for ss-proxy WebSocket proxy functionality
#
# ⚠️  WARNING: THIS FILE IS NOT EXECUTED IN CI/CD ⚠️
#
# Reason: Hurl does not support WebSocket message exchange protocol.
# While Hurl can perform the WebSocket upgrade handshake (HTTP 101),
# it cannot send/receive WebSocket frames or properly close connections.
# This causes 300-second timeouts in automated tests.
#
# ✅ ALTERNATIVE: Complete WebSocket testing is done in Rust integration tests
# See: tests/integration.rs
#   - test_websocket_echo (text messages)
#   - test_websocket_binary_message (binary messages)
#   - test_websocket_multiple_messages (message sequences)
#   - test_websocket_session_not_found (error handling)
#
# This file is kept for documentation purposes only.
#

# =============================================================================
# WebSocket Echo Test - Text Message
# =============================================================================
GET http://localhost:{{port}}/ws/test-ws
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 101
[Asserts]
header "Upgrade" == "websocket"
header "Connection" contains "upgrade"

# Note: Due to Hurl limitations with WebSocket message testing,
# actual WebSocket message exchange is tested in the Rust integration tests.
# This test only verifies the WebSocket upgrade handshake.

# =============================================================================
# WebSocket Error Case - Session Not Found (404)
# =============================================================================
GET http://localhost:{{port}}/ws/nonexistent-session
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 404

# =============================================================================
# WebSocket Error Case - Inactive Session (503)
# =============================================================================
GET http://localhost:{{port}}/ws/test-inactive
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
HTTP 503
