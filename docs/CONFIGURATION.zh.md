# 配置指南

本文档详细介绍 ss-proxy 的配置选项和使用方法。

[English](CONFIGURATION.md) | 简体中文

- [配置指南](#配置指南)
  - [命令行参数](#命令行参数)
    - [可用参数](#可用参数)
    - [配置优先级](#配置优先级)
  - [使用示例](#使用示例)
    - [1. 使用默认配置](#1-使用默认配置)
    - [2. 自定义端口和数据库路径](#2-自定义端口和数据库路径)
    - [3. 使用短选项](#3-使用短选项)
    - [4. 通过环境变量配置](#4-通过环境变量配置)
    - [5. 混合使用（CLI 参数优先级高于环境变量）](#5-混合使用cli-参数优先级高于环境变量)
    - [6. 直接运行编译后的二进制文件](#6-直接运行编译后的二进制文件)
    - [7. 查看帮助信息](#7-查看帮助信息)
  - [日志配置](#日志配置)
    - [设置日志级别](#设置日志级别)
    - [日志级别说明](#日志级别说明)
    - [使用 RUST\_LOG 进行高级控制](#使用-rust_log-进行高级控制)
  - [性能调优](#性能调优)
    - [1. 请求超时设置](#1-请求超时设置)
    - [2. 数据库位置](#2-数据库位置)
    - [3. 网络绑定](#3-网络绑定)
  - [生产环境部署建议](#生产环境部署建议)
    - [1. 使用 systemd 服务（Linux）](#1-使用-systemd-服务linux)
    - [2. 使用 Docker](#2-使用-docker)
    - [3. 配置文件管理](#3-配置文件管理)
  - [故障排查](#故障排查)
    - [1. 检查配置](#1-检查配置)
    - [2. 启用详细日志](#2-启用详细日志)
    - [3. 测试数据库连接](#3-测试数据库连接)
    - [4. 检查端口占用](#4-检查端口占用)

## 命令行参数

ss-proxy 支持通过命令行参数和环境变量进行配置。

### 可用参数

| 参数 | 短选项 | 环境变量 | 默认值 | 说明 |
|------|--------|----------|--------|------|
| `--host` | `-H` | `SS_PROXY_HOST` | `0.0.0.0` | 监听地址 |
| `--port` | `-p` | `SS_PROXY_PORT` | `8080` | 监听端口 |
| `--db-path` | `-d` | `SS_PROXY_DB_PATH` | `./sessions.db` | 数据库文件路径 |
| `--timeout` | `-t` | `SS_PROXY_TIMEOUT` | `30` | 请求超时时间（秒） |
| `--log-level` | `-l` | `SS_PROXY_LOG_LEVEL` | `info` | 日志级别 (trace/debug/info/warn/error) |
| `--help` | `-h` | - | - | 显示帮助信息 |
| `--version` | `-V` | - | - | 显示版本信息 |

### 配置优先级

配置加载顺序（优先级从高到低）：

1. 命令行参数
2. 环境变量
3. 默认值

## 使用示例

### 1. 使用默认配置

```bash
cargo run --release
```

服务器将在 `0.0.0.0:8080` 启动，使用 `./sessions.db` 数据库。

### 2. 自定义端口和数据库路径

```bash
cargo run --release -- --port 9090 --db-path /data/sessions.db
```

### 3. 使用短选项

```bash
cargo run --release -- -p 9090 -d /data/sessions.db -l debug
```

### 4. 通过环境变量配置

```bash
export SS_PROXY_PORT=9090
export SS_PROXY_DB_PATH=/data/sessions.db
export SS_PROXY_LOG_LEVEL=debug
cargo run --release
```

### 5. 混合使用（CLI 参数优先级高于环境变量）

```bash
export SS_PROXY_PORT=8080
cargo run --release -- --port 9090  # 实际使用 9090
```

### 6. 直接运行编译后的二进制文件

```bash
# 编译
cargo build --release

# 运行
./target/release/ss-proxy --port 9090 --log-level debug

# 或使用环境变量
SS_PROXY_PORT=9090 ./target/release/ss-proxy
```

### 7. 查看帮助信息

```bash
cargo run --release -- --help
```

## 日志配置

### 设置日志级别

通过 `--log-level` 参数或 `SS_PROXY_LOG_LEVEL` 环境变量：

```bash
# 详细日志
cargo run --release -- --log-level debug

# 只显示错误
cargo run --release -- --log-level error

# 使用环境变量
SS_PROXY_LOG_LEVEL=trace cargo run --release
```

### 日志级别说明

- `trace`: 最详细的日志，包含所有细节
- `debug`: 调试信息，用于开发和故障排查
- `info`: 常规信息（默认级别）
- `warn`: 警告信息
- `error`: 错误信息

### 使用 RUST_LOG 进行高级控制

对于更细粒度的日志控制，可以使用 `RUST_LOG` 环境变量：

```bash
# 只显示 ss-proxy 的 debug 日志
RUST_LOG=ss_proxy=debug cargo run --release

# 显示多个模块的日志
RUST_LOG=ss_proxy=debug,tower_http=info cargo run --release

# 显示所有依赖的 trace 日志
RUST_LOG=trace cargo run --release
```

## 性能调优

### 1. 请求超时设置

根据下游服务器的响应时间调整超时：

```bash
# 增加超时到 60 秒（适用于慢速 API）
cargo run --release -- --timeout 60

# 减少超时到 10 秒（适用于快速 API）
cargo run --release -- --timeout 10
```

### 2. 数据库位置

将数据库放在高性能存储上：

```bash
# 使用 SSD 路径
cargo run --release -- --db-path /ssd/data/sessions.db

# 使用内存数据库（重启后数据丢失）
cargo run --release -- --db-path :memory:
```

### 3. 网络绑定

根据部署环境选择合适的绑定地址：

```bash
# 仅本地访问
cargo run --release -- --host 127.0.0.1

# 允许所有网络接口访问（生产环境）
cargo run --release -- --host 0.0.0.0

# 绑定到特定网络接口
cargo run --release -- --host 192.168.1.100
```

## 生产环境部署建议

### 1. 使用 systemd 服务（Linux）

创建服务文件 `/etc/systemd/system/ss-proxy.service`：

```ini
[Unit]
Description=SS Proxy Server
After=network.target

[Service]
Type=simple
User=ssProxy
WorkingDirectory=/opt/ss-proxy
Environment="SS_PROXY_PORT=8080"
Environment="SS_PROXY_DB_PATH=/var/lib/ss-proxy/sessions.db"
Environment="SS_PROXY_LOG_LEVEL=info"
ExecStart=/opt/ss-proxy/ss-proxy
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable ss-proxy
sudo systemctl start ss-proxy
sudo systemctl status ss-proxy
```

### 2. 使用 Docker

创建 `Dockerfile`：

```dockerfile
FROM rust:1.90 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y sqlite3 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/ss-proxy /usr/local/bin/
COPY --from=builder /app/migrations /migrations
WORKDIR /data
EXPOSE 8080
CMD ["ss-proxy", "--host", "0.0.0.0", "--port", "8080", "--db-path", "/data/sessions.db"]
```

运行容器：

```bash
docker build -t ss-proxy .
docker run -d -p 8080:8080 -v /path/to/data:/data ss-proxy
```

### 3. 配置文件管理

虽然 ss-proxy 不使用配置文件，但可以通过脚本管理环境变量：

创建 `config.env`：

```bash
SS_PROXY_HOST=0.0.0.0
SS_PROXY_PORT=8080
SS_PROXY_DB_PATH=/var/lib/ss-proxy/sessions.db
SS_PROXY_TIMEOUT=30
SS_PROXY_LOG_LEVEL=info
```

使用配置文件：

```bash
# 加载配置并运行
export $(cat config.env | xargs) && ./ss-proxy
```

## 故障排查

### 1. 检查配置

```bash
# 查看版本和帮助
./ss-proxy --version
./ss-proxy --help
```

### 2. 启用详细日志

```bash
# 使用 debug 级别查看详细信息
./ss-proxy --log-level debug
```

### 3. 测试数据库连接

```bash
# 检查数据库文件是否存在
ls -la sessions.db

# 测试数据库连接
sqlite3 sessions.db 'SELECT COUNT(*) FROM sessions;'
```

### 4. 检查端口占用

```bash
# Linux/macOS
lsof -i :8080

# 或使用 netstat
netstat -tuln | grep 8080
```
