#!/bin/bash
#
# Simple Keychain Import - Run in TWO steps
# Step 1: Run WITHOUT sudo (adds to user keychain)
# Step 2: Run WITH sudo (adds to system keychain)
#

KEYFILE="/Volumes/Keys/media.key"
DATASETS=("tank/enc1" "media/enc2")
SERVICE="org.openzfs.automount"

echo "======================================================="
echo "  Simple Keychain Import"
echo "======================================================="
echo

# Read key (always needs sudo since file is root-owned)
echo "📖 Reading keyfile..."
KEYHEX=$(sudo xxd -p -c 256 "$KEYFILE" | tr -d '\n')
echo "   ✅ Read ${#KEYHEX} hex chars"
echo

if [ "$EUID" -eq 0 ]; then
    # Running as root - add to SYSTEM keychain
    echo "🔐 Running as ROOT - Adding to SYSTEM keychain"
    echo "   Location: /Library/Keychains/System.keychain"
    echo

    for DATASET in "${DATASETS[@]}"; do
        echo "   $DATASET..."

        # Delete old
        security delete-generic-password -s "$SERVICE" -a "$DATASET" "/Library/Keychains/System.keychain" 2>/dev/null || true

        # Add new
        printf "%s" "$KEYHEX" | security add-generic-password \
            -s "$SERVICE" \
            -a "$DATASET" \
            -w - \
            -T "/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount" \
            -T "/Library/PrivilegedHelperTools/org.openzfs.automount.helper" \
            -T "/usr/bin/security" \
            "/Library/Keychains/System.keychain" 2>&1

        echo "   ✅ Added to system keychain"
    done

    echo
    echo "✅ System keychain complete!"
    echo
    echo "Now run WITHOUT sudo to add to user keychain:"
    echo "   $0"

else
    # Running as user - add to USER keychain
    echo "👤 Running as USER - Adding to YOUR keychain"
    echo

    for DATASET in "${DATASETS[@]}"; do
        echo "   $DATASET..."

        # Delete from BOTH keychains first (avoid conflicts)
        security delete-generic-password -s "$SERVICE" -a "$DATASET" 2>/dev/null || true
        sudo security delete-generic-password -s "$SERVICE" -a "$DATASET" "/Library/Keychains/System.keychain" 2>/dev/null || true

        # Add new - NO keychain path, NO -U flag (create fresh)
        printf "%s" "$KEYHEX" | security add-generic-password \
            -s "$SERVICE" \
            -a "$DATASET" \
            -w - 2>&1

        # Verify
        LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | wc -c | tr -d ' ')
        if [ "$LEN" -eq 64 ]; then
            echo "   ✅ Added to user keychain ($LEN chars)"
        else
            echo "   ⚠️  Added but length is $LEN (expected 64)"
        fi
    done

    echo
    echo "✅ User keychain complete!"
    echo
    echo "Now run WITH sudo to add to system keychain:"
    echo "   sudo $0"
fi

echo
echo "======================================================="
