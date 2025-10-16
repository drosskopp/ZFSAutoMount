#!/bin/bash

# Manual privileged helper installation
# Use this if SMJobBless is failing (CFErrorDomainLaunchd error 2)

set -e

echo "=================================================="
echo "Manual Privileged Helper Installation"
echo "=================================================="
echo ""
echo "This script manually installs the privileged helper,"
echo "bypassing the SMJobBless mechanism."
echo ""
echo "You will be prompted for your admin password."
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Find the helper binary in the built app
HELPER_SOURCE="/Applications/ZFSAutoMount.app/Contents/Library/LaunchServices/org.openzfs.automount.helper"
HELPER_DEST="/Library/PrivilegedHelperTools/org.openzfs.automount.helper"
PLIST_DEST="/Library/LaunchDaemons/org.openzfs.automount.helper.plist"

# Step 1: Verify source exists
echo "1. Checking for helper binary in app bundle..."
if [ ! -f "$HELPER_SOURCE" ]; then
    echo "❌ Helper binary not found in app bundle!"
    echo "   Expected: $HELPER_SOURCE"
    echo ""
    echo "The app may not be built correctly."
    echo "Try rebuilding:"
    echo "  cd /Users/sysop/src/github.com/drosskopp/ZFSAutoMount"
    echo "  xcodebuild -scheme ZFSAutoMount -configuration Debug build"
    exit 1
fi
echo "✅ Found helper binary"
echo ""

# Step 2: Remove old helper if exists
echo "2. Removing old helper (if exists)..."
sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true
sudo rm -f "$HELPER_DEST"
sudo rm -f "$PLIST_DEST"
echo "✅ Old helper removed"
echo ""

# Step 3: Copy helper binary
echo "3. Installing helper binary..."
sudo cp "$HELPER_SOURCE" "$HELPER_DEST"
sudo chown root:wheel "$HELPER_DEST"
sudo chmod 544 "$HELPER_DEST"
echo "✅ Helper binary installed"
echo ""

# Step 4: Create LaunchDaemon plist
echo "4. Creating LaunchDaemon plist..."

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
echo "✅ LaunchDaemon plist created"
echo ""

# Step 5: Load the helper
echo "5. Loading helper into launchd..."
sudo launchctl load -w "$PLIST_DEST"

if [ $? -eq 0 ]; then
    echo "✅ Helper loaded successfully"
else
    echo "❌ Failed to load helper"
    exit 1
fi
echo ""

# Step 6: Verify
echo "6. Verifying installation..."
echo ""

# Check file exists
if [ -f "$HELPER_DEST" ]; then
    echo "✅ Helper binary installed:"
    ls -la "$HELPER_DEST"
else
    echo "❌ Helper binary missing"
fi

echo ""

# Check if loaded
LOADED=$(sudo launchctl list | grep openzfs || echo "")
if [ -n "$LOADED" ]; then
    echo "✅ Helper loaded in launchd:"
    echo "   $LOADED"
else
    echo "❌ Helper not loaded"
fi

echo ""
echo "=================================================="
echo "✅ Installation Complete!"
echo "=================================================="
echo ""
echo "The privileged helper is now installed and running."
echo ""
echo "Next steps:"
echo "1. Restart the ZFSAutoMount app:"
echo "   killall ZFSAutoMount"
echo "   open /Applications/ZFSAutoMount.app"
echo ""
echo "2. Test scrub:"
echo "   Preferences → Maintenance → Run Now"
echo ""
echo "3. You should see 'Scrub Started' instead of an error"
echo ""
echo "To view helper logs:"
echo "  sudo tail -f /var/log/org.openzfs.automount.helper.log"
echo ""
