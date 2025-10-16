#!/bin/bash
# Deploy ZFSAutoMount to Mac Mini

set -e

MINI_IP="${MINI_IP:-YOUR_MAC_MINI_IP}"  # Override with env var if needed

echo "🔨 Building ZFSAutoMount (Release)..."
cd "$(dirname "$0")"

xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""

echo "📦 Creating archive..."
cd ./build/Build/Products/Release
rm -f ZFSAutoMount.app.zip
ditto -c -k --sequesterRsrc --keepParent ZFSAutoMount.app ZFSAutoMount.app.zip

echo "📤 Copying to Mac Mini ($MINI_IP)..."
scp ZFSAutoMount.app.zip $MINI_IP:~/

echo "🚀 Installing on Mac Mini..."
ssh $MINI_IP << 'ENDSSH'
cd ~
unzip -o ZFSAutoMount.app.zip
sudo cp -R ZFSAutoMount.app /Applications/
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app
rm -rf ZFSAutoMount.app ZFSAutoMount.app.zip
echo "✅ Installation complete!"
echo ""
echo "Testing ZFS paths..."
ls -l /usr/local/zfs/bin/zfs
ls -l /usr/local/zfs/bin/zpool
echo ""
echo "App installed at: /Applications/ZFSAutoMount.app"
ENDSSH

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To launch on Mac Mini:"
echo "  ssh $MINI_IP 'open /Applications/ZFSAutoMount.app'"
echo ""
echo "To check if it's running:"
echo "  ssh $MINI_IP 'ps aux | grep ZFSAutoMount'"
