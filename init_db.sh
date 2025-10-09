#!/bin/bash

# ss-proxy 数据库初始化脚本
# 用途：执行 SQL 脚本创建数据库表结构

set -e  # 遇到错误立即退出

# 默认数据库路径
DB_PATH="${1:-./sessions.db}"

echo "================================================"
echo "  ss-proxy 数据库初始化工具"
echo "================================================"
echo ""
echo "数据库路径: $DB_PATH"
echo ""

# 检查 sqlite3 是否安装
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ 错误: 未找到 sqlite3 命令"
    echo "请先安装 SQLite: brew install sqlite"
    exit 1
fi

# 检查 SQL 脚本是否存在
if [ ! -f "migrations/init.sql" ]; then
    echo "❌ 错误: 未找到 migrations/init.sql 文件"
    exit 1
fi

# 执行 SQL 脚本
echo "正在执行初始化脚本..."
if sqlite3 "$DB_PATH" < migrations/init.sql; then
    echo ""
    echo "================================================"
    echo "✅ 数据库初始化成功！"
    echo "================================================"
    echo ""
    echo "数据库位置: $DB_PATH"
    echo ""
    echo "查看表结构:"
    echo "  sqlite3 $DB_PATH '.schema sessions'"
    echo ""
    echo "查询数据:"
    echo "  sqlite3 $DB_PATH 'SELECT * FROM sessions;'"
    echo ""
else
    echo ""
    echo "❌ 数据库初始化失败"
    exit 1
fi
