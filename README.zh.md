# ss-proxy

一个基于 Rust 构建的高性能代理服务器，支持 HTTP/HTTPS 和 WebSocket 协议转发，使用 SQLite 数据库管理会话和下游服务器信息。

[English](README.md) | 简体中文

- [ss-proxy](#ss-proxy)
  - [系统要求](#系统要求)
  - [功能特性](#功能特性)
  - [快速开始](#快速开始)
    - [1. 克隆项目](#1-克隆项目)
    - [2. 初始化数据库](#2-初始化数据库)
    - [3. 添加测试会话](#3-添加测试会话)
    - [4. 启动代理服务器](#4-启动代理服务器)
    - [5. 测试代理](#5-测试代理)
  - [快速示例](#快速示例)
    - [HTTP 代理](#http-代理)
    - [WebSocket 代理](#websocket-代理)
  - [路由规则](#路由规则)
  - [错误处理](#错误处理)
  - [开发指南](#开发指南)
    - [代码检查和格式化](#代码检查和格式化)
    - [常用命令](#常用命令)
    - [运行测试](#运行测试)
  - [文档](#文档)

## 系统要求

- **Rust**: 1.90.0+（支持 Edition 2024）
- **SQLite**: 3.x
- **操作系统**: Linux / macOS / Windows

> **注意**: 项目使用 `rust-toolchain.toml` 自动管理 Rust 版本。首次克隆项目时，`rustup` 会自动下载并安装 Rust 1.90.0。

## 功能特性

- 🚀 **高性能异步代理**: 基于 Tokio 和 Axum 构建
- 🔄 **协议支持**: 支持 HTTP/HTTPS 和 WebSocket 代理
- 🌊 **流式传输**: 原生支持流式响应（SSE、LLM API、分块编码）
- 💾 **会话管理**: 使用 SQLite 数据库存储会话信息
- 🎯 **动态路由**: 根据 session_id 动态转发到不同的下游服务器
- ⚡ **连接池**: 内置数据库连接池和 HTTP 客户端连接池
- 📊 **状态检查**: 支持下游服务器状态验证

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/second-state/ss-proxy.git
cd ss-proxy
```

进入项目目录后，`rustup` 会自动安装 Rust 1.90.0（如果尚未安装）。

### 2. 初始化数据库

```bash
# 添加脚本执行权限并运行
chmod +x init_db.sh
./init_db.sh
```

这将创建 `./sessions.db` 数据库文件。关于数据库结构和详细操作，请参阅 [数据库操作指南](docs/DATABASE.zh.md)。

### 3. 添加测试会话

```bash
sqlite3 sessions.db <<EOF
INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('session_001', 'https://httpbin.org', 'active');
EOF
```

### 4. 启动代理服务器

```bash
# 使用默认配置（0.0.0.0:8080）
cargo run --release

# 或自定义端口
cargo run --release -- --port 9090
```

更多配置选项请参阅 [配置指南](docs/CONFIGURATION.zh.md)。

### 5. 测试代理

```bash
# 测试 HTTP 代理
curl http://localhost:8080/session_001/get

# 测试健康检查
curl http://localhost:8080/health
```

## 快速示例

### HTTP 代理

```bash
curl http://localhost:8080/session_001/get
```

### WebSocket 代理

```bash
wscat -c ws://localhost:8080/ws/session_001
```

> 💡 **提示**: 想要完整的端到端示例？请查看 [完整示例教程](docs/EXAMPLES.zh.md)，其中包含详细的步骤和多个测试场景。

> 💡 **提示**: 更多使用示例（POST 请求、流式传输、查询参数等）请参阅 [路由规则详解](docs/ROUTING.zh.md)。

## 路由规则

ss-proxy 支持 HTTP/HTTPS 和 WebSocket 代理，具有不同的转发行为：

- **HTTP/HTTPS**: session_id 仅用于查询数据库，不会出现在下游 URL 中
- **WebSocket**: session_id 会被追加到下游 WebSocket URL 的路径中

详细的路由规则、转发行为和示例，请参阅 [路由规则详解](docs/ROUTING.zh.md)。

## 错误处理

| HTTP 状态码 | 说明 |
|------------|------|
| `200-5xx` | 下游服务器的原始响应 |
| `404` | session_id 不存在 |
| `503` | 下游服务器不可用（状态非 active） |
| `502` | 无法连接到下游服务器 |

## 开发指南

### 代码检查和格式化

```bash
# 代码检查
cargo clippy

# 格式化代码
cargo fmt

# 检查格式（不修改）
cargo fmt --check
```

### 常用命令

```bash
# 快速检查（不生成二进制文件）
cargo check

# 开发构建
cargo build

# 发布构建（优化）
cargo build --release

# 运行项目
cargo run

# 运行测试
cargo test

# 清理构建产物
cargo clean
```

### 运行测试

```bash
# 运行所有测试（推荐）
./run_tests.sh

# 仅运行单元测试
cargo test

# 仅运行集成测试
cargo test --test integration
```

详细的测试指南请参阅 [测试文档](docs/TESTING.zh.md)。

## 文档

- � [完整示例教程](docs/EXAMPLES.zh.md) - 端到端示例和测试场景
- �📖 [数据库操作指南](docs/DATABASE.zh.md) - 数据库结构和操作详解
- ⚙️ [配置指南](docs/CONFIGURATION.zh.md) - 配置选项和部署建议
- 🧪 [测试指南](docs/TESTING.zh.md) - 测试套件和 CI/CD 说明
- 🔀 [路由规则详解](docs/ROUTING.zh.md) - 路由规则和请求转发行为
