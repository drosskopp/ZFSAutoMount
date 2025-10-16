#!/bin/bash
# Deploy script for ZFS AutoMount

set -e

echo "🔨 Building ZFSAutoMount..."
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  build

echo "📦 Built successfully!"
echo ""
echo "📍 App location: ./build/Build/Products/Release/ZFSAutoMount.app"
echo ""

# Check if we should install
read -p "📲 Install to /Applications? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "🚀 Installing to /Applications..."
    sudo cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/
    sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app
    echo "✅ Installed successfully!"
    echo ""
    echo "To run: open /Applications/ZFSAutoMount.app"
else
    echo "ℹ️  To install manually, run:"
    echo "  sudo cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/"
    echo "  sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app"
fi
