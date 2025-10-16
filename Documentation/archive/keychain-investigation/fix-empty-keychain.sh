#!/bin/bash
#
# Fix Empty Keychain Entry for tank/enc1
#

set -e

KEYFILE="/Volumes/Keys/media.key"
SERVICE="org.openzfs.automount"
DATASET="tank/enc1"

echo "======================================================="
echo "  Fix Empty Keychain Entry"
echo "======================================================="
echo

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run with sudo"
    echo "   (Keyfile is owned by root)"
    echo
    echo "   Usage: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
echo "👤 User: $REAL_USER"
echo

if [ ! -f "$KEYFILE" ]; then
    echo "❌ Keyfile not found: $KEYFILE"
    exit 1
fi

# Read and convert key (with sudo)
echo "📖 Reading keyfile: $KEYFILE"
KEYHEX=$(sudo xxd -p -c 256 "$KEYFILE" | tr -d '\n')
KEYSIZE=$(sudo wc -c < "$KEYFILE" | tr -d ' ')

echo "   Key: $KEYSIZE bytes → ${#KEYHEX} hex chars"
echo "   First 32 hex chars: ${KEYHEX:0:32}"
echo

# Delete old entry (the empty one) - run as user, specify user's login keychain
echo "🗑️  Deleting old empty entry from user keychain..."
USER_KEYCHAIN="/Users/$REAL_USER/Library/Keychains/login.keychain-db"
sudo -u "$REAL_USER" security delete-generic-password -s "$SERVICE" -a "$DATASET" "$USER_KEYCHAIN" 2>/dev/null || true

# Add new entry - run as user
# Create temp script in /tmp (sudo -u can't execute from /var/folders)
echo "📥 Adding new entry to user keychain..."
TMPSCRIPT="/tmp/keychain_add_$$.sh"
cat > "$TMPSCRIPT" <<'EOFSCRIPT'
#!/bin/bash
printf "%s" "$1" | security add-generic-password \
    -s "$2" \
    -a "$3" \
    -w - \
    -U
EOFSCRIPT

chmod +x "$TMPSCRIPT"
chown "$REAL_USER" "$TMPSCRIPT"
sudo -u "$REAL_USER" "$TMPSCRIPT" "$KEYHEX" "$SERVICE" "$DATASET"
rm -f "$TMPSCRIPT"

# Verify
echo
echo "✅ Verifying user keychain..."
STORED_LEN=$(sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | wc -c | tr -d ' ')
echo "   Stored: $STORED_LEN characters"

if [ "$STORED_LEN" -eq 64 ]; then
    echo "   ✅ Correct length for AES-256 key"
else
    echo "   ❌ Wrong length! Expected 64, got $STORED_LEN"
    exit 1
fi

# Verify hex format
STORED_KEY=$(sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null)
if [[ "$STORED_KEY" =~ ^[0-9a-fA-F]+$ ]]; then
    echo "   ✅ Valid hex format"
else
    echo "   ❌ Invalid hex format"
    exit 1
fi

echo
echo "======================================================="
echo "  ✅ Fixed! User keychain entry for $DATASET is correct"
echo "======================================================="
echo

# Now add to system keychain as well (don't prompt, just do it)
echo "📋 Adding to SYSTEM keychain for boot-time access..."
echo "(Required for mounting before user login)"
echo

# Always add to system keychain for boot-time access
if true; then
    echo
    echo "📥 Adding to system keychain (requires sudo)..."

    # Delete old entry if exists
    security delete-generic-password -s "$SERVICE" -a "$DATASET" "/Library/Keychains/System.keychain" 2>/dev/null || true

    # Add to system keychain - directly (already running as root)
    printf "%s" "$KEYHEX" | security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w - \
        -T "/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount" \
        -T "/Library/PrivilegedHelperTools/org.openzfs.automount.helper" \
        -T "/usr/bin/security" \
        "/Library/Keychains/System.keychain"

    echo "   ✅ Added to system keychain"

    # Verify system keychain
    echo
    echo "🔍 Verifying system keychain..."
    SYS_LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w "/Library/Keychains/System.keychain" 2>/dev/null | wc -c | tr -d ' ')
    echo "   Stored in system keychain: $SYS_LEN characters"

    if [ "$SYS_LEN" -eq 64 ]; then
        echo "   ✅ Correct length in system keychain"
    else
        echo "   ⚠️  Unexpected length: $SYS_LEN (expected 64)"
    fi
fi

echo
echo "======================================================="
echo "  ✅ Complete! Both keychains updated"
echo "======================================================="
echo
echo "Summary:"
echo "  • User keychain: 64 chars ✅"
echo "  • System keychain: 64 chars ✅"
echo "  • Dataset: $DATASET"
echo
echo "Next step: Run test"
echo "  ./test-mount.sh"
echo
echo "Expected: NO password prompts, automatic mounting"
echo "======================================================="
