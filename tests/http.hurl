# HTTP/HTTPS Proxy Tests
# Test suite for ss-proxy HTTP proxy functionality

# =============================================================================
# Health Check Test
# =============================================================================
GET http://localhost:{{port}}/health
HTTP 200
[Asserts]
body == "OK"
duration < 1000  # Should respond within 1 second

# =============================================================================
# HTTP Proxy - GET Request Test
# =============================================================================
GET http://localhost:{{port}}/test-http/get
HTTP 200
[Asserts]
jsonpath "$.url" == "http://localhost:8888/get"
header "Content-Type" contains "application/json"

# =============================================================================
# HTTP Proxy - Query Parameters Test
# =============================================================================
GET http://localhost:{{port}}/test-http/get?foo=bar&hello=world
HTTP 200
[Asserts]
jsonpath "$.args.foo" == "bar"
jsonpath "$.args.hello" == "world"

# =============================================================================
# HTTP Proxy - POST Request Test
# =============================================================================
POST http://localhost:{{port}}/test-http/post
Content-Type: application/json
{
  "test": "data",
  "number": 42,
  "nested": {
    "key": "value"
  }
}
HTTP 200
[Asserts]
jsonpath "$.url" == "http://localhost:8888/post"
jsonpath "$.json.test" == "data"
jsonpath "$.json.number" == 42
jsonpath "$.json.nested.key" == "value"

# =============================================================================
# HTTP Proxy - PUT Request Test
# =============================================================================
PUT http://localhost:{{port}}/test-http/put
Content-Type: application/json
{
  "action": "update",
  "id": 123
}
HTTP 200
[Asserts]
jsonpath "$.url" == "http://localhost:8888/put"
jsonpath "$.json.action" == "update"

# =============================================================================
# HTTP Proxy - DELETE Request Test
# =============================================================================
DELETE http://localhost:{{port}}/test-http/delete
HTTP 200
[Asserts]
jsonpath "$.url" == "http://localhost:8888/delete"

# =============================================================================
# HTTP Proxy - Custom Headers Test
# =============================================================================
GET http://localhost:{{port}}/test-http/headers
X-Custom-Header: test-value
User-Agent: ss-proxy-test/1.0
HTTP 200
[Asserts]
jsonpath "$.headers['X-Custom-Header']" == "test-value"
jsonpath "$.headers['User-Agent']" == "ss-proxy-test/1.0"

# =============================================================================
# HTTP Proxy - Path with Multiple Segments Test
# =============================================================================
GET http://localhost:{{port}}/test-http/anything/path/to/resource
HTTP 200
[Asserts]
jsonpath "$.url" == "http://localhost:8888/anything/path/to/resource"

# =============================================================================
# JSON API Proxy Test (jsonplaceholder)
# =============================================================================
GET http://localhost:{{port}}/test-json/posts/1
HTTP 200
[Asserts]
jsonpath "$.id" == 1
jsonpath "$.userId" exists

# =============================================================================
# Error Case - Session Not Found (404)
# =============================================================================
GET http://localhost:{{port}}/nonexistent-session/get
HTTP 404

# =============================================================================
# Error Case - Inactive Session (503)
# =============================================================================
GET http://localhost:{{port}}/test-inactive/get
HTTP 503
