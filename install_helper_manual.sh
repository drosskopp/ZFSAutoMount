#!/bin/bash
# Manual helper installation for development (without SMJobBless)
# This bypasses SMJobBless and installs the helper directly as a LaunchDaemon

set -e

echo "🔧 Manual Privileged Helper Installation"
echo "This script installs the helper as a LaunchDaemon (development only)"
echo ""

# Check if helper binary exists
HELPER_PATH="./build/Build/Products/Release/org.openzfs.automount.helper"
if [ ! -f "$HELPER_PATH" ]; then
    echo "❌ Helper binary not found at: $HELPER_PATH"
    echo "Building helper..."
    xcodebuild -project ZFSAutoMount.xcodeproj \
      -scheme PrivilegedHelper \
      -configuration Release \
      -derivedDataPath ./build \
      build
fi

echo "📦 Helper binary found"
echo ""

# Create LaunchDaemon plist
echo "📝 Creating LaunchDaemon plist..."
sudo tee /Library/LaunchDaemons/org.openzfs.automount.helper.plist > /dev/null << 'EOF'
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
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/var/log/zfs-automount-helper.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/zfs-automount-helper-error.log</string>
</dict>
</plist>
EOF

# Copy helper binary
echo "📋 Copying helper binary..."
sudo mkdir -p /Library/PrivilegedHelperTools
sudo cp "$HELPER_PATH" /Library/PrivilegedHelperTools/
sudo chmod 755 /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo chown root:wheel /Library/PrivilegedHelperTools/org.openzfs.automount.helper

# Set correct permissions on plist
sudo chown root:wheel /Library/LaunchDaemons/org.openzfs.automount.helper.plist
sudo chmod 644 /Library/LaunchDaemons/org.openzfs.automount.helper.plist

# Load the LaunchDaemon
echo "🚀 Loading helper daemon..."
sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.helper.plist

echo ""
echo "✅ Helper installed successfully!"
echo ""
echo "Helper location: /Library/PrivilegedHelperTools/org.openzfs.automount.helper"
echo "LaunchDaemon: /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
echo ""
echo "To check if it's running:"
echo "  sudo launchctl list | grep openzfs"
echo ""
echo "To view logs:"
echo "  tail -f /var/log/zfs-automount-helper.log"
echo ""
echo "To uninstall:"
echo "  sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
echo "  sudo rm /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
echo "  sudo rm /Library/PrivilegedHelperTools/org.openzfs.automount.helper"
