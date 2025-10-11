#!/bin/bash

# ss-proxy database initialization script
# Purpose: Execute SQL scripts to create database table structure

set -e  # Exit immediately on error

# Default database path
DB_PATH="${1:-./sessions.db}"

echo "================================================"
echo "  ss-proxy Database Initialization Tool"
echo "================================================"
echo ""
echo "Database path: $DB_PATH"
echo ""

# Check if sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ Error: sqlite3 command not found"
    echo "Please install SQLite first: brew install sqlite"
    exit 1
fi

# Check if SQL script exists
if [ ! -f "migrations/init.sql" ]; then
    echo "❌ Error: migrations/init.sql file not found"
    exit 1
fi

# Execute SQL script
echo "Executing initialization script..."
if sqlite3 "$DB_PATH" < migrations/init.sql; then
    echo ""
    echo "================================================"
    echo "✅ Database initialization successful!"
    echo "================================================"
    echo ""
    echo "Database location: $DB_PATH"
    echo ""
    echo "View table schema:"
    echo "  sqlite3 $DB_PATH '.schema sessions'"
    echo ""
    echo "Query data:"
    echo "  sqlite3 $DB_PATH 'SELECT * FROM sessions;'"
    echo ""
else
    echo ""
    echo "❌ Database initialization failed"
    exit 1
fi
