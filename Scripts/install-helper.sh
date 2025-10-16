#!/bin/bash
#
# Install Updated Privileged Helper
#

set -e

HELPER_SRC="build/Release/org.openzfs.automount.helper"
HELPER_DST="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
PLIST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"

echo "======================================================="
echo "  Installing Updated Privileged Helper"
echo "======================================================="
echo

if [ ! -f "$HELPER_SRC" ]; then
    echo "❌ Helper binary not found: $HELPER_SRC"
    echo "   Run: xcodebuild -project ZFSAutoMount.xcodeproj -target PrivilegedHelper -configuration Release build"
    exit 1
fi

# Show version info
echo "📦 Helper to install:"
ls -lh "$HELPER_SRC"
stat -f "   Modified: %Sm" -t "%Y-%m-%d %H:%M:%S" "$HELPER_SRC"
echo

if [ -f "$HELPER_DST" ]; then
    echo "📦 Currently installed helper:"
    sudo ls -lh "$HELPER_DST"
    sudo stat -f "   Modified: %Sm" -t "%Y-%m-%d %H:%M:%S" "$HELPER_DST"
    echo
fi

# Unload if running
echo "🛑 Unloading helper daemon..."
sudo launchctl bootout system "$PLIST" 2>/dev/null || true
sleep 1

# Install new helper
echo "📥 Installing new helper..."
sudo cp "$HELPER_SRC" "$HELPER_DST"
sudo chown root:wheel "$HELPER_DST"
sudo chmod 544 "$HELPER_DST"

echo "✅ Helper installed"
ls -lh "$HELPER_DST"
echo

# Load helper
echo "🚀 Loading helper daemon..."
sudo launchctl bootstrap system "$PLIST"

# Verify it's running
sleep 1
if sudo launchctl print system/org.openzfs.automount.helper &>/dev/null; then
    echo "✅ Helper daemon is running"
else
    echo "❌ Helper daemon failed to start"
    echo "   Check logs with: sudo log show --predicate 'process == \"org.openzfs.automount.helper\"' --last 2m"
    exit 1
fi

echo
echo "======================================================="
echo "  Installation Complete"
echo "======================================================="
echo
echo "Changes in this helper version:"
echo "  • Reads encryption keys from system keychain (as root)"
echo "  • Falls back to user keychain if needed"
echo "  • Detailed logging for debugging (NSLog)"
echo
echo "Next steps:"
echo "  1. Test with: sudo zfs unmount tank/enc1"
echo "  2. Then: sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo "  3. Check helper logs with:"
echo "     sudo log show --predicate 'eventMessage contains \"ZFSAutoMount Helper\"' --last 2m --info"
echo
echo "======================================================="
