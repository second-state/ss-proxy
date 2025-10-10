# Streaming Response Test
# Test suite for validating streaming/SSE response handling

# =============================================================================
# HTTP Streaming Test - Simulates OpenAI-style streaming response
# =============================================================================
# This test verifies that the proxy correctly handles streaming responses
# from downstream servers (like SSE or chunked transfer encoding)

POST http://localhost:{{port}}/test-http/stream-bytes/1024
HTTP 200
[Asserts]
# Verify the response is received
header "Content-Type" exists
duration < 5000  # Should complete within 5 seconds

# =============================================================================
# SSE (Server-Sent Events) Style Test
# =============================================================================
# Test that mimics LLM streaming responses (like OpenAI's streaming API)

POST http://localhost:{{port}}/test-http/stream/20
HTTP 200
[Asserts]
# Verify streaming response headers
header "Content-Type" exists
# Response should be received in streaming fashion
duration < 10000
