# Routing Rules Guide

This document provides detailed information about ss-proxy routing rules and request forwarding behavior.

English | [简体中文](ROUTING.zh.md)

- [Routing Rules Guide](#routing-rules-guide)
  - [Routing Overview](#routing-overview)
  - [HTTP/HTTPS Forwarding Rules](#httphttps-forwarding-rules)
    - [Forwarding Components](#forwarding-components)
    - [Examples](#examples)
      - [Example 1: Basic GET Request](#example-1-basic-get-request)
      - [Example 2: With Query Parameters](#example-2-with-query-parameters)
      - [Example 3: POST Request](#example-3-post-request)
      - [Example 4: Streaming Response (SSE)](#example-4-streaming-response-sse)
      - [Example 5: DELETE Request](#example-5-delete-request)
      - [Example 6: With Custom Headers](#example-6-with-custom-headers)
    - [Auto-Filtered Headers](#auto-filtered-headers)
  - [WebSocket Forwarding Rules](#websocket-forwarding-rules)
    - [WebSocket Forwarding Components](#websocket-forwarding-components)
    - [WebSocket Examples](#websocket-examples)
      - [Example 1: Basic WebSocket Connection](#example-1-basic-websocket-connection)
      - [Example 2: WebSocket URL Conversion](#example-2-websocket-url-conversion)
    - [WebSocket Message Forwarding](#websocket-message-forwarding)
  - [Session Status](#session-status)
    - [Status Check Example](#status-check-example)
  - [Error Handling](#error-handling)
    - [HTTP Status Codes](#http-status-codes)
    - [Error Examples](#error-examples)
      - [Example 1: Session Does Not Exist](#example-1-session-does-not-exist)
      - [Example 2: Downstream Server Unavailable](#example-2-downstream-server-unavailable)
      - [Example 3: Cannot Connect to Downstream Server](#example-3-cannot-connect-to-downstream-server)
      - [Example 4: Downstream Server Error](#example-4-downstream-server-error)
  - [Performance Features](#performance-features)
    - [Connection Pooling](#connection-pooling)
    - [Timeout Settings](#timeout-settings)
  - [Security Considerations](#security-considerations)
    - [Header Filtering](#header-filtering)
    - [Recommendations](#recommendations)
  - [FAQ](#faq)
    - [Q1: Why does WebSocket append session\_id while HTTP doesn't?](#q1-why-does-websocket-append-session_id-while-http-doesnt)
    - [Q2: Can I modify the forwarding behavior?](#q2-can-i-modify-the-forwarding-behavior)
    - [Q3: Does it support gRPC?](#q3-does-it-support-grpc)
    - [Q4: Can it forward to multiple downstream servers (load balancing)?](#q4-can-it-forward-to-multiple-downstream-servers-load-balancing)
    - [Q5: Is there a size limit for streaming responses?](#q5-is-there-a-size-limit-for-streaming-responses)
  - [Related Documentation](#related-documentation)

## Routing Overview

| Path Pattern | Description | Forwarding Rule |
|--------------|-------------|-----------------|
| `/health` | Health check endpoint | - |
| `/ws/:session_id` | WebSocket proxy | Append session_id to downstream path |
| `/:session_id/*path` | HTTP/HTTPS proxy | Forward only path part, excluding session_id |

## HTTP/HTTPS Forwarding Rules

### Forwarding Components

| Component | Handling | Description |
|-----------|----------|-------------|
| session_id | Not forwarded | Used only for database query |
| path | Fully forwarded | Forwarded as-is to downstream server |
| query string | Fully forwarded | All query parameters preserved |
| HTTP method | Fully forwarded | Supports GET/POST/PUT/DELETE/PATCH, etc. |
| request headers | Filtered forwarding | Auto-filters host, connection, transfer-encoding, content-length |
| request body | Fully forwarded | Forwarded as-is |
| response | Fully forwarded | Includes status code, headers, body |
| streaming | Supported | SSE, chunked encoding, LLM API, etc. |

### Examples

#### Example 1: Basic GET Request

```bash
# Database configuration
# session_id: session_100
# downstream_url: https://api.example.com

# User request
curl http://localhost:8080/session_100/users

# Actually forwarded to
https://api.example.com/users
```

#### Example 2: With Query Parameters

```bash
# User request
curl "http://localhost:8080/session_100/users?page=2&limit=10"

# Actually forwarded to
https://api.example.com/users?page=2&limit=10
```

#### Example 3: POST Request

```bash
# User request
curl -X POST http://localhost:8080/session_100/api/data \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}'

# Actually forwarded to (including headers and body)
POST https://api.example.com/api/data
Content-Type: application/json
{"name": "test"}
```

#### Example 4: Streaming Response (SSE)

```bash
# User request
curl http://localhost:8080/session_100/stream

# Actually forwarded to (supports streaming)
https://api.example.com/stream
```

#### Example 5: DELETE Request

```bash
# User request
curl -X DELETE http://localhost:8080/session_100/users/123

# Actually forwarded to
DELETE https://api.example.com/users/123
```

#### Example 6: With Custom Headers

```bash
# User request
curl http://localhost:8080/session_100/api/data \
  -H "Authorization: Bearer token123" \
  -H "X-Custom-Header: value"

# Actually forwarded to (including custom headers)
GET https://api.example.com/api/data
Authorization: Bearer token123
X-Custom-Header: value
```

### Auto-Filtered Headers

The following headers are not forwarded to downstream servers (handled automatically by the proxy):

- `host` - Determined by target server
- `connection` - Connection management
- `transfer-encoding` - Transfer encoding related
- `content-length` - Content length related

All other headers are fully forwarded.

## WebSocket Forwarding Rules

### WebSocket Forwarding Components

| Component | Handling | Description |
|-----------|----------|-------------|
| session_id | Appended to path | Added to the end of downstream WebSocket URL path |
| messages | Bidirectional forwarding | Client ↔ Server messages fully forwarded |

### WebSocket Examples

#### Example 1: Basic WebSocket Connection

```bash
# Database configuration
# session_id: session_200
# downstream_url: wss://backend.com/ws

# User request
wscat -c ws://localhost:8080/ws/session_200

# Actually forwarded to
wss://backend.com/ws/session_200
```

#### Example 2: WebSocket URL Conversion

```bash
# Database configuration
# session_id: session_300
# downstream_url: http://api.example.com  # HTTP URL

# User request
wscat -c ws://localhost:8080/ws/session_300

# Actually forwarded to (auto-converted to WebSocket URL)
ws://api.example.com/session_300
```

```bash
# Database configuration
# session_id: session_400
# downstream_url: https://api.example.com  # HTTPS URL

# User request
wscat -c wss://localhost:8080/ws/session_400

# Actually forwarded to (auto-converted to WebSocket URL)
wss://api.example.com/session_400
```

### WebSocket Message Forwarding

- **Text messages**: Fully forwarded
- **Binary messages**: Fully forwarded
- **Ping/Pong**: Automatically handled
- **Close**: Bidirectional close signal forwarding

## Session Status

The proxy server only forwards requests to downstream servers with the following status values:

| Status | Description | Behavior |
|--------|-------------|----------|
| `active` | Active | ✅ Forward request |
| `online` | Online | ✅ Forward request |
| `ready` | Ready | ✅ Forward request |
| `inactive` | Inactive | ❌ Return 503 |
| Others | - | ❌ Return 503 |

### Status Check Example

```bash
# Session in database
session_id: session_500
downstream_url: https://api.example.com
downstream_server_status: inactive

# User request
curl http://localhost:8080/session_500/users

# Response
HTTP/1.1 503 Service Unavailable
```

## Error Handling

### HTTP Status Codes

| Status Code | Description | Reason |
|-------------|-------------|--------|
| `200-5xx` | Downstream server response | Directly returns downstream server status code |
| `404` | Not Found | session_id does not exist in database |
| `503` | Service Unavailable | Downstream server status unavailable (not active/online/ready) |
| `502` | Bad Gateway | Cannot connect to downstream server |

### Error Examples

#### Example 1: Session Does Not Exist

```bash
# User request (session_999 does not exist)
curl http://localhost:8080/session_999/users

# Response
HTTP/1.1 404 Not Found
```

#### Example 2: Downstream Server Unavailable

```bash
# Database configuration
# session_id: session_600
# downstream_server_status: inactive

# User request
curl http://localhost:8080/session_600/users

# Response
HTTP/1.1 503 Service Unavailable
```

#### Example 3: Cannot Connect to Downstream Server

```bash
# Database configuration
# session_id: session_700
# downstream_url: https://nonexistent.example.com

# User request
curl http://localhost:8080/session_700/users

# Response
HTTP/1.1 502 Bad Gateway
```

#### Example 4: Downstream Server Error

```bash
# User request
curl http://localhost:8080/session_100/api/error

# Downstream server returns error
HTTP/1.1 500 Internal Server Error
{"error": "Something went wrong"}

# Proxy fully forwards response
HTTP/1.1 500 Internal Server Error
{"error": "Something went wrong"}
```

## Performance Features

### Connection Pooling

- **HTTP Connection Pool**: Reuses HTTP connections to downstream servers
- **Database Connection Pool**: Reuses SQLite database connections
- **Concurrent Processing**: Based on Tokio async runtime, supports high concurrency

### Timeout Settings

Default timeout configuration (adjustable via environment variables):

```bash
# HTTP request timeout (default 30 seconds)
export REQUEST_TIMEOUT=30

# Database connection pool max connections (default 5)
export DATABASE_MAX_CONNECTIONS=5
```

For detailed configuration, see [Configuration Guide](CONFIGURATION.md).

## Security Considerations

### Header Filtering

The proxy automatically filters the following sensitive headers to prevent security issues:

- `host` - Prevents Host header injection
- `connection` - Prevents connection hijacking
- `transfer-encoding` - Prevents request smuggling attacks
- `content-length` - Prevents content-length mismatch

### Recommendations

1. **Use HTTPS**: Use a reverse proxy (like Nginx) to provide HTTPS support in production
2. **Restrict Access**: Use firewall or IP whitelist to restrict proxy access
3. **Monitor Logs**: Regularly check logs to detect abnormal traffic
4. **Update Dependencies**: Regularly update Rust dependencies to fix security vulnerabilities

For detailed security configuration, see [Configuration Guide](CONFIGURATION.md#security-configuration).

## FAQ

### Q1: Why does WebSocket append session_id while HTTP doesn't?

**A**: This is designed based on different protocol usage scenarios:

- **HTTP/HTTPS**: Downstream servers typically distinguish resources by path (like `/users`, `/posts`), and session_id is only used for routing decisions at the proxy layer
- **WebSocket**: Downstream servers typically need to know the specific session identifier to manage long connections, so session_id is appended to the path

### Q2: Can I modify the forwarding behavior?

**A**: The current version does not support configurable forwarding behavior. If you need different forwarding logic, you can:

1. Modify the source code `src/handlers/http.rs` and `src/handlers/websocket.rs`
2. Submit an Issue or Pull Request to the project repository

### Q3: Does it support gRPC?

**A**: The current version does not support gRPC. gRPC is based on HTTP/2 and requires special handling. If you need it, please submit an Issue.

### Q4: Can it forward to multiple downstream servers (load balancing)?

**A**: The current version does not support load balancing. Each session_id can only correspond to one downstream server. If you need load balancing, we recommend:

1. Use a load balancer downstream (like Nginx, HAProxy)
2. Or create multiple session_ids in the database pointing to different downstream servers

### Q5: Is there a size limit for streaming responses?

**A**: There is no hard limit. The proxy uses streaming transfer and does not load the entire response into memory, theoretically supporting responses of any size.

## Related Documentation

- [Database Guide](DATABASE.md) - Session management and database operations
- [Configuration Guide](CONFIGURATION.md) - Configuration options and deployment recommendations
- [Testing Guide](TESTING.md) - Testing routing and forwarding behavior
