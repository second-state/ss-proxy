# 完整示例教程

本文档提供两个完整的端到端示例，展示如何使用 ss-proxy 进行 HTTP 和 WebSocket 代理。每个示例都包含详细的步骤，您可以通过复制粘贴命令来完成整个流程。

[English](EXAMPLES.md) | 简体中文

- [完整示例教程](#完整示例教程)
  - [前置准备](#前置准备)
    - [系统要求](#系统要求)
    - [安装依赖](#安装依赖)
  - [章节 1：HTTP 代理完整示例](#章节-1http-代理完整示例)
    - [1.1 克隆并进入项目](#11-克隆并进入项目)
    - [1.2 启动测试服务](#12-启动测试服务)
    - [1.3 初始化数据库](#13-初始化数据库)
    - [1.4 配置 HTTP 会话](#14-配置-http-会话)
    - [1.5 构建并启动代理服务器](#15-构建并启动代理服务器)
    - [1.6 测试 HTTP 代理功能](#16-测试-http-代理功能)
    - [1.7 清理环境](#17-清理环境)
  - [章节 2：WebSocket 代理完整示例](#章节-2websocket-代理完整示例)
    - [2.1 环境准备](#21-环境准备)
    - [2.2 配置 WebSocket 会话](#22-配置-websocket-会话)
    - [2.3 启动代理服务器（如未运行）](#23-启动代理服务器如未运行)
    - [2.4 测试 WebSocket 连接](#24-测试-websocket-连接)
    - [2.5 清理环境](#25-清理环境)
  - [故障排查](#故障排查)
    - [服务启动失败](#服务启动失败)
    - [代理连接失败](#代理连接失败)
    - [WebSocket 连接问题](#websocket-连接问题)

## 前置准备

### 系统要求

在开始之前，请确保您的系统满足以下要求：

- **操作系统**: macOS、Linux 或 Windows（WSL2）
- **Docker**: 20.10+ 和 Docker Compose
- **Rust**: 1.90.0+（项目会自动安装）
- **SQLite**: 3.x
- **其他工具**: curl, websocat（用于 WebSocket 测试）

### 安装依赖

```bash
# macOS
brew install docker docker-compose sqlite websocat

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose sqlite3

# 安装 websocat（WebSocket 客户端）
cargo install websocat

# 验证安装
docker --version
docker-compose --version
sqlite3 --version
websocat --version
```

---

## 章节 1：HTTP 代理完整示例

本示例将演示如何设置 ss-proxy 并代理 HTTP 请求到测试服务器。

### 1.1 克隆并进入项目

```bash
# 克隆项目
git clone https://github.com/second-state/ss-proxy.git
cd ss-proxy
```

### 1.2 启动测试服务

我们使用 Docker Compose 启动本地测试服务，包括 httpbin（HTTP 测试）、json-api 和 ws-echo（WebSocket 测试）。

```bash
# 启动所有测试服务
docker compose -f docker-compose.test.yml up -d

# 等待服务启动（约 10-15 秒）
sleep 15

# 验证服务状态
docker compose -f docker-compose.test.yml ps
```

**预期输出**:

```console
NAME                      COMMAND                  SERVICE   STATUS      PORTS
ss-proxy-test-httpbin     "gunicorn -b 0.0.0.0…"   httpbin   Up          0.0.0.0:8888->80/tcp
ss-proxy-test-json        "json-server -H 0.0.…"   json-api  Up          0.0.0.0:8889->80/tcp
ss-proxy-test-ws          "sh -c 'pip install …"   ws-echo   Up          0.0.0.0:8890->8890/tcp
```

**验证服务可访问**:

```bash
# 测试 httpbin 服务
curl http://localhost:8888/get

# 预期返回 JSON 响应
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get"
}
```

### 1.3 初始化数据库

```bash
# 添加执行权限并运行初始化脚本
chmod +x init_db.sh
./init_db.sh

# 验证数据库已创建
ls -lh sessions.db
```

**预期输出**:

```console
================================================
  ss-proxy Database Initialization Tool
================================================

Database path: ./sessions.db

Executing initialization script...
✅ sessions 表创建成功
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY NOT NULL,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_session_status
ON sessions(downstream_server_status);
CREATE INDEX idx_created_at
ON sessions(created_at);

================================================
✅ Database initialization successful!
================================================
```

**查看数据库结构**:

```bash
sqlite3 sessions.db '.schema sessions'
```

**预期输出**:

```sql
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY NOT NULL,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_session_status
ON sessions(downstream_server_status);
CREATE INDEX idx_created_at
ON sessions(created_at);
```

### 1.4 配置 HTTP 会话

向数据库添加一个 HTTP 会话配置，将 session_id 映射到我们的测试服务器。

```bash
# 添加 HTTP 测试会话
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_http_001', 'http://localhost:8888', 'active');
EOF

# 验证会话已添加
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_http_001';"
```

**预期输出**:

```console
session_http_001|http://localhost:8888|active|2025-10-11 02:28:26|2025-10-11 02:28:26
```

### 1.5 构建并启动代理服务器

```bash
# 构建项目（Release 模式，性能更好）
cargo build --release

# 启动代理服务器（默认端口 8080）
cargo run --release &

# 等待服务器启动
sleep 3

# 验证服务器运行中
curl http://localhost:8080/health
```

**预期输出**:

```console
OK
```

### 1.6 测试 HTTP 代理功能

现在我们可以通过代理服务器发送 HTTP 请求了。

**测试 1: 简单的 GET 请求**

```bash
# 通过代理访问 /get 端点
curl http://localhost:8080/session_http_001/get
```

**预期输出**:

```json
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get"
}
```

**测试 2: 带查询参数的 GET 请求**

```bash
curl "http://localhost:8080/session_http_001/get?name=Alice&age=30"
```

**预期输出**:

```json
{
  "args": {
    "age": "30",
    "name": "Alice"
  },
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/get?name=Alice&age=30"
}
```

**测试 3: POST 请求**

```bash
curl -X POST http://localhost:8080/session_http_001/post \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "age": 25
  }'
```

**预期输出**:

```json
{
  "args": {},
  "data": "{\n    \"username\": \"testuser\",\n    \"email\": \"test@example.com\",\n    \"age\": 25\n  }",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Content-Length": "80",
    "Content-Type": "application/json",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1"
  },
  "json": {
    "age": 25,
    "email": "test@example.com",
    "username": "testuser"
  },
  "origin": "192.168.65.1",
  "url": "http://localhost:8888/post"
}
```

**测试 4: 带自定义请求头**

```bash
curl http://localhost:8080/session_http_001/headers \
  -H "X-Custom-Header: MyValue" \
  -H "Authorization: Bearer token123"
```

**预期输出**:

```json
{
  "headers": {
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Authorization": "Bearer token123",
    "Host": "localhost:8888",
    "User-Agent": "curl/8.7.1",
    "X-Custom-Header": "MyValue"
  }
}
```

**测试 5: 流式响应**

```bash
# 测试流式传输（模拟 SSE 或 LLM API）
curl http://localhost:8080/session_http_001/stream/10
```

**预期输出**: 您会看到数据逐行流式返回，而不是一次性返回。

```console
2025-10-11T02:38:37.142132Z  INFO ss_proxy::proxy::http_proxy: Forwarding request to: GET http://localhost:8888/stream/10
2025-10-11T02:38:37.159392Z  INFO ss_proxy::proxy::http_proxy: Received response from downstream server: 200 OK
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 0}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 1}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 2}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 3}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 4}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 5}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 6}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 7}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 8}
{"url": "http://localhost:8888/stream/10", "args": {}, "headers": {"Host": "localhost:8888", "User-Agent": "curl/8.7.1", "Accept": "*/*", "Accept-Encoding": "gzip"}, "origin": "192.168.65.1", "id": 9}
```

**测试 6: 不同的 HTTP 方法**

```bash
# PUT 请求
curl -X PUT http://localhost:8080/session_http_001/put \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'

# DELETE 请求
curl -X DELETE http://localhost:8080/session_http_001/delete

# PATCH 请求
curl -X PATCH http://localhost:8080/session_http_001/patch \
  -H "Content-Type: application/json" \
  -d '{"key": "updated"}'
```

**测试 7: 处理错误情况**

```bash
# 测试不存在的会话
curl http://localhost:8080/non-existent-session/get
```

**预期输出**: Session not found 或类似错误

```console
Session not found: non-existent-session - no rows returned by a query that expected to return at least one row
```

### 1.7 清理环境

测试完成后，清理所有服务和资源。

```bash
# 停止代理服务器
pkill -f "ss-proxy" || killall ss-proxy

# 停止并删除测试服务
docker compose -f docker-compose.test.yml down

# （可选）删除测试数据库
rm sessions.db

# 验证清理完成
docker ps | grep ss-proxy-test  # 应该没有输出
```

**🎉 恭喜！您已成功完成 HTTP 代理示例！**

---

## 章节 2：WebSocket 代理完整示例

本示例将演示如何使用 ss-proxy 代理 WebSocket 连接。

### 2.1 环境准备

如果您已完成章节 1，测试服务应该已经运行。如果没有，请先执行：

```bash
# 确保在项目根目录
cd ss-proxy

# 启动测试服务（如果尚未启动）
docker compose -f docker-compose.test.yml up -d

# 等待服务就绪
sleep 15

# 验证 WebSocket echo 服务运行中
docker ps | grep ss-proxy-test-ws
```

**初始化数据库（如果尚未初始化）**:

```bash
chmod +x init_db.sh
./init_db.sh
```

### 2.2 配置 WebSocket 会话

```bash
# 添加 WebSocket 测试会话
sqlite3 sessions.db <<EOF
INSERT OR REPLACE INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_ws_001', 'ws://localhost:8890', 'active');
EOF

# 验证会话已添加
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_ws_001';"
```

**预期输出**:

```console
session_ws_001|ws://localhost:8890|active|2025-10-11 02:43:22|2025-10-11 02:43:22
```

### 2.3 启动代理服务器（如未运行）

```bash
# 检查代理服务器是否运行
curl http://localhost:8080/health 2>/dev/null || {
    echo "代理服务器未运行，正在启动..."
    cargo run --release &
    sleep 3
}

# 验证服务器运行
curl http://localhost:8080/health
```

**预期输出**:

```console
OK
```

### 2.4 测试 WebSocket 连接

我们将使用 `websocat` 工具来测试 WebSocket 连接。

**测试 1: 简单的 Echo 测试**

```bash
# 打开 WebSocket 连接并发送消息
# 注意：这是一个交互式会话
websocat ws://localhost:8080/ws/session_ws_001
```

启动后，您可以输入任何文本，服务器会将其回显（echo）。

**交互示例**:

```console
连接成功后，输入：
> Hello WebSocket!

预期输出：
< Hello WebSocket!

输入：
> {"type": "message", "data": "test"}

预期输出：
< {"type": "message", "data": "test"}

按 Ctrl+C 退出
```

**测试 2: 使用脚本发送消息**

```bash
# 发送单条消息并接收响应
# 注意：需要添加 sleep 以等待服务器响应
(echo "Test message from script"; sleep 0.5) | websocat ws://localhost:8080/ws/session_ws_001
```

**预期输出**:

```console
Test message from script
```

**测试 3: 发送多条消息**

创建一个测试脚本：

```bash
# 创建测试消息文件
cat > /tmp/ws-test-messages.txt <<EOF
Message 1: Hello
Message 2: WebSocket
Message 3: Proxy
Message 4: Test
EOF

# 通过 WebSocket 发送所有消息
# 注意：添加 sleep 以等待所有响应
(cat /tmp/ws-test-messages.txt; sleep 1) | websocat ws://localhost:8080/ws/session_ws_001
```

**预期输出**:

```console
Message 1: Hello
Message 2: WebSocket
Message 3: Proxy
Message 4: Test
```

**测试 4: 测试 JSON 消息**

```bash
# 发送 JSON 格式的消息
(echo '{"action": "ping", "timestamp": 1234567890}'; sleep 0.5) | \
  websocat ws://localhost:8080/ws/session_ws_001
```

**预期输出**:

```json
{"action": "ping", "timestamp": 1234567890}
```

**测试 5: 使用 curl 测试 WebSocket 升级**

```bash
# 测试 WebSocket 握手（HTTP 升级）
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  http://localhost:8080/ws/session_ws_001
```

**预期输出**:

```console
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: ...
```

**测试 6: 长连接测试**

```bash
# 测试长时间保持连接
# 每秒发送一条消息，持续 10 秒
(
  for i in {1..10}; do
    echo "Message at second $i"
    sleep 1
  done
) | websocat ws://localhost:8080/ws/session_ws_001
```

**预期输出**: 每秒收到一条回显消息，持续 10 秒。

**测试 7: 错误处理**

```bash
# 测试不存在的会话
echo "Test" | websocat ws://localhost:8080/ws/invalid-session 2>&1

# 预期输出: 连接失败或错误消息
```

### 2.5 清理环境

```bash
# 停止代理服务器
pkill -f "ss-proxy" || killall ss-proxy

# 停止测试服务
docker compose -f docker-compose.test.yml down

# 清理临时文件
rm -f /tmp/ws-test-messages.txt

# （可选）删除测试数据库
rm -f sessions.db

# 验证清理
docker ps | grep ss-proxy-test  # 应该没有输出
```

**🎉 恭喜！您已成功完成 WebSocket 代理示例！**

---

## 故障排查

### 服务启动失败

**问题**: Docker 服务无法启动

```bash
# 检查 Docker 是否运行
docker info

# 查看服务日志
docker compose -f docker-compose.test.yml logs

# 检查端口占用
lsof -i :8888
lsof -i :8889
lsof -i :8890

# 强制重启服务
docker compose -f docker-compose.test.yml down
docker compose -f docker-compose.test.yml up -d --force-recreate
```

### 代理连接失败

**问题**: 无法连接到代理服务器

```bash
# 检查代理服务器是否运行
ps aux | grep ss-proxy

# 检查端口监听
lsof -i :8080
netstat -an | grep 8080

# 查看代理服务器日志
# （如果在前台运行，可以直接看到日志）

# 重新启动代理
pkill -f ss-proxy
cargo run --release &
```

**问题**: Session not found 错误

```bash
# 验证会话配置
sqlite3 sessions.db "SELECT * FROM sessions;"

# 检查 session_id 拼写
# 确保 URL 中的 session_id 与数据库中的完全匹配
```

### WebSocket 连接问题

**问题**: websocat 命令未找到

```bash
# 安装 websocat
cargo install websocat

# 或使用 npm 安装 wscat
npm install -g wscat

# 使用 wscat 测试
wscat -c ws://localhost:8080/ws/session_ws_001
```

**问题**: WebSocket 连接立即断开

```bash
# 检查下游 WebSocket 服务
docker logs ss-proxy-test-ws

# 直接测试下游服务
websocat ws://localhost:8890

# 如果直接连接成功，问题可能在代理配置
sqlite3 sessions.db "SELECT * FROM sessions WHERE session_id = 'session_ws_001';"
```

---

**相关文档**:

- [README](../README.zh.md) - 项目概述
- [配置指南](CONFIGURATION.zh.md) - 详细配置说明
- [数据库操作](DATABASE.zh.md) - 数据库管理
- [路由规则](ROUTING.zh.md) - 路由配置
- [测试指南](TESTING.zh.md) - 测试套件说明
