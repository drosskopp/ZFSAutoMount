#!/bin/bash
#
# ZFSAutoMount - Import Encryption Keys to Keychain
#
# This script reads encryption keys from files and imports them into
# macOS Keychain for use by ZFSAutoMount.
#

set -e

KEYFILE="/Volumes/Keys/media.key"
DATASETS=("tank/enc1" "media/enc2")
SERVICE="org.openzfs.automount"

echo "=== ZFSAutoMount Key Import Tool ==="
echo

# Check if keyfile exists
if [ ! -f "$KEYFILE" ]; then
    echo "❌ Error: Keyfile not found at $KEYFILE"
    exit 1
fi

# Read keyfile (needs sudo since it's root-owned)
echo "📖 Reading keyfile: $KEYFILE"
KEYDATA=$(sudo cat "$KEYFILE" | base64)

if [ -z "$KEYDATA" ]; then
    echo "❌ Error: Failed to read keyfile"
    exit 1
fi

echo "✅ Keyfile read successfully ($(sudo wc -c < "$KEYFILE") bytes)"
echo

# Import key for each dataset
for DATASET in "${DATASETS[@]}"; do
    echo "🔑 Importing key for dataset: $DATASET"

    # Delete existing keychain entry (if any)
    security delete-generic-password -s "$SERVICE" -a "$DATASET" 2>/dev/null || true

    # Add new keychain entry
    # Note: We store the base64-encoded key since raw binary may have issues
    echo "$KEYDATA" | security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w - \
        -T "/Applications/ZFSAutoMount.app" \
        -T "/Library/PrivilegedHelperTools/org.openzfs.automount.helper"

    if [ $? -eq 0 ]; then
        echo "  ✅ Key imported to keychain for $DATASET"
    else
        echo "  ❌ Failed to import key for $DATASET"
        exit 1
    fi
done

echo
echo "=== Verification ==="
echo "Checking keychain entries..."
for DATASET in "${DATASETS[@]}"; do
    if security find-generic-password -s "$SERVICE" -a "$DATASET" &>/dev/null; then
        echo "  ✅ $DATASET - Key present in keychain"
    else
        echo "  ❌ $DATASET - Key NOT found in keychain"
    fi
done

echo
echo "=== Next Steps ==="
echo "1. Update ZFS keylocation property:"
echo "   sudo zfs set keylocation=prompt tank/enc1"
echo "   sudo zfs set keylocation=prompt media/enc2"
echo
echo "2. Test key loading:"
echo "   /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo
echo "3. Reboot to test boot-time mounting"
echo
echo "✅ Done!"
