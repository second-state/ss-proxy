# 测试指南

本文档详细介绍 ss-proxy 的测试套件、运行方法和 CI/CD 配置。

[English](TESTING.md) | 简体中文

- [测试指南](#测试指南)
  - [前提条件](#前提条件)
  - [测试架构](#测试架构)
  - [运行测试](#运行测试)
    - [方法 1: 使用 Docker 服务（推荐）](#方法-1-使用-docker-服务推荐)
    - [方法 2: 手动管理服务](#方法-2-手动管理服务)
    - [方法 3: 运行单个测试套件](#方法-3-运行单个测试套件)
  - [流式传输测试](#流式传输测试)
    - [测试覆盖](#测试覆盖)
  - [测试服务](#测试服务)
  - [测试用例详解](#测试用例详解)
    - [1. HTTP/HTTPS 代理测试](#1-httphttps-代理测试)
    - [2. WebSocket 代理测试](#2-websocket-代理测试)
    - [3. 健康检查测试](#3-健康检查测试)
    - [4. 流式传输测试](#4-流式传输测试)
  - [测试覆盖率](#测试覆盖率)
  - [Docker 测试的优势](#docker-测试的优势)
  - [CI/CD](#cicd)
    - [测试工作流 (`.github/workflows/test.yml`)](#测试工作流-githubworkflowstestyml)
    - [构建工作流 (`.github/workflows/build.yml`)](#构建工作流-githubworkflowsbuildyml)
  - [手动测试](#手动测试)
    - [测试 HTTP 代理](#测试-http-代理)
    - [测试 WebSocket 代理](#测试-websocket-代理)
    - [测试流式传输](#测试流式传输)
  - [故障排查](#故障排查)
    - [测试失败诊断](#测试失败诊断)
    - [端口冲突](#端口冲突)
    - [清理测试环境](#清理测试环境)
  - [性能测试](#性能测试)
    - [使用 Apache Bench](#使用-apache-bench)
    - [使用 wrk](#使用-wrk)
    - [使用 k6（推荐用于复杂场景）](#使用-k6推荐用于复杂场景)
  - [贡献测试](#贡献测试)

## 前提条件

- **Docker 和 Docker Compose**（用于测试服务）
- **Hurl**（用于 API 测试）
- **Rust 工具链**

## 测试架构

ss-proxy 使用多层测试策略：

1. **单元测试**: 测试独立的函数和模块
2. **集成测试**: 测试完整的 HTTP/HTTPS 和 WebSocket 代理功能
3. **API 测试**: 使用 Hurl 进行端到端 API 测试
4. **流式传输测试**: 验证流式响应支持（SSE、LLM API 等）

## 运行测试

### 方法 1: 使用 Docker 服务（推荐）

这种方法使用本地 Docker 容器提供所有测试依赖，无需依赖不稳定的外部服务：

```bash
# 运行所有测试（自动启动/停止服务）
./run_tests.sh

# 或使用自定义端口
TEST_PORT=10086 ./run_tests.sh
```

测试脚本会：

1. 构建项目
2. 启动 Docker 测试服务（httpbin、json-api、ws-echo）
3. 初始化测试数据库
4. 运行 Hurl API 测试
5. 运行 Rust 集成测试
6. 完成后自动停止服务

### 方法 2: 手动管理服务

```bash
# 启动测试服务
./scripts/start-test-services.sh

# 运行测试（跳过 Docker 服务管理）
USE_DOCKER_SERVICES=false ./run_tests.sh

# 停止测试服务
./scripts/stop-test-services.sh
```

### 方法 3: 运行单个测试套件

```bash
# 仅运行 Rust 单元测试
cargo test

# 仅运行 Rust 集成测试（包含 HTTP + WebSocket 测试）
cargo test --test integration

# 仅运行 Hurl HTTP API 测试（需要服务运行中）
hurl --test --variable port=8080 tests/http.hurl

# 运行流式传输测试
./test_streaming.sh
```

**注意**: WebSocket 测试仅在 Rust 集成测试 (`tests/integration.rs`) 中可用，因为 Hurl 不支持 WebSocket 消息协议。

## 流式传输测试

流式传输测试验证 ss-proxy 对流式响应的支持，包括 LLM API（如 OpenAI）的流式输出：

```bash
# 运行完整的流式传输测试套件
./test_streaming.sh

# 使用自定义端口
TEST_PROXY_PORT=9090 TEST_MOCK_PORT=10087 ./test_streaming.sh
```

### 测试覆盖

- ✅ 非流式请求转发 (`stream=false`)
- ✅ 流式请求转发 (`stream=true`)
- ✅ SSE (Server-Sent Events) 格式验证
- ✅ 首字节延迟 (TTFB) 性能测试
- ✅ 完整性验证（所有数据块正确转发）

详见：[流式传输测试文档](../tests/STREAMING_TEST_README.md)

## 测试服务

测试套件使用以下 Docker 服务（全部在本地运行）：

| 服务 | 端口 | 用途 | 替代 |
|---------|------|---------|----------|
| **httpbin** | 8888 | HTTP 测试服务 | httpbin.org |
| **json-api** | 8889 | REST API 测试服务 | jsonplaceholder.typicode.com |
| **ws-echo** | 8890 | WebSocket 回显服务 | echo.websocket.org |

所有服务在 `USE_DOCKER_SERVICES=true`（默认）时由 `run_tests.sh` 自动管理。

## 测试用例详解

### 1. HTTP/HTTPS 代理测试

**测试文件**: `tests/http.hurl`, `tests/integration.rs`

**测试场景**:

- ✅ GET 请求转发
- ✅ POST 请求转发
- ✅ 查询参数保留
- ✅ 自定义 Headers 转发
- ✅ Session 不存在错误处理
- ✅ Session 不可用错误处理

### 2. WebSocket 代理测试

**测试文件**: `tests/integration.rs`

**测试场景**:

- ✅ 文本消息回显
- ✅ 二进制消息回显
- ✅ 多条消息连续转发
- ✅ Session 不存在错误处理

### 3. 健康检查测试

**测试文件**: `tests/http.hurl`, `tests/integration.rs`

**测试场景**:

- ✅ `/health` 端点返回 200 OK

### 4. 流式传输测试

**测试文件**: `tests/streaming_test.hurl`, `test_streaming.sh`

**测试场景**:

- ✅ 非流式响应转发
- ✅ SSE 流式响应转发
- ✅ 首字节延迟测试
- ✅ 数据完整性验证

## 测试覆盖率

运行测试覆盖率分析：

```bash
# 安装 tarpaulin（如果未安装）
cargo install cargo-tarpaulin

# 生成覆盖率报告
cargo tarpaulin --out Html --output-dir coverage

# 查看报告
open coverage/index.html
```

## Docker 测试的优势

✅ **稳定**: 不依赖外部服务
✅ **快速**: 本地网络，无互联网延迟
✅ **可靠**: 一致的测试环境
✅ **离线**: 无需互联网连接即可测试
✅ **CI/CD 就绪**: 包含 GitHub Actions 集成

## CI/CD

项目包含 GitHub Actions 工作流，自动执行：

### 测试工作流 (`.github/workflows/test.yml`)

- 在 push/PR 时运行所有测试
- 两个独立的测试任务：
  - `test`: HTTP/HTTPS 和 WebSocket 代理测试
  - `streaming-test`: 流式响应测试
- 使用服务容器提供测试依赖
- 缓存 Rust 依赖以加快构建

### 构建工作流 (`.github/workflows/build.yml`)

- 运行代码检查和格式化检查
- 为多个平台构建二进制文件

## 手动测试

### 测试 HTTP 代理

```bash
# 1. 启动代理服务器
cargo run --release

# 2. 在数据库中插入测试数据
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_100', 'https://httpbin.org', 'active');
EOF

# 3. 测试请求
curl http://localhost:8080/session_100/get
curl -X POST http://localhost:8080/session_100/post -d '{"test":"data"}'
```

### 测试 WebSocket 代理

```bash
# 1. 启动代理服务器
cargo run --release

# 2. 在数据库中插入测试数据
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_200', 'wss://echo.websocket.org', 'active');
EOF

# 3. 使用 wscat 测试（需要安装：npm install -g wscat）
wscat -c ws://localhost:8080/ws/session_200
```

### 测试流式传输

```bash
# 1. 启动测试服务和代理
./test_streaming.sh

# 2. 手动测试流式端点
curl -N http://localhost:8080/session_streaming/stream
```

## 故障排查

### 测试失败诊断

1. **检查 Docker 服务状态**

   ```bash
   docker-compose -f docker-compose.test.yml ps
   ```

2. **查看服务日志**

   ```bash
   docker-compose -f docker-compose.test.yml logs httpbin
   docker-compose -f docker-compose.test.yml logs ws-echo
   ```

3. **手动测试服务**

   ```bash
   # 测试 httpbin
   curl http://localhost:8888/get

   # 测试 ws-echo
   wscat -c ws://localhost:8890
   ```

4. **启用详细日志**

   ```bash
   SS_PROXY_LOG_LEVEL=debug ./run_tests.sh
   ```

### 端口冲突

如果默认端口已被占用：

```bash
# 使用自定义端口
TEST_PORT=10086 ./run_tests.sh
```

### 清理测试环境

```bash
# 停止所有测试服务
docker-compose -f docker-compose.test.yml down

# 清理测试数据库
rm -f test_sessions_*.db

# 清理 Docker 资源
docker system prune -f
```

## 性能测试

虽然项目未包含专门的性能测试，但可以使用以下工具进行基准测试：

### 使用 Apache Bench

```bash
# 测试 HTTP 代理性能
ab -n 1000 -c 10 http://localhost:8080/test-http/get
```

### 使用 wrk

```bash
# 安装 wrk
# macOS: brew install wrk
# Ubuntu: sudo apt install wrk

# 运行基准测试
wrk -t4 -c100 -d30s http://localhost:8080/test-http/get
```

### 使用 k6（推荐用于复杂场景）

```bash
# 安装 k6
# macOS: brew install k6
# Ubuntu: snap install k6

# 创建测试脚本 load-test.js
# 运行负载测试
k6 run load-test.js
```

## 贡献测试

如果您要添加新功能，请确保：

1. ✅ 添加相应的单元测试
2. ✅ 添加集成测试（如果适用）
3. ✅ 更新 Hurl 测试文件（如果影响 API）
4. ✅ 运行完整测试套件确保通过
5. ✅ 更新测试文档

测试文件位置：

- 单元测试：在相应的源文件中（`#[cfg(test)]` 模块）
- 集成测试：`tests/integration.rs`
- API 测试：`tests/*.hurl`
- 测试数据：`tests/fixtures.sql`, `tests/mock-data/`
