#!/bin/bash
#
# Copy the WORKING media/enc2 key to tank/enc1
# Since both use the same keyfile, this is valid
#

SERVICE="org.openzfs.automount"

echo "======================================================="
echo "  Copy Working Key (media/enc2 → tank/enc1)"
echo "======================================================="
echo

# Get the working key from media/enc2
echo "📖 Reading working key from media/enc2..."
WORKING_KEY=$(security find-generic-password -s "$SERVICE" -a "media/enc2" -w 2>/dev/null)

if [ -z "$WORKING_KEY" ]; then
    echo "❌ Could not read key for media/enc2"
    exit 1
fi

echo "   ✅ Found key: ${#WORKING_KEY} characters"
echo

# Delete old tank/enc1 entry
echo "🗑️  Deleting old tank/enc1 entries..."
security delete-generic-password -s "$SERVICE" -a "tank/enc1" 2>/dev/null || true
sudo security delete-generic-password -s "$SERVICE" -a "tank/enc1" "/Library/Keychains/System.keychain" 2>/dev/null || true

# Add to user keychain
echo "📥 Adding to YOUR keychain..."
printf "%s" "$WORKING_KEY" | security add-generic-password \
    -s "$SERVICE" \
    -a "tank/enc1" \
    -w -

# Verify
LEN=$(security find-generic-password -s "$SERVICE" -a "tank/enc1" -w 2>/dev/null | wc -c | tr -d ' ')
echo "   Stored: $LEN characters"

if [ "$LEN" -eq 64 ]; then
    echo "   ✅ SUCCESS!"
else
    echo "   ❌ Failed (wrong length: $LEN)"
    exit 1
fi

echo
echo "======================================================="
echo "  ✅ Key copied successfully!"
echo "======================================================="
echo
echo "Now test mounting:"
echo "  sudo zfs unmount tank/enc1"
echo "  sudo zfs unload-key tank/enc1"
echo "  sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo
echo "======================================================="
