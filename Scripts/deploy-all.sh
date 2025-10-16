#!/bin/bash
#
# Deploy Complete ZFSAutoMount Update
# This deploys both the main app AND the privileged helper
#

set -e

echo "======================================================="
echo "  Complete ZFSAutoMount Deployment"
echo "======================================================="
echo

# Check build artifacts
APP_SRC="$HOME/Library/Developer/Xcode/DerivedData/ZFSAutoMount-hclgmdjvkhhftlglkhaflibznaje/Build/Products/Release/ZFSAutoMount.app"
HELPER_SRC="build/Release/org.openzfs.automount.helper"

if [ ! -d "$APP_SRC" ]; then
    echo "❌ App not found: $APP_SRC"
    echo "   Run: xcodebuild -project ZFSAutoMount.xcodeproj -scheme ZFSAutoMount -configuration Release build"
    exit 1
fi

if [ ! -f "$HELPER_SRC" ]; then
    echo "❌ Helper not found: $HELPER_SRC"
    echo "   Run: xcodebuild -project ZFSAutoMount.xcodeproj -target PrivilegedHelper -configuration Release build"
    exit 1
fi

echo "📦 Artifacts ready:"
echo "   App: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$APP_SRC")"
echo "   Helper: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$HELPER_SRC")"
echo

# ============================================================================
# 1. Deploy Main App
# ============================================================================

echo "======================================================="
echo "  Step 1: Deploying Main Application"
echo "======================================================="
echo

echo "🛑 Stopping running app..."
pkill -x ZFSAutoMount 2>/dev/null || true
sleep 1

echo "🗑️  Removing old app..."
sudo rm -rf /Applications/ZFSAutoMount.app

echo "📥 Installing new app..."
sudo cp -r "$APP_SRC" /Applications/

if [ -d /Applications/ZFSAutoMount.app ]; then
    echo "✅ App deployed successfully"
else
    echo "❌ App deployment failed"
    exit 1
fi

echo

# ============================================================================
# 2. Deploy Privileged Helper
# ============================================================================

echo "======================================================="
echo "  Step 2: Deploying Privileged Helper"
echo "======================================================="
echo

HELPER_DST="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
PLIST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"

echo "🛑 Unloading helper daemon..."
sudo launchctl bootout system "$PLIST" 2>/dev/null || true
sleep 1

echo "📥 Installing new helper..."
sudo cp "$HELPER_SRC" "$HELPER_DST"
sudo chown root:wheel "$HELPER_DST"
sudo chmod 544 "$HELPER_DST"

echo "✅ Helper installed"

echo "🚀 Loading helper daemon..."
sudo launchctl bootstrap system "$PLIST"
sleep 1

if sudo launchctl print system/org.openzfs.automount.helper &>/dev/null; then
    echo "✅ Helper daemon is running"
else
    echo "❌ Helper daemon failed to start"
    exit 1
fi

echo

# ============================================================================
# Summary
# ============================================================================

echo "======================================================="
echo "  ✅ Deployment Complete!"
echo "======================================================="
echo
echo "🎉 What's New in This Version:"
echo
echo "1. CRITICAL FIX: Dataset array population"
echo "   • Now calls refreshPools() before loading keys"
echo "   • Fixes 'Found 0 encrypted datasets' bug"
echo
echo "2. Privileged Helper Keychain Access"
echo "   • Helper now reads system keychain (as root)"
echo "   • Falls back to user keychain if needed"
echo "   • Detailed NSLog logging for debugging"
echo
echo "3. Actual Mount Verification"
echo "   • Verifies datasets are mounted after operation"
echo "   • Reports specific failures instead of false success"
echo
echo "4. Automatic Menu Bar Refresh"
echo "   • Updates every 30 seconds automatically"
echo "   • Shows current mount status without manual refresh"
echo
echo "5. Comprehensive Logging"
echo "   • Tracks every step of mounting process"
echo "   • Helps debug keychain and mount issues"
echo
echo "======================================================="
echo "  Next Steps"
echo "======================================================="
echo
echo "Option A: Test boot-mount functionality"
echo "   sudo zfs unmount tank/enc1"
echo "   sudo zfs unload-key tank/enc1"
echo "   sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo
echo "Option B: Test menu bar app"
echo "   1. Open ZFSAutoMount from Applications folder"
echo "   2. Click menu bar icon"
echo "   3. Try 'Refresh Pools' or 'Mount All Datasets'"
echo "   4. Wait 30 seconds to see automatic refresh"
echo
echo "Option C: Check helper logs"
echo "   sudo log show --predicate 'eventMessage contains \"ZFSAutoMount Helper\"' --last 5m --info"
echo
echo "Option D: Run automated test"
echo "   ./test-mount.sh"
echo
echo "======================================================="
