#!/bin/bash

# Quick helper status check - no sudo needed for most checks

echo "Helper Status Check"
echo "==================="
echo ""

echo "1. App location:"
if [ -d "/Applications/ZFSAutoMount.app" ]; then
    echo "   ✅ /Applications/ZFSAutoMount.app"
    echo "   Built: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" /Applications/ZFSAutoMount.app)"
else
    echo "   ❌ App not found"
fi
echo ""

echo "2. Helper binary in app bundle:"
HELPER_IN_APP="/Applications/ZFSAutoMount.app/Contents/Library/LaunchServices/org.openzfs.automount.helper"
if [ -f "$HELPER_IN_APP" ]; then
    echo "   ✅ Found: $HELPER_IN_APP"
    ls -lh "$HELPER_IN_APP"
else
    echo "   ❌ Not found: $HELPER_IN_APP"
    echo ""
    echo "   Checking alternate location..."
    find /Applications/ZFSAutoMount.app -name "*helper*" -type f 2>/dev/null | head -5
fi
echo ""

echo "3. Installed helper binary:"
HELPER_INSTALLED="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
if [ -f "$HELPER_INSTALLED" ]; then
    echo "   ✅ Found: $HELPER_INSTALLED"
    echo "   (need sudo to see details)"
else
    echo "   ❌ Not installed: $HELPER_INSTALLED"
fi
echo ""

echo "4. Helper plist:"
PLIST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"
if [ -f "$PLIST" ]; then
    echo "   ✅ Found: $PLIST"
else
    echo "   ❌ Not found: $PLIST"
fi
echo ""

echo "5. App is running:"
if ps aux | grep -v grep | grep ZFSAutoMount > /dev/null; then
    echo "   ✅ Yes"
    ps aux | grep -v grep | grep ZFSAutoMount | awk '{print "   PID: " $2}'
else
    echo "   ❌ No"
fi
echo ""

echo "To check if helper is loaded (needs sudo):"
echo "  sudo launchctl list | grep openzfs"
echo ""
echo "To view helper logs (needs sudo):"
echo "  sudo tail -20 /var/log/org.openzfs.automount.helper.log"
echo ""
