#!/bin/bash
# Install helper on Mac Mini (run this ON the Mac mini)

set -e

echo "🔧 Installing ZFS AutoMount Privileged Helper"
echo ""

# Check if helper binary exists in home directory
HELPER_BINARY=~/org.openzfs.automount.helper
if [ ! -f "$HELPER_BINARY" ]; then
    echo "❌ Helper binary not found at: $HELPER_BINARY"
    echo ""
    echo "Please copy the helper binary first:"
    echo "  scp ./build/Build/Products/Release/org.openzfs.automount.helper YOUR_MAC_MINI_IP:~/"
    exit 1
fi

echo "✅ Helper binary found"
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
echo "📋 Installing helper binary..."
sudo mkdir -p /Library/PrivilegedHelperTools
sudo cp "$HELPER_BINARY" /Library/PrivilegedHelperTools/
sudo chmod 755 /Library/PrivilegedHelperTools/org.openzfs.automount.helper
sudo chown root:wheel /Library/PrivilegedHelperTools/org.openzfs.automount.helper

# Set correct permissions
sudo chown root:wheel /Library/LaunchDaemons/org.openzfs.automount.helper.plist
sudo chmod 644 /Library/LaunchDaemons/org.openzfs.automount.helper.plist

# Unload if already loaded
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.automount.helper.plist 2>/dev/null || true

# Load the LaunchDaemon
echo "🚀 Loading helper daemon..."
sudo launchctl load /Library/LaunchDaemons/org.openzfs.automount.helper.plist

# Clean up
rm -f "$HELPER_BINARY"

echo ""
echo "✅ Helper installed successfully!"
echo ""
echo "Helper location: /Library/PrivilegedHelperTools/org.openzfs.automount.helper"
echo "LaunchDaemon: /Library/LaunchDaemons/org.openzfs.automount.helper.plist"
echo ""
echo "To check status:"
echo "  sudo launchctl list | grep openzfs"
echo ""
echo "To view logs:"
echo "  sudo tail -f /var/log/zfs-automount-helper.log"
echo "  sudo tail -f /var/log/zfs-automount-helper-error.log"
echo ""
echo "Now you can use the app to mount ZFS datasets!"
