#!/bin/bash
#
# Setup encryption keys via CONFIG FILE instead of keychain
# This avoids all the macOS keychain API issues
#

set -e

KEYFILE="/path/to/your/encryption.key"
CONFIG="/etc/zfs/automount.conf"

echo "======================================================="
echo "  Setup Config File with Key Locations"
echo "======================================================="
echo

if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run with sudo"
    echo "   Usage: sudo $0"
    exit 1
fi

# Create config directory if needed
mkdir -p /etc/zfs

# Create secure key directory
KEYDIR="/etc/zfs/keys"
mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"

# Copy the key file
echo "📋 Copying keyfile to $KEYDIR..."
cp "$KEYFILE" "$KEYDIR/backup.key"
chmod 400 "$KEYDIR/backup.key"
chown root:wheel "$KEYDIR/backup.key"

echo "   ✅ Key copied and secured"
echo

# Create config file
echo "📝 Creating $CONFIG..."
cat > "$CONFIG" <<'EOF'
# ZFS AutoMount Configuration
# Format: dataset_name key_location [mount_options]

# Encrypted datasets - using secure keyfile
pool/encrypted1 keylocation=file:///etc/zfs/keys/backup.key
pool/encrypted2 keylocation=file:///etc/zfs/keys/backup.key

# Non-encrypted datasets (auto-mount)
pool
backup
EOF

chmod 644 "$CONFIG"

echo "   ✅ Config created"
echo

# Show config
echo "📄 Config file contents:"
cat "$CONFIG"
echo

echo "======================================================="
echo "  ✅ Setup Complete!"
echo "======================================================="
echo

echo "Key location: /etc/zfs/keys/backup.key"
echo "Config file: /etc/zfs/automount.conf"
echo

echo "The app will now read keys from the config file instead of keychain."
echo "This works at boot time (before login) because the file is readable by root."
echo

echo "Test mounting:"
echo "  sudo zfs unmount pool/encrypted1 pool/encrypted2"
echo "  sudo zfs unload-key pool/encrypted1 pool/encrypted2"
echo "  sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo

echo "======================================================="
