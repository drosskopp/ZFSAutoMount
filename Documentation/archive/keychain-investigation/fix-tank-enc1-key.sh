#!/bin/bash
#
# Fix tank/enc1 keychain entry - Simple version
# Run this WITHOUT sudo (as your normal user)
#

set -e

KEYFILE="/Volumes/Keys/media.key"
SERVICE="org.openzfs.automount"
DATASET="tank/enc1"

echo "======================================================="
echo "  Fix tank/enc1 Keychain Entry (User Mode)"
echo "======================================================="
echo

if [ "$EUID" -eq 0 ]; then
    echo "❌ Do NOT run with sudo!"
    echo "   Run as your normal user:"
    echo "   ./fix-tank-enc1-key.sh"
    exit 1
fi

echo "👤 User: $(whoami)"
echo

# Read keyfile (requires sudo for read access)
if [ ! -f "$KEYFILE" ]; then
    echo "❌ Keyfile not found: $KEYFILE"
    exit 1
fi

echo "📖 Reading keyfile: $KEYFILE"
KEYHEX=$(sudo xxd -p -c 256 "$KEYFILE" | tr -d '\n')
KEYSIZE=$(echo -n "$KEYHEX" | wc -c | tr -d ' ')
KEYSIZE=$((KEYSIZE / 2))  # Convert hex chars to bytes

echo "   Key: $KEYSIZE bytes → ${#KEYHEX} hex chars"
echo "   First 32 hex chars: ${KEYHEX:0:32}"
echo

# Specify user's login keychain explicitly
USER_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Delete old entry from user keychain (not system keychain!)
echo "🗑️  Deleting old entry from your login keychain..."
security delete-generic-password -s "$SERVICE" -a "$DATASET" "$USER_KEYCHAIN" >/dev/null 2>&1 || true

# Add new entry to user keychain - use temp file to avoid stdin issues
echo "📥 Adding new entry to your login keychain..."
TMPFILE="/tmp/zfs_key_$$.tmp"
printf "%s" "$KEYHEX" > "$TMPFILE"
chmod 600 "$TMPFILE"

# Use cat to pipe the file content (ensures clean stdin)
cat "$TMPFILE" | security add-generic-password \
    -s "$SERVICE" \
    -a "$DATASET" \
    -w - \
    -U \
    "$USER_KEYCHAIN"

rm -f "$TMPFILE"

# Verify from user keychain specifically
echo
echo "✅ Verifying user keychain..."
STORED_LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" "$USER_KEYCHAIN" -w 2>/dev/null | wc -c | tr -d ' ')
echo "   Stored: $STORED_LEN characters"

if [ "$STORED_LEN" -eq 64 ]; then
    echo "   ✅ Correct length for AES-256 key!"
elif [ "$STORED_LEN" -eq 0 ]; then
    echo "   ⚠️  Not found in user keychain (might be in system keychain)"
else
    echo "   ❌ Wrong length! Expected 64, got $STORED_LEN"
    exit 1
fi

# Validate hex format
STORED_KEY=$(security find-generic-password -s "$SERVICE" -a "$DATASET" "$USER_KEYCHAIN" -w 2>/dev/null)
if [[ "$STORED_KEY" =~ ^[0-9a-fA-F]+$ ]] && [ ${#STORED_KEY} -eq 64 ]; then
    echo "   ✅ Valid hex format"
else
    echo "   ⚠️  Check format"
fi

echo
echo "======================================================="
echo "  ✅ User keychain updated!"
echo "======================================================="
echo
echo "Now add to SYSTEM keychain (for boot-time access):"
echo "  sudo ./add-to-system-keychain.sh"
echo
echo "Or test mounting now:"
echo "  sudo zfs unmount tank/enc1"
echo "  sudo zfs unload-key tank/enc1"
echo "  sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo
echo "======================================================="
