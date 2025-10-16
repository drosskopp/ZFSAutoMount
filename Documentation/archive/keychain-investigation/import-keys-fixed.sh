#!/bin/bash
#
# ZFSAutoMount - Import RAW Encryption Keys to Keychain
#
# This script reads RAW binary encryption keys and imports them into
# macOS Keychain as hex-encoded strings for use by ZFSAutoMount.
#

set -e

KEYFILE="/Volumes/Keys/media.key"
DATASETS=("tank/enc1" "media/enc2")
SERVICE="org.openzfs.automount"

echo "=== ZFSAutoMount Key Import Tool ==="
echo

# Check if running as root or can sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script needs sudo access to read the keyfile."
    echo "Please run: sudo $0"
    exit 1
fi

# Check if keyfile exists
if [ ! -f "$KEYFILE" ]; then
    echo "❌ Error: Keyfile not found at $KEYFILE"
    exit 1
fi

# Read keyfile and convert to hex
echo "📖 Reading keyfile: $KEYFILE"
KEYSIZE=$(wc -c < "$KEYFILE" | tr -d ' ')
echo "   Key size: $KEYSIZE bytes"

if [ "$KEYSIZE" -ne 32 ]; then
    echo "⚠️  Warning: Expected 32 bytes for AES-256, got $KEYSIZE bytes"
fi

# Convert raw binary to hex string
KEYHEX=$(xxd -p -c 256 "$KEYFILE" | tr -d '\n')

if [ -z "$KEYHEX" ]; then
    echo "❌ Error: Failed to read keyfile"
    exit 1
fi

echo "✅ Keyfile read successfully"
echo "   Hex representation: ${KEYHEX:0:16}...${KEYHEX: -16}"
echo

# Get the user who invoked sudo
REAL_USER="${SUDO_USER:-$USER}"
echo "🔐 Importing to keychain for user: $REAL_USER"
echo

# Import key for each dataset
for DATASET in "${DATASETS[@]}"; do
    echo "🔑 Importing key for dataset: $DATASET"

    # Delete existing keychain entry (if any) - run as the real user
    sudo -u "$REAL_USER" security delete-generic-password -s "$SERVICE" -a "$DATASET" 2>/dev/null || true

    # Add new keychain entry - run as the real user
    # We store the hex-encoded key as a string
    echo "$KEYHEX" | sudo -u "$REAL_USER" security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w - \
        -U \
        -T "/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount" \
        -T ""

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
    if sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" &>/dev/null; then
        echo "  ✅ $DATASET - Key present in keychain"
    else
        echo "  ❌ $DATASET - Key NOT found in keychain"
    fi
done

echo
echo "⚠️  IMPORTANT: Raw binary keys need special handling!"
echo
echo "The keys are now stored as HEX strings in keychain."
echo "ZFSAutoMount's privileged helper needs to convert hex→binary before loading."
echo
echo "=== Next Steps ==="
echo "1. We need to update HelperMain.swift to handle raw (hex) keys"
echo "2. Update ZFS keylocation property:"
echo "   sudo zfs set keylocation=prompt tank/enc1"
echo "   sudo zfs set keylocation=prompt media/enc2"
echo "3. Test key loading after code update"
echo
echo "✅ Keys imported to keychain!"
echo "⏸️  Code update needed before testing"
