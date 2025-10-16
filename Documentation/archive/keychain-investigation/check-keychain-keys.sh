#!/bin/bash
#
# Check what's actually stored in keychains
#

SERVICE="org.openzfs.automount"
DATASETS=("tank/enc1" "media/enc2")

echo "======================================================="
echo "  Keychain Key Inspection"
echo "======================================================="
echo

for DATASET in "${DATASETS[@]}"; do
    echo "Dataset: $DATASET"
    echo "----------------------------------------"

    # User keychain
    echo "User keychain:"
    if security find-generic-password -s "$SERVICE" -a "$DATASET" &>/dev/null; then
        LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | wc -c | tr -d ' ')
        FIRST_CHARS=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | head -c 32)
        echo "  ✅ Found: $LEN chars"
        echo "  First 32 chars: $FIRST_CHARS"

        # Check if it's valid hex
        FULL_KEY=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null)
        if echo "$FULL_KEY" | grep -qE '^[0-9a-fA-F]+$'; then
            echo "  ✅ Valid hex format"
        else
            echo "  ❌ NOT valid hex - contains non-hex characters"
        fi

        # Check length
        KEY_LEN=${#FULL_KEY}
        if [ $((KEY_LEN % 2)) -eq 0 ]; then
            echo "  ✅ Even length (can be converted to bytes)"
            BYTE_COUNT=$((KEY_LEN / 2))
            echo "  → $KEY_LEN hex chars = $BYTE_COUNT bytes"
        else
            echo "  ❌ ODD length (cannot be converted to bytes!)"
        fi
    else
        echo "  ❌ NOT FOUND"
    fi

    echo

    # System keychain (requires sudo)
    echo "System keychain:"
    echo "  (Requires manual check with: sudo security find-generic-password -s $SERVICE -a $DATASET -w /Library/Keychains/System.keychain)"

    echo
done

echo "======================================================="
echo "  Testing Key Retrieval"
echo "======================================================="
echo

# Test if the app can read the keys
echo "Testing if ZFSAutoMount app can read keys..."
echo "(This simulates what happens when you open the menu bar app)"
echo

for DATASET in "${DATASETS[@]}"; do
    echo -n "$DATASET: "
    if security find-generic-password -s "$SERVICE" -a "$DATASET" -w &>/dev/null; then
        echo "✅ Accessible"
    else
        echo "❌ Not accessible (will prompt for permission)"
    fi
done

echo
echo "======================================================="
