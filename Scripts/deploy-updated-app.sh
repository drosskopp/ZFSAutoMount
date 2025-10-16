#!/bin/bash
#
# Deploy Updated ZFSAutoMount with Enhanced Logging
#

set -e

echo "======================================================="
echo "  Deploying Updated ZFSAutoMount"
echo "======================================================="
echo

# Kill running app
echo "🛑 Stopping running app..."
pkill -x ZFSAutoMount 2>/dev/null || true
sleep 1

# Remove old app
echo "🗑️  Removing old app from /Applications..."
sudo rm -rf /Applications/ZFSAutoMount.app

# Copy new app
echo "📦 Copying new app to /Applications..."
sudo cp -r ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-hclgmdjvkhhftlglkhaflibznaje/Build/Products/Release/ZFSAutoMount.app /Applications/

# Verify
if [ -d /Applications/ZFSAutoMount.app ]; then
    echo "✅ App deployed successfully"
else
    echo "❌ Deployment failed"
    exit 1
fi

echo
echo "======================================================="
echo "  Changes in This Version"
echo "======================================================="
echo
echo "✅ CRITICAL FIX: Datasets array populated before mounting"
echo "   - Now calls refreshPools() before trying to load keys"
echo "   - This was causing 'Found 0 encrypted datasets' bug"
echo
echo "✅ Fixed: Mount status verification"
echo "   - Now actually checks if datasets are mounted after operation"
echo "   - Reports failures when keys aren't loaded properly"
echo
echo "✅ Added: Comprehensive logging"
echo "   - NSLog() statements track every step of mounting process"
echo "   - Key loading attempts logged with success/failure"
echo "   - Dataset mount status logged after each operation"
echo
echo "✅ Fixed: UI not updating"
echo "   - Notification posting now happens on main thread"
echo "   - Menu bar will update when pools/datasets change"
echo
echo "✅ Helper reads keychain"
echo "   - Privileged helper checks system keychain (as root)"
echo "   - Falls back to user keychain if needed"
echo
echo "======================================================="
echo "  Testing Instructions"
echo "======================================================="
echo
echo "1. Unmount encrypted datasets:"
echo "   sudo zfs unmount tank/enc1 media/enc2"
echo "   sudo zfs unload-key tank/enc1 media/enc2"
echo
echo "2. Test mounting with --boot-mount (with logs):"
echo "   sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo
echo "3. Check logs for detailed debugging info:"
echo "   - Look for 'ZFSAutoMount:' prefixed messages"
echo "   - Shows which datasets were found"
echo "   - Shows key loading attempts and results"
echo "   - Shows mount verification results"
echo
echo "4. Verify actual mount status:"
echo "   zfs mount | grep -E 'tank/enc1|media/enc2'"
echo "   zfs get keystatus tank/enc1 media/enc2"
echo
echo "5. Test UI updates:"
echo "   - Open the app normally (menu bar)"
echo "   - Manually unmount: sudo zfs unmount tank/enc1"
echo "   - Click menu bar icon to see if status updated"
echo
echo "======================================================="
