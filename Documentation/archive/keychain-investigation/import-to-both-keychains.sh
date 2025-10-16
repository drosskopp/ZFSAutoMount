#!/bin/bash
#
# Import Encryption Keys to BOTH System and User Keychains
#
# This enables:
# - Boot-time mounting (uses system keychain)
# - User-friendly access after login (uses user keychain)
#

set -e

KEYFILE="/Volumes/Keys/media.key"
DATASETS=("tank/enc1" "media/enc2")
SERVICE="org.openzfs.automount"
SYSTEM_KEYCHAIN="/Library/Keychains/System.keychain"

echo "======================================================="
echo "  Dual Keychain Import - System + User"
echo "======================================================="
echo

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run with sudo"
    echo "   Usage: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
echo "👤 User: $REAL_USER"
echo

# Read keyfile
if [ ! -f "$KEYFILE" ]; then
    echo "❌ Keyfile not found: $KEYFILE"
    exit 1
fi

echo "📖 Reading keyfile: $KEYFILE"
KEYHEX=$(xxd -p -c 256 "$KEYFILE" | tr -d '\n')
KEYSIZE=$(wc -c < "$KEYFILE" | tr -d ' ')
echo "   ✅ $KEYSIZE bytes → ${#KEYHEX} hex chars"
echo

# ============================================================================
# Import to SYSTEM KEYCHAIN (for boot-time access)
# ============================================================================

echo "📋 Step 1: Import to System Keychain"
echo "   Location: $SYSTEM_KEYCHAIN"
echo "   Purpose: Boot-time mounting (before user login)"
echo

for DATASET in "${DATASETS[@]}"; do
    echo "🔑 $DATASET → System Keychain"

    # Delete existing entry (if any)
    security delete-generic-password -s "$SERVICE" -a "$DATASET" "$SYSTEM_KEYCHAIN" 2>/dev/null || true

    # Add to system keychain - use printf to avoid newline
    printf "%s" "$KEYHEX" | security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w - \
        -T "/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount" \
        -T "/Library/PrivilegedHelperTools/org.openzfs.automount.helper" \
        -T "/usr/bin/security" \
        "$SYSTEM_KEYCHAIN"

    if [ $? -eq 0 ]; then
        echo "   ✅ Stored in system keychain"
    else
        echo "   ❌ Failed to store in system keychain"
        exit 1
    fi
done

echo

# ============================================================================
# Import to USER KEYCHAIN (for logged-in access)
# ============================================================================

echo "📋 Step 2: Import to User Keychain"
echo "   Purpose: Friendly access after login (no permission dialogs)"
echo

for DATASET in "${DATASETS[@]}"; do
    echo "🔑 $DATASET → User Keychain"

    # Delete existing entry (if any)
    sudo -u "$REAL_USER" security delete-generic-password -s "$SERVICE" -a "$DATASET" 2>/dev/null || true

    # Add to user keychain - use printf to avoid newline
    printf "%s" "$KEYHEX" | sudo -u "$REAL_USER" security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w - \
        -U

    if [ $? -eq 0 ]; then
        echo "   ✅ Stored in user keychain"
    else
        echo "   ❌ Failed to store in user keychain"
        exit 1
    fi
done

echo

# ============================================================================
# Verification
# ============================================================================

echo "📋 Step 3: Verification"
echo "======================================================="
echo

echo "System Keychain ($SYSTEM_KEYCHAIN):"
for DATASET in "${DATASETS[@]}"; do
    if security find-generic-password -s "$SERVICE" -a "$DATASET" "$SYSTEM_KEYCHAIN" &>/dev/null; then
        LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w "$SYSTEM_KEYCHAIN" 2>/dev/null | wc -c | tr -d ' ')
        echo "  ✅ $DATASET ($LEN chars)"
    else
        echo "  ❌ $DATASET - NOT FOUND"
    fi
done

echo
echo "User Keychain:"
for DATASET in "${DATASETS[@]}"; do
    if sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" &>/dev/null; then
        LEN=$(sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | wc -c | tr -d ' ')
        echo "  ✅ $DATASET ($LEN chars)"
    else
        echo "  ❌ $DATASET - NOT FOUND"
    fi
done

echo
echo "======================================================="
echo "  ✅ Dual Keychain Import Complete!"
echo "======================================================="
echo
echo "📊 Summary:"
echo "  • Keys stored in BOTH keychains"
echo "  • System keychain → Boot-time access"
echo "  • User keychain → Post-login access"
echo
echo "🎯 How it works:"
echo "  1. At boot (before login):"
echo "     LaunchDaemon runs → Reads system keychain → Mounts datasets"
echo
echo "  2. After user login:"
echo "     Menu bar app → Reads user keychain → No permission prompts"
echo
echo "🧪 Testing:"
echo "  1. Test post-login mounting:"
echo "     sudo zfs unmount tank/enc1 media/enc2"
echo "     sudo zfs unload-key tank/enc1 media/enc2"
echo "     # Then mount via menu bar app"
echo
echo "  2. Test boot-time mounting:"
echo "     # Rebuild app with updated KeychainHelper.swift"
echo "     # Redeploy to /Applications/"
echo "     # Test with --boot-mount"
echo
echo "⚠️  Next Steps:"
echo "  1. Rebuild ZFSAutoMount with updated KeychainHelper.swift"
echo "  2. Redeploy to /Applications/"
echo "  3. Test --boot-mount to verify system keychain access"
echo
echo "======================================================="
