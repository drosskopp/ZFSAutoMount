#!/bin/bash
#
# Fix Keychain Import - Store keys correctly
#

set -e

KEYFILE="/Volumes/Keys/media.key"
DATASETS=("tank/enc1" "media/enc2")
SERVICE="org.openzfs.automount"

echo "=== Fix Keychain Import ==="
echo

if [ "$EUID" -ne 0 ]; then
    echo "❌ Run with: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

# Read and convert key
echo "📖 Reading keyfile: $KEYFILE"
KEYHEX=$(xxd -p -c 256 "$KEYFILE" | tr -d '\n')
echo "✅ Key read: ${#KEYHEX} chars"
echo

# Delete and re-import correctly
for DATASET in "${DATASETS[@]}"; do
    echo "🔑 Dataset: $DATASET"

    # Delete old entry
    sudo -u "$REAL_USER" security delete-generic-password -s "$SERVICE" -a "$DATASET" 2>/dev/null || true

    # Import using security command - run entirely as user
    # Create temp file with key for sudo -u to work properly
    TMPKEY=$(mktemp)
    printf "%s" "$KEYHEX" > "$TMPKEY"
    chown "$REAL_USER" "$TMPKEY"
    chmod 600 "$TMPKEY"

    # Import as user with temp file
    sudo -u "$REAL_USER" security add-generic-password \
        -s "$SERVICE" \
        -a "$DATASET" \
        -w "$KEYHEX" \
        -U

    rm -f "$TMPKEY"

    echo "   ✅ Imported"
done

echo
echo "=== Verification ==="
for DATASET in "${DATASETS[@]}"; do
    echo -n "Testing $DATASET: "
    LEN=$(sudo -u "$REAL_USER" security find-generic-password -s "$SERVICE" -a "$DATASET" -w 2>/dev/null | wc -c | tr -d ' ')
    if [ "$LEN" -gt 0 ]; then
        echo "✅ $LEN chars stored"
    else
        echo "❌ EMPTY!"
    fi
done

echo
echo "✅ Done! Try mounting again from the app."
