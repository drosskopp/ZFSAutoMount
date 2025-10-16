# Installing to Mac Mini

## Quick Install (From Dev Mac to Mini)

### Option 1: Build and Copy via SCP

```bash
# 1. Build release version on your dev Mac
cd /path/to/ZFSAutoMount
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  build

# 2. Create ZIP for transfer
cd ./build/Build/Products/Release
ditto -c -k --sequesterRsrc --keepParent ZFSAutoMount.app ZFSAutoMount.app.zip

# 3. Copy to Mac mini
scp ZFSAutoMount.app.zip YOUR_MAC_MINI_IP:~/

# 4. SSH to Mac mini and install
ssh YOUR_MAC_MINI_IP
unzip ZFSAutoMount.app.zip
sudo cp -R ZFSAutoMount.app /Applications/
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app
open /Applications/ZFSAutoMount.app
```

### Option 2: Build on Mac Mini Directly

```bash
# 1. Copy source to Mac mini
cd /path/to/parent
scp -r ZFSAutoMount YOUR_MAC_MINI_IP:~/

# 2. SSH to Mac mini
ssh YOUR_MAC_MINI_IP

# 3. Build on Mac mini
cd ~/ZFSAutoMount
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  build

# 4. Install
sudo cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/
sudo xattr -rd com.apple.quarantine /Applications/ZFSAutoMount.app
open /Applications/ZFSAutoMount.app
```

## Verify ZFS Paths on Mac Mini

Before running, verify OpenZFS paths:

```bash
ssh YOUR_MAC_MINI_IP
which zfs      # Should be: /usr/local/zfs/bin/zfs
which zpool    # Should be: /usr/local/zfs/bin/zpool
zpool status   # Should show your pools
```

## Expected Behavior

After launching the app on Mac mini:

1. **Menu bar icon appears** (disk icon)
2. **Click the icon** - You should see:
   - media pool (3.43T / 7.14T)
   - tank pool (8.21T / 10.44T)
3. **Click "Refresh Pools"** - Pool info updates
4. **Click "Preferences"** - Settings window opens
5. **Install Helper** - Click to install privileged helper

## Current Fix Applied

✅ **Fixed paths for OpenZFS on OS X:**
- Changed from `/usr/local/bin/` to `/usr/local/zfs/bin/`
- Added auto-detection for common ZFS installation paths
- App now checks multiple locations:
  1. `/usr/local/zfs/bin/` (OpenZFS on OS X default) ⭐️
  2. `/usr/local/bin/` (Homebrew)
  3. `/opt/homebrew/bin/` (Homebrew Apple Silicon)
  4. `/usr/bin/` (System)

## Troubleshooting

### App says "OpenZFS Not Found"

Check ZFS is actually installed:
```bash
ls -l /usr/local/zfs/bin/zfs
ls -l /usr/local/zfs/bin/zpool
```

If files exist but app doesn't detect them, check permissions:
```bash
ls -la /usr/local/zfs/bin/
```

### No Pools Showing

1. Check pools are imported:
   ```bash
   sudo zpool import -a
   zpool list
   ```

2. Check app can execute zpool:
   ```bash
   /usr/local/zfs/bin/zpool list
   ```

3. Check Console.app for errors:
   - Open Console.app
   - Search for "ZFSAutoMount"
   - Look for error messages

### Testing Without Installing

```bash
# Run directly from build directory
open ./build/Build/Products/Release/ZFSAutoMount.app
```

## Next Steps After Install

1. **Test pool detection** - Click menu bar icon
2. **Install helper** - Via Preferences → General
3. **Test mounting** - Click "Mount All Datasets"
4. **Set up encryption keys** - See USAGE.md
5. **Install LaunchDaemon** - For boot-time mounting

## Updating the App

To update after code changes:

```bash
# On dev Mac
cd /path/to/ZFSAutoMount

# Rebuild
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

# Reinstall on Mac mini (via scp or direct build)
```

## Current Version Info

- **ZFS Paths:** Auto-detected (prefers `/usr/local/zfs/bin/`)
- **Code Signing:** Ad-hoc (development)
- **Build Type:** Release
- **Tested On:** Mac mini @ YOUR_MAC_MINI_IP
