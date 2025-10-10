#!/bin/bash

# 流式传输端到端测试脚本
# 测试 ss-proxy 的流式响应转发功能

set -e

echo "🧪 ss-proxy 流式传输测试"
echo "=========================="
echo ""

# 检测 CI 环境
CI_ENV=${CI:-false}
if [ "$CI_ENV" = "true" ]; then
    echo "🤖 运行在 CI 环境中"
fi
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置（支持环境变量覆盖）
PROXY_PORT=${TEST_PROXY_PORT:-8080}
MOCK_SERVER_PORT=${TEST_MOCK_PORT:-10086}
DB_PATH=${TEST_DB_PATH:-"./test_streaming.db"}
SESSION_ID="test-stream"

echo "配置信息："
echo "  Proxy 端口: $PROXY_PORT"
echo "  Mock 服务器端口: $MOCK_SERVER_PORT"
echo "  数据库路径: $DB_PATH"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo "🧹 清理测试环境..."

    if [ ! -z "$PROXY_PID" ]; then
        echo "停止 ss-proxy (PID: $PROXY_PID)..."
        kill $PROXY_PID 2>/dev/null || true
    fi

    if [ ! -z "$MOCK_PID" ]; then
        echo "停止 Mock 服务器 (PID: $MOCK_PID)..."
        kill $MOCK_PID 2>/dev/null || true
    fi

    if [ -f "$DB_PATH" ]; then
        rm -f "$DB_PATH"
    fi

    echo "✅ 清理完成"
}

trap cleanup EXIT

# 1. 编译项目
echo "📦 1. 编译 ss-proxy..."
cargo build --release
echo -e "${GREEN}✓${NC} 编译成功"
echo ""

# 2. 创建测试数据库
echo "📝 2. 创建测试数据库..."
rm -f "$DB_PATH"
sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    downstream_server_url TEXT NOT NULL,
    downstream_server_status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO sessions (session_id, downstream_server_url, downstream_server_status)
VALUES ('$SESSION_ID', 'http://localhost:$MOCK_SERVER_PORT', 'active');
EOF
echo -e "${GREEN}✓${NC} 数据库创建成功"
echo ""

# 3. 启动 Mock OpenAI 服务器
echo "🚀 3. 启动 Mock OpenAI 流式服务器..."

# 检测 Python 命令（CI 环境可能使用 python 而非 python3）
PYTHON_CMD="python3"
if ! command -v python3 &> /dev/null; then
    if command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo -e "${RED}✗${NC} 未找到 Python"
        exit 1
    fi
fi

$PYTHON_CMD tests/mock-data/mock-openai-stream.py $MOCK_SERVER_PORT > /tmp/mock-server.log 2>&1 &
MOCK_PID=$!
sleep 2

if ! kill -0 $MOCK_PID 2>/dev/null; then
    echo -e "${RED}✗${NC} Mock 服务器启动失败"
    cat /tmp/mock-server.log
    exit 1
fi

echo -e "${GREEN}✓${NC} Mock 服务器运行中 (PID: $MOCK_PID)"
echo ""

# 等待 Mock 服务器就绪
echo "⏳ 等待 Mock 服务器就绪..."
for i in {1..10}; do
    if curl -s http://localhost:$MOCK_SERVER_PORT/v1/chat/completions \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{"stream": false}' > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Mock 服务器已就绪"
        break
    fi
    if [ $i -eq 10 ]; then
        echo -e "${RED}✗${NC} Mock 服务器未能就绪"
        cat /tmp/mock-server.log
        exit 1
    fi
    sleep 1
done
echo ""

# 4. 启动 ss-proxy
echo "🚀 4. 启动 ss-proxy..."
./target/release/ss-proxy \
    --port $PROXY_PORT \
    --db-path "$DB_PATH" \
    --timeout 60 \
    --log-level info > /tmp/proxy.log 2>&1 &
PROXY_PID=$!
sleep 2

if ! kill -0 $PROXY_PID 2>/dev/null; then
    echo -e "${RED}✗${NC} ss-proxy 启动失败"
    cat /tmp/proxy.log
    exit 1
fi

echo -e "${GREEN}✓${NC} ss-proxy 运行中 (PID: $PROXY_PID)"
echo ""

# 5. 测试健康检查
echo "🏥 5. 测试健康检查..."
if curl -s http://localhost:$PROXY_PORT/health | grep -q "OK"; then
    echo -e "${GREEN}✓${NC} 健康检查通过"
else
    echo -e "${RED}✗${NC} 健康检查失败"
    exit 1
fi
echo ""

# 6. 测试直连 Mock 服务器（非流式）
echo "🧪 6. 测试直连 Mock 服务器（非流式）..."
RESPONSE=$(curl -s -X POST http://localhost:$MOCK_SERVER_PORT/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"stream": false, "messages": [{"role": "user", "content": "Hello"}]}')

if echo "$RESPONSE" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Mock 服务器响应正常"
else
    echo -e "${RED}✗${NC} Mock 服务器响应异常"
    echo "$RESPONSE"
    exit 1
fi
echo ""

# 7. 测试通过 Proxy 的非流式请求
echo "🔄 7. 测试通过 ss-proxy 的非流式请求..."
RESPONSE=$(curl -s -X POST http://localhost:$PROXY_PORT/$SESSION_ID/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"stream": false, "messages": [{"role": "user", "content": "Hello"}]}')

if echo "$RESPONSE" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} 非流式请求转发成功"
    echo "   响应: $(echo "$RESPONSE" | jq -r '.choices[0].message.content')"
else
    echo -e "${RED}✗${NC} 非流式请求转发失败"
    echo "$RESPONSE"
    exit 1
fi
echo ""

# 8. 测试通过 Proxy 的流式请求
echo "🌊 8. 测试通过 ss-proxy 的流式请求..."
echo -e "${YELLOW}   接收流式响应...${NC}"

TEMP_FILE=$(mktemp)
START_TIME=$(date +%s)

# 执行流式请求并捕获 HTTP 状态码
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_FILE" \
    -X POST http://localhost:$PROXY_PORT/$SESSION_ID/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"stream": true, "messages": [{"role": "user", "content": "Hello"}]}')

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 检查 HTTP 状态码
if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}✗${NC} HTTP 请求失败，状态码: $HTTP_CODE"
    echo "响应内容:"
    cat "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 检查响应内容
CHUNK_COUNT=$(grep -c "^data: " "$TEMP_FILE" || true)
HAS_DONE=$(grep -q "\[DONE\]" "$TEMP_FILE" && echo "yes" || echo "no")

if [ "$CHUNK_COUNT" -gt 0 ] && [ "$HAS_DONE" = "yes" ]; then
    echo -e "${GREEN}✓${NC} 流式请求转发成功"
    echo "   数据块数量: $CHUNK_COUNT"
    echo "   传输时间: ${DURATION}秒"
    echo "   已接收完整标记: ✓"

    # 提取并显示部分内容（使用更安全的方式）
    echo ""
    echo "   📄 响应示例（前3行）:"
    # 临时禁用 set -e 以避免 jq 错误导致脚本退出
    set +e
    head -n 3 "$TEMP_FILE" | while IFS= read -r line; do
        if [[ "$line" == data:* ]]; then
            # 移除 "data: " 前缀并尝试解析 JSON
            json_content="${line#data: }"
            CONTENT=$(echo "$json_content" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
            # 只在成功解析且非空时输出
            if [ $? -eq 0 ] && [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
                echo "      $CONTENT"
            fi
        fi
    done
    set -e
else
    echo -e "${RED}✗${NC} 流式请求转发失败"
    echo "   数据块数量: $CHUNK_COUNT (期望 > 0)"
    echo "   完成标记: $HAS_DONE (期望 yes)"
    echo ""
    echo "响应内容:"
    cat "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

rm -f "$TEMP_FILE"
echo ""

# 9. 性能测试 - 首字节延迟
echo "⚡ 9. 测试首字节延迟 (TTFB - Time To First Byte)..."

TEMP_FILE=$(mktemp)
curl -w "首字节延迟: %{time_starttransfer}s\n总时间: %{time_total}s\n" \
    -o "$TEMP_FILE" \
    -s -X POST http://localhost:$PROXY_PORT/$SESSION_ID/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"stream": true, "messages": [{"role": "user", "content": "Test"}]}'

rm -f "$TEMP_FILE"
echo ""

# 10. 总结
echo "════════════════════════"
echo -e "${GREEN}🎉 所有测试通过！${NC}"
echo "════════════════════════"
echo ""
echo "测试覆盖："
echo "  ✓ 健康检查"
echo "  ✓ 直连服务器测试"
echo "  ✓ 非流式请求转发"
echo "  ✓ 流式请求转发"
echo "  ✓ SSE 格式验证"
echo "  ✓ 首字节延迟测试"
echo ""
echo "📊 日志文件："
echo "  - Proxy 日志: /tmp/proxy.log"
echo "  - Mock 服务器日志: /tmp/mock-server.log"
echo ""
