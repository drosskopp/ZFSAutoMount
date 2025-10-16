#!/bin/bash

# Quick fix for "Unknown command: scrub_pool" error
# Removes old helper and triggers reinstall

echo "🔧 Quick Helper Fix"
echo "==================="
echo ""

# Step 1: Remove old helper
echo "Step 1: Removing old helper..."
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist 2>/dev/null
sudo rm -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo rm -f /Library/LaunchDaemons/org.openzfs.automount.helper.plist

if [ $? -eq 0 ]; then
    echo "✅ Old helper removed"
else
    echo "⚠️  No old helper found (OK if first install)"
fi

# Step 2: Kill running app
echo ""
echo "Step 2: Restarting app..."
killall ZFSAutoMount 2>/dev/null
sleep 1

# Step 3: Rebuild
echo ""
echo "Step 3: Rebuilding app with new helper..."
cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount
xcodebuild -scheme ZFSAutoMount -configuration Debug build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded"
else
    echo "❌ Build failed - check Xcode"
    exit 1
fi

# Step 4: Deploy
echo ""
echo "Step 4: Deploying to /Applications..."
rm -rf /Applications/ZFSAutoMount.app
cp -R ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app /Applications/

if [ $? -eq 0 ]; then
    echo "✅ App deployed"
else
    echo "❌ Failed to deploy app"
    exit 1
fi

# Step 5: Launch
echo ""
echo "Step 5: Launching app..."
open /Applications/ZFSAutoMount.app
sleep 2

echo ""
echo "=================================================="
echo "✅ Fix Complete!"
echo "=================================================="
echo ""
echo "Now do this:"
echo "1. Click the ZFS menu bar icon"
echo "2. Click 'Mount All Datasets'"
echo "3. Enter your admin password (installs new helper)"
echo "4. Go to Preferences → Maintenance"
echo "5. Click 'Run Now' for scrub"
echo ""
echo "You should now see 'Scrub Started' instead of an error!"
echo ""
