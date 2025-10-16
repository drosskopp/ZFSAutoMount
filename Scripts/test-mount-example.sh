#!/bin/bash
#
# Quick test script for ZFS mounting
#

set -e

echo "======================================================="
echo "  Testing ZFSAutoMount - Boot Mount Sequence"
echo "======================================================="
echo

# Check current state
echo "📊 Current state:"
echo
echo "Pools:"
zpool list
echo
echo "Encrypted datasets:"
zfs list -o name,mountpoint,mounted,encryption,keystatus pool/encrypted1 pool/encrypted2
echo

# Unmount and unload keys
echo "🔄 Preparing test environment..."
echo "   Unmounting and unloading keys..."
sudo zfs unmount pool/encrypted1 2>/dev/null || true
sudo zfs unmount pool/encrypted2 2>/dev/null || true
sudo zfs unload-key pool/encrypted1 2>/dev/null || true
sudo zfs unload-key pool/encrypted2 2>/dev/null || true

echo
echo "📊 After cleanup:"
zfs list -o name,mounted,keystatus pool/encrypted1 pool/encrypted2
echo

# Run boot-mount
echo "======================================================="
echo "  Running: sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount"
echo "======================================================="
echo

sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount

RESULT=$?

echo
echo "======================================================="
echo "  Results"
echo "======================================================="
echo
echo "Exit code: $RESULT"
echo

if [ $RESULT -eq 0 ]; then
    echo "✅ Boot mount reported SUCCESS"
else
    echo "❌ Boot mount reported FAILURE (exit code: $RESULT)"
fi

echo
echo "📊 Final state:"
zfs list -o name,mounted,keystatus pool/encrypted1 pool/encrypted2
echo

# Check actual mounts
echo "🔍 Verification:"
TANK_MOUNTED=$(zfs mount | grep -c "pool/encrypted1" || true)
MEDIA_MOUNTED=$(zfs mount | grep -c "pool/encrypted2" || true)

if [ "$TANK_MOUNTED" -eq 1 ]; then
    echo "   ✅ pool/encrypted1 is mounted"
else
    echo "   ❌ pool/encrypted1 is NOT mounted"
fi

if [ "$MEDIA_MOUNTED" -eq 1 ]; then
    echo "   ✅ pool/encrypted2 is mounted"
else
    echo "   ❌ pool/encrypted2 is NOT mounted"
fi

echo
echo "======================================================="

if [ "$TANK_MOUNTED" -eq 1 ] && [ "$MEDIA_MOUNTED" -eq 1 ]; then
    echo "  ✅ ALL TESTS PASSED"
    echo "======================================================="
    exit 0
else
    echo "  ❌ SOME TESTS FAILED"
    echo "======================================================="
    exit 1
fi
