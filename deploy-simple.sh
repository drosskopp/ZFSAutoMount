#!/bin/bash
#
# Complete deployment with manual helper installation
# Works without Apple code signing (for development)
#

set -e

echo "=================================================="
echo "ZFSAutoMount Complete Deployment"
echo "=================================================="
echo ""

# Step 1: Build both targets
echo "🔨 Step 1: Building app and helper..."

echo "   → Building ZFSAutoMount app..."
xcodebuild -scheme ZFSAutoMount -configuration Debug build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ App build failed!"
    exit 1
fi
echo "   ✅ App build succeeded"

echo "   → Building PrivilegedHelper..."
xcodebuild -scheme PrivilegedHelper -configuration Debug build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Helper build failed!"
    exit 1
fi
echo "   ✅ Helper build succeeded"

echo "✅ Build complete"
echo ""

# Step 2: Stop app
echo "🛑 Step 2: Stopping ZFSAutoMount..."
killall ZFSAutoMount 2>/dev/null || true
sleep 1
echo "✅ App stopped"
echo ""

# Step 3: Remove old privileged helper
echo "🗑️  Step 3: Removing old privileged helper..."
echo "(You may be prompted for your password)"

sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist 2>/dev/null || true
sudo rm -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo rm -f /Library/LaunchDaemons/org.openzfs.automount.helper.plist

echo "✅ Old helper removed"
echo ""

# Step 4: Deploy app
echo "📋 Step 4: Deploying app to /Applications..."
sudo rm -rf /Applications/ZFSAutoMount.app
sudo cp -R /Users/yourname/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app /Applications/

echo "✅ App deployed"
echo ""

# Step 5: Install helper manually
echo "🔧 Step 5: Installing privileged helper..."

# Find the helper binary in DerivedData
HELPER_SOURCE=$(find ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug -name "org.openzfs.automount.helper" -type f | head -1)
HELPER_DEST="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
PLIST_DEST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"

if [ -z "$HELPER_SOURCE" ] || [ ! -f "$HELPER_SOURCE" ]; then
    echo "❌ Helper binary not found in build products!"
    echo ""
    echo "   Searched in:"
    echo "   ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug"
    echo ""
    echo "   This is a build configuration issue."
    echo "   The PrivilegedHelper target may not have built correctly."
    exit 1
fi

echo "   → Found helper: $HELPER_SOURCE"

# Copy helper binary
echo "   → Installing helper binary..."
sudo cp "$HELPER_SOURCE" "$HELPER_DEST"
sudo chown root:wheel "$HELPER_DEST"
sudo chmod 544 "$HELPER_DEST"
echo "   ✅ Helper binary installed"

# Create LaunchDaemon plist
echo "   → Creating LaunchDaemon plist..."
sudo tee "$PLIST_DEST" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.openzfs.automount.helper</string>
    <key>MachServices</key>
    <dict>
        <key>org.openzfs.automount.helper</key>
        <true/>
    </dict>
    <key>Program</key>
    <string>/Library/PrivilegedHelperTools/org.openzfs.automount.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/org.openzfs.automount.helper</string>
    </array>
    <key>KeepAlive</key>
    <false/>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardErrorPath</key>
    <string>/var/log/org.openzfs.automount.helper.log</string>
    <key>StandardOutPath</key>
    <string>/var/log/org.openzfs.automount.helper.log</string>
</dict>
</plist>
EOF

sudo chown root:wheel "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
echo "   ✅ LaunchDaemon plist created"

# Load the helper
echo "   → Loading helper into launchd..."
sudo launchctl load -w "$PLIST_DEST"

if [ $? -eq 0 ]; then
    echo "   ✅ Helper loaded successfully"
else
    echo "   ⚠️  Warning: Helper may not have loaded correctly"
fi

echo "✅ Helper installation complete"
echo ""

# Step 6: Launch app
echo "🚀 Step 6: Starting app..."
open /Applications/ZFSAutoMount.app
sleep 2

echo ""
echo "=================================================="
echo "✅ Deployment Complete!"
echo "=================================================="
echo ""

# Verify helper installation
if [ -f "$HELPER_DEST" ]; then
    echo "✅ Privileged helper is installed and ready"
    echo ""
    echo "   Helper binary: $HELPER_DEST"
    sudo ls -lh "$HELPER_DEST"
    echo ""
    echo "   Helper status:"
    sudo launchctl list | grep openzfs || echo "   ⚠️  Helper not loaded"
    echo ""
    echo "You can now use:"
    echo "  • Menu bar → Mount All Datasets"
    echo "  • Preferences → Maintenance → Run Now (scrub/TRIM)"
    echo "  • Automatic scheduling"
    echo ""
else
    echo "⚠️  Privileged helper NOT installed"
    echo ""
    echo "Some features won't work:"
    echo "  • Mount All Datasets"
    echo "  • Scrub/TRIM operations"
    echo ""
fi

echo "------------------------------------------------"
echo "Quick Tests:"
echo "------------------------------------------------"
echo ""
echo "Test scrub:"
echo "  Preferences → Maintenance → Run Now"
echo "  (Should show 'Scrub Started' alert)"
echo ""
echo "Test TRIM (if you have SSD pools):"
echo "  Preferences → Maintenance → Run Now (TRIM)"
echo ""
echo "Watch helper logs:"
echo "  sudo tail -f /var/log/org.openzfs.automount.helper.log"
echo ""
echo "Watch app logs:"
echo "  log stream --predicate 'process == \"ZFSAutoMount\"' --level debug"
echo ""
