#!/bin/bash
#
# Check System Keychain (requires sudo)
#

SERVICE="org.openzfs.automount"
DATASETS=("tank/enc1" "media/enc2")
SYSTEM_KEYCHAIN="/Library/Keychains/System.keychain"

echo "======================================================="
echo "  System Keychain Inspection"
echo "======================================================="
echo

if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run with sudo"
    echo "   Usage: sudo $0"
    exit 1
fi

echo "Checking: $SYSTEM_KEYCHAIN"
echo

for DATASET in "${DATASETS[@]}"; do
    echo "Dataset: $DATASET"
    echo "----------------------------------------"

    if security find-generic-password -s "$SERVICE" -a "$DATASET" "$SYSTEM_KEYCHAIN" &>/dev/null; then
        echo "✅ Found in system keychain"

        # Get length
        LEN=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w "$SYSTEM_KEYCHAIN" 2>/dev/null | wc -c | tr -d ' ')
        echo "   Length: $LEN characters"

        # Show first 32 chars
        FIRST_CHARS=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w "$SYSTEM_KEYCHAIN" 2>/dev/null | head -c 32)
        echo "   First 32 chars: $FIRST_CHARS"

        # Validate
        if [ "$LEN" -eq 64 ]; then
            echo "   ✅ Correct length for AES-256"
        elif [ "$LEN" -eq 0 ]; then
            echo "   ❌ EMPTY!"
        else
            echo "   ⚠️  Unexpected length (expected 64)"
        fi

        # Check hex format
        FULL_KEY=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w "$SYSTEM_KEYCHAIN" 2>/dev/null)
        if [[ "$FULL_KEY" =~ ^[0-9a-fA-F]+$ ]] && [ ${#FULL_KEY} -eq 64 ]; then
            echo "   ✅ Valid hex format"
        else
            echo "   ❌ Invalid format or wrong length"
        fi

    else
        echo "❌ NOT FOUND in system keychain"
    fi

    echo
done

echo "======================================================="
echo "  ACL (Access Control List)"
echo "======================================================="
echo

for DATASET in "${DATASETS[@]}"; do
    if security find-generic-password -s "$SERVICE" -a "$DATASET" "$SYSTEM_KEYCHAIN" &>/dev/null; then
        echo "ACL for $DATASET:"
        security find-generic-password -s "$SERVICE" -a "$DATASET" "$SYSTEM_KEYCHAIN" 2>&1 | grep -A 5 "access control"
        echo
    fi
done

echo "======================================================="
