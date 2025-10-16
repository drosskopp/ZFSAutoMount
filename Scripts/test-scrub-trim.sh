#!/bin/bash

# Script to test scrub and TRIM functionality
# This helps diagnose issues with the "Run Now" buttons

echo "=================================================="
echo "ZFS Scrub & TRIM Diagnostic Tool"
echo "=================================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script needs sudo privileges to run ZFS commands"
    echo "Please run with: sudo ./test-scrub-trim.sh"
    exit 1
fi

# Find zpool binary
ZPOOL_PATH=""
for path in /usr/local/zfs/bin/zpool /opt/homebrew/bin/zpool /usr/local/bin/zpool /usr/bin/zpool; do
    if [ -x "$path" ]; then
        ZPOOL_PATH="$path"
        break
    fi
done

if [ -z "$ZPOOL_PATH" ]; then
    echo "❌ zpool command not found!"
    exit 1
fi

echo "✅ Found zpool at: $ZPOOL_PATH"
echo ""

# List all pools
echo "📦 Available Pools:"
echo "===================="
$ZPOOL_PATH list -H -o name,health,size,allocated

if [ $? -ne 0 ]; then
    echo "❌ Failed to list pools"
    exit 1
fi

echo ""
echo "Select a pool to test scrub on:"
read -p "Pool name: " POOL_NAME

if [ -z "$POOL_NAME" ]; then
    echo "❌ No pool name provided"
    exit 1
fi

echo ""
echo "Testing pool: $POOL_NAME"
echo "===================="

# Show current status
echo ""
echo "1️⃣  Current pool status:"
echo "--------------------"
$ZPOOL_PATH status "$POOL_NAME" | grep -E "(scan:|scrub:)"

# Start scrub
echo ""
echo "2️⃣  Starting scrub..."
echo "--------------------"
$ZPOOL_PATH scrub "$POOL_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Scrub command executed successfully"
else
    echo "❌ Scrub command failed with exit code: $?"
    exit 1
fi

# Wait a moment
sleep 2

# Check status again
echo ""
echo "3️⃣  Status after starting scrub:"
echo "--------------------"
$ZPOOL_PATH status "$POOL_NAME" | grep -E "(scan:|scrub:)"

echo ""
echo "4️⃣  Full pool status:"
echo "--------------------"
$ZPOOL_PATH status "$POOL_NAME"

echo ""
echo "=================================================="
echo "Diagnostic Complete"
echo "=================================================="
echo ""
echo "If you see 'scrub in progress', the scrub is working!"
echo "Small pools may complete instantly."
echo ""
echo "To check TRIM support, run:"
echo "  diskutil info disk0 | grep 'Solid State'"
echo ""
