#!/bin/bash
# Update ZFSAutoMount on Mac Mini (run this ON the Mac mini)

echo "🔄 Updating ZFSAutoMount..."
echo ""

# Check if zip exists
if [ ! -f ~/ZFSAutoMount.app.zip ]; then
    echo "❌ ZFSAutoMount.app.zip not found in home directory"
    exit 1
fi

# Quit running app if exists
echo "📴 Stopping running app (if any)..."
killall ZFSAutoMount 2>/dev/null || true

# Unzip
echo "📦 Extracting update..."
cd ~
unzip -o ZFSAutoMount.app.zip

# Install
echo "🚀 Installing update (requires sudo)..."
sudo cp -R ~/ZFSAutoMount.app /Applications/
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app

# Cleanup
rm -rf ~/ZFSAutoMount.app ~/ZFSAutoMount.app.zip

echo ""
echo "✅ Update complete!"
echo ""
echo "To launch:"
echo "  open /Applications/ZFSAutoMount.app"
