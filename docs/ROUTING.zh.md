# 路由规则详解

本文档详细说明 ss-proxy 的路由规则和请求转发行为。

[English](ROUTING.md) | 简体中文

- [路由规则详解](#路由规则详解)
  - [路由概览](#路由概览)
  - [HTTP/HTTPS 转发规则](#httphttps-转发规则)
    - [转发组件说明](#转发组件说明)
    - [示例](#示例)
      - [示例 1：基本 GET 请求](#示例-1基本-get-请求)
      - [示例 2：带查询参数](#示例-2带查询参数)
      - [示例 3：POST 请求](#示例-3post-请求)
      - [示例 4：流式响应（SSE）](#示例-4流式响应sse)
      - [示例 5：DELETE 请求](#示例-5delete-请求)
      - [示例 6：带自定义 Headers](#示例-6带自定义-headers)
    - [自动过滤的 Headers](#自动过滤的-headers)
  - [WebSocket 转发规则](#websocket-转发规则)
    - [WebSocket 转发组件](#websocket-转发组件)
    - [WebSocket 示例](#websocket-示例)
      - [示例 1：基本 WebSocket 连接](#示例-1基本-websocket-连接)
      - [示例 2：WebSocket URL 转换](#示例-2websocket-url-转换)
    - [WebSocket 消息转发](#websocket-消息转发)
  - [会话状态](#会话状态)
    - [状态检查示例](#状态检查示例)
  - [错误处理](#错误处理)
    - [HTTP 状态码](#http-状态码)
    - [错误示例](#错误示例)
      - [示例 1：Session 不存在](#示例-1session-不存在)
      - [示例 2：下游服务器不可用](#示例-2下游服务器不可用)
      - [示例 3：无法连接下游服务器](#示例-3无法连接下游服务器)
      - [示例 4：下游服务器错误](#示例-4下游服务器错误)
  - [性能特性](#性能特性)
    - [连接池](#连接池)
    - [超时设置](#超时设置)
  - [安全考虑](#安全考虑)
    - [Headers 过滤](#headers-过滤)
    - [建议](#建议)
  - [常见问题](#常见问题)
    - [Q1: 为什么 WebSocket 要追加 session\_id，而 HTTP 不追加？](#q1-为什么-websocket-要追加-session_id而-http-不追加)
    - [Q2: 可以修改转发行为吗？](#q2-可以修改转发行为吗)
    - [Q3: 支持 gRPC 吗？](#q3-支持-grpc-吗)
    - [Q4: 可以转发到多个下游服务器吗（负载均衡）？](#q4-可以转发到多个下游服务器吗负载均衡)
    - [Q5: 流式响应有大小限制吗？](#q5-流式响应有大小限制吗)
  - [相关文档](#相关文档)

## 路由概览

| 路径模式 | 说明 | 转发规则 |
|---------|------|----------|
| `/health` | 健康检查端点 | - |
| `/ws/:session_id` | WebSocket 代理 | 追加 session_id 到下游路径 |
| `/:session_id/*path` | HTTP/HTTPS 代理 | 只转发 path 部分，不含 session_id |

## HTTP/HTTPS 转发规则

### 转发组件说明

| 组件 | 处理方式 | 说明 |
|------|----------|------|
| session_id | 不转发 | 仅用于查询数据库 |
| path | 完整转发 | 原样转发到下游服务器 |
| query string | 完整转发 | 保留所有查询参数 |
| HTTP method | 完整转发 | 支持 GET/POST/PUT/DELETE/PATCH 等 |
| request headers | 过滤转发 | 自动过滤 host、connection、transfer-encoding、content-length |
| request body | 完整转发 | 原样转发 |
| response | 完整转发 | 包括状态码、headers、body |
| streaming | 支持 | SSE、分块编码、LLM API 等 |

### 示例

#### 示例 1：基本 GET 请求

```bash
# 数据库配置
# session_id: session_100
# downstream_url: https://api.example.com

# 用户请求
curl http://localhost:8080/session_100/users

# 实际转发到
https://api.example.com/users
```

#### 示例 2：带查询参数

```bash
# 用户请求
curl "http://localhost:8080/session_100/users?page=2&limit=10"

# 实际转发到
https://api.example.com/users?page=2&limit=10
```

#### 示例 3：POST 请求

```bash
# 用户请求
curl -X POST http://localhost:8080/session_100/api/data \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}'

# 实际转发到（包括 headers 和 body）
POST https://api.example.com/api/data
Content-Type: application/json
{"name": "test"}
```

#### 示例 4：流式响应（SSE）

```bash
# 用户请求
curl http://localhost:8080/session_100/stream

# 实际转发到（支持流式传输）
https://api.example.com/stream
```

#### 示例 5：DELETE 请求

```bash
# 用户请求
curl -X DELETE http://localhost:8080/session_100/users/123

# 实际转发到
DELETE https://api.example.com/users/123
```

#### 示例 6：带自定义 Headers

```bash
# 用户请求
curl http://localhost:8080/session_100/api/data \
  -H "Authorization: Bearer token123" \
  -H "X-Custom-Header: value"

# 实际转发到（包括自定义 headers）
GET https://api.example.com/api/data
Authorization: Bearer token123
X-Custom-Header: value
```

### 自动过滤的 Headers

以下 headers 不会被转发到下游服务器（由代理自动处理）：

- `host` - 由目标服务器决定
- `connection` - 连接管理相关
- `transfer-encoding` - 传输编码相关
- `content-length` - 内容长度相关

所有其他 headers 都会被完整转发。

## WebSocket 转发规则

### WebSocket 转发组件

| 组件 | 处理方式 | 说明 |
|------|----------|------|
| session_id | 追加到路径 | 会被添加到下游 WebSocket URL 的路径末尾 |
| 消息 | 双向转发 | 客户端↔服务器消息完整转发 |

### WebSocket 示例

#### 示例 1：基本 WebSocket 连接

```bash
# 数据库配置
# session_id: session_200
# downstream_url: wss://backend.com/ws

# 用户请求
wscat -c ws://localhost:8080/ws/session_200

# 实际转发到
wss://backend.com/ws/session_200
```

#### 示例 2：WebSocket URL 转换

```bash
# 数据库配置
# session_id: session_300
# downstream_url: http://api.example.com  # HTTP URL

# 用户请求
wscat -c ws://localhost:8080/ws/session_300

# 实际转发到（自动转换为 WebSocket URL）
ws://api.example.com/session_300
```

```bash
# 数据库配置
# session_id: session_400
# downstream_url: https://api.example.com  # HTTPS URL

# 用户请求
wscat -c wss://localhost:8080/ws/session_400

# 实际转发到（自动转换为 WebSocket URL）
wss://api.example.com/session_400
```

### WebSocket 消息转发

- **文本消息**: 完整转发
- **二进制消息**: 完整转发
- **Ping/Pong**: 自动处理
- **Close**: 双向转发关闭信号

## 会话状态

代理服务器只会将请求转发到状态为以下值的下游服务器：

| 状态值 | 说明 | 行为 |
|--------|------|------|
| `active` | 活跃 | ✅ 转发请求 |
| `online` | 在线 | ✅ 转发请求 |
| `ready` | 就绪 | ✅ 转发请求 |
| `inactive` | 不活跃 | ❌ 返回 503 |
| 其他 | - | ❌ 返回 503 |

### 状态检查示例

```bash
# 数据库中的会话
session_id: session_500
downstream_url: https://api.example.com
downstream_server_status: inactive

# 用户请求
curl http://localhost:8080/session_500/users

# 响应
HTTP/1.1 503 Service Unavailable
```

## 错误处理

### HTTP 状态码

| 状态码 | 说明 | 原因 |
|--------|------|------|
| `200-5xx` | 下游服务器响应 | 直接返回下游服务器的状态码 |
| `404` | Not Found | session_id 在数据库中不存在 |
| `503` | Service Unavailable | 下游服务器状态不可用（非 active/online/ready） |
| `502` | Bad Gateway | 无法连接到下游服务器 |

### 错误示例

#### 示例 1：Session 不存在

```bash
# 用户请求（session_999 不存在）
curl http://localhost:8080/session_999/users

# 响应
HTTP/1.1 404 Not Found
```

#### 示例 2：下游服务器不可用

```bash
# 数据库配置
# session_id: session_600
# downstream_server_status: inactive

# 用户请求
curl http://localhost:8080/session_600/users

# 响应
HTTP/1.1 503 Service Unavailable
```

#### 示例 3：无法连接下游服务器

```bash
# 数据库配置
# session_id: session_700
# downstream_url: https://nonexistent.example.com

# 用户请求
curl http://localhost:8080/session_700/users

# 响应
HTTP/1.1 502 Bad Gateway
```

#### 示例 4：下游服务器错误

```bash
# 用户请求
curl http://localhost:8080/session_100/api/error

# 下游服务器返回错误
HTTP/1.1 500 Internal Server Error
{"error": "Something went wrong"}

# 代理完整转发响应
HTTP/1.1 500 Internal Server Error
{"error": "Something went wrong"}
```

## 性能特性

### 连接池

- **HTTP 连接池**: 复用到下游服务器的 HTTP 连接
- **数据库连接池**: 复用 SQLite 数据库连接
- **并发处理**: 基于 Tokio 异步运行时，支持高并发

### 超时设置

默认超时配置（可通过环境变量调整）：

```bash
# HTTP 请求超时（默认 30 秒）
export REQUEST_TIMEOUT=30

# 数据库连接池最大连接数（默认 5）
export DATABASE_MAX_CONNECTIONS=5
```

详细配置说明请参阅 [配置指南](CONFIGURATION.md)。

## 安全考虑

### Headers 过滤

代理会自动过滤以下敏感 headers，防止安全问题：

- `host` - 防止 Host header 注入
- `connection` - 防止连接劫持
- `transfer-encoding` - 防止请求走私攻击
- `content-length` - 防止内容长度不匹配

### 建议

1. **使用 HTTPS**: 在生产环境中使用反向代理（如 Nginx）提供 HTTPS 支持
2. **限制访问**: 使用防火墙或 IP 白名单限制对代理的访问
3. **监控日志**: 定期检查日志，发现异常流量
4. **更新依赖**: 定期更新 Rust 依赖，修复安全漏洞

详细安全配置请参阅 [配置指南](CONFIGURATION.md#安全配置)。

## 常见问题

### Q1: 为什么 WebSocket 要追加 session_id，而 HTTP 不追加？

**A**: 这是基于不同协议的使用场景设计的：

- **HTTP/HTTPS**: 通常下游服务器通过路径区分资源（如 `/users`、`/posts`），session_id 仅用于代理层的路由决策
- **WebSocket**: 通常下游服务器需要知道具体的会话标识来管理长连接，因此追加 session_id 到路径中

### Q2: 可以修改转发行为吗？

**A**: 当前版本不支持配置转发行为。如果需要不同的转发逻辑，可以：

1. 修改源代码 `src/handlers/http.rs` 和 `src/handlers/websocket.rs`
2. 提交 Issue 或 Pull Request 到项目仓库

### Q3: 支持 gRPC 吗？

**A**: 当前版本不支持 gRPC。gRPC 基于 HTTP/2，需要特殊处理。如有需求，请提交 Issue。

### Q4: 可以转发到多个下游服务器吗（负载均衡）？

**A**: 当前版本不支持负载均衡。每个 session_id 只能对应一个下游服务器。如需负载均衡，建议：

1. 在下游使用负载均衡器（如 Nginx、HAProxy）
2. 或在数据库中创建多个 session_id 指向不同的下游服务器

### Q5: 流式响应有大小限制吗？

**A**: 没有硬性限制。代理使用流式传输，不会将整个响应加载到内存中，理论上支持任意大小的响应。

## 相关文档

- [数据库操作指南](DATABASE.md) - 会话管理和数据库操作
- [配置指南](CONFIGURATION.md) - 配置选项和部署建议
- [测试指南](TESTING.md) - 测试路由和转发行为
