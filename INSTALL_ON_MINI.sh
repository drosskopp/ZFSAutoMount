#!/bin/bash
# Run this script ON the Mac mini after copying the app

echo "🚀 Installing ZFSAutoMount on Mac Mini..."
echo ""

# Check if app exists in home directory
if [ ! -d ~/ZFSAutoMount.app ]; then
    echo "❌ ZFSAutoMount.app not found in home directory"
    echo "Please copy the app first:"
    echo "  scp -r ZFSAutoMount.app YOUR_MAC_MINI_IP:~/"
    exit 1
fi

echo "📍 Found app in home directory"
echo ""

# Copy to Applications
echo "📦 Installing to /Applications (requires sudo)..."
sudo cp -R ~/ZFSAutoMount.app /Applications/
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app

echo ""
echo "✅ Installation complete!"
echo ""

# Test ZFS paths
echo "🔍 Checking ZFS installation..."
if [ -f /usr/local/zfs/bin/zfs ] && [ -f /usr/local/zfs/bin/zpool ]; then
    echo "✅ OpenZFS found at /usr/local/zfs/bin/"
    ls -lh /usr/local/zfs/bin/zfs
    ls -lh /usr/local/zfs/bin/zpool
else
    echo "⚠️  OpenZFS not found at /usr/local/zfs/bin/"
    echo "Checking alternative locations..."
    which zfs
    which zpool
fi

echo ""
echo "📱 App installed at: /Applications/ZFSAutoMount.app"
echo ""
echo "To launch:"
echo "  open /Applications/ZFSAutoMount.app"
echo ""
echo "Or to test from command line:"
echo "  /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount"
