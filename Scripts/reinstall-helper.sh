#!/bin/bash

# Script to reinstall the privileged helper
# This is needed after adding new commands (like scrub_pool and trim_pool)

echo "=================================================="
echo "Privileged Helper Reinstallation"
echo "=================================================="
echo ""

HELPER_PATH="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
HELPER_PLIST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"

echo "This script will:"
echo "1. Remove the old privileged helper"
echo "2. Force reinstallation with new commands"
echo ""
echo "You will need to enter your admin password."
echo ""

# Check if helper exists
if [ -f "$HELPER_PATH" ]; then
    echo "✅ Found existing helper at: $HELPER_PATH"

    # Show version/date
    ls -la "$HELPER_PATH"
    echo ""

    # Unload from launchd
    echo "Unloading helper from launchd..."
    sudo launchctl unload "$HELPER_PLIST" 2>/dev/null

    # Remove helper binary
    echo "Removing old helper binary..."
    sudo rm -f "$HELPER_PATH"

    # Remove plist
    echo "Removing old helper plist..."
    sudo rm -f "$HELPER_PLIST"

    echo "✅ Old helper removed"
else
    echo "ℹ️  No existing helper found (this is OK for first install)"
fi

echo ""
echo "=================================================="
echo "Next Steps:"
echo "=================================================="
echo ""
echo "1. Quit ZFSAutoMount if it's running:"
echo "   killall ZFSAutoMount"
echo ""
echo "2. Rebuild the app to ensure latest helper binary:"
echo "   cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount"
echo "   xcodebuild -scheme ZFSAutoMount -configuration Debug build"
echo ""
echo "3. Copy the app to Applications:"
echo "   rm -rf /Applications/ZFSAutoMount.app"
echo "   cp -R ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app /Applications/"
echo ""
echo "4. Launch the app:"
echo "   open /Applications/ZFSAutoMount.app"
echo ""
echo "5. Trigger helper installation by clicking:"
echo "   Menu Bar → Mount All Datasets"
echo "   (Enter admin password when prompted)"
echo ""
echo "6. Test scrub by going to:"
echo "   Preferences → Maintenance → Run Now"
echo ""
echo "The new helper will be installed with scrub_pool and trim_pool commands!"
echo ""
