#!/bin/bash
#
# Diagnose Keychain Issues
#

SERVICE="org.openzfs.automount"
DATASETS=("tank/enc1" "media/enc2")

echo "======================================================="
echo "  Keychain Diagnostic"
echo "======================================================="
echo

# Check user keychain
echo "📋 User Keychain:"
echo

for DATASET in "${DATASETS[@]}"; do
    echo "Dataset: $DATASET"

    if security find-generic-password -s "$SERVICE" -a "$DATASET" &>/dev/null; then
        KEY=$(security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null)
        LEN=${#KEY}

        echo "  ✅ Found: $LEN characters"
        echo "  First 32 chars: ${KEY:0:32}"

        # Validate hex
        if [[ "$KEY" =~ ^[0-9a-fA-F]+$ ]]; then
            echo "  ✅ Valid hex format"

            if [ $((LEN % 2)) -eq 0 ]; then
                BYTES=$((LEN / 2))
                echo "  ✅ Even length: $BYTES bytes"

                # Expected for AES-256: 32 bytes = 64 hex chars
                if [ "$BYTES" -eq 32 ]; then
                    echo "  ✅ Correct length for AES-256 (32 bytes)"
                else
                    echo "  ⚠️  Unexpected length for AES-256 (expected 32 bytes, got $BYTES)"
                fi
            else
                echo "  ❌ ODD length - cannot convert to bytes!"
            fi
        else
            echo "  ❌ INVALID hex - contains non-hex characters"

            # Show what non-hex chars are present
            NON_HEX=$(echo "$KEY" | grep -o '[^0-9a-fA-F]' | sort -u | tr -d '\n')
            echo "     Non-hex characters found: '$NON_HEX'"
        fi
    else
        echo "  ❌ NOT FOUND"
    fi

    echo
done

echo "======================================================="
echo "  System Keychain (requires sudo)"
echo "======================================================="
echo

echo "Run this to check system keychain:"
echo

for DATASET in "${DATASETS[@]}"; do
    echo "sudo security find-generic-password -s \"$SERVICE\" -a \"$DATASET\" -w \"/Library/Keychains/System.keychain\" 2>&1 | head -c 64"
    echo
done

echo "======================================================="
echo "  Helper Daemon Status"
echo "======================================================="
echo

if sudo launchctl print system/org.openzfs.automount.helper &>/dev/null; then
    echo "✅ Helper daemon is running"

    echo
    echo "Recent helper logs:"
    sudo log show --predicate 'eventMessage contains "ZFSAutoMount Helper"' --last 2m --info 2>/dev/null | tail -20
else
    echo "❌ Helper daemon is NOT running"
fi

echo
echo "======================================================="
