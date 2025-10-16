# Building ZFS AutoMount

## Prerequisites

1. **macOS 26.0 (Tahoe)** or later
2. **Xcode 16.0+** - Install from Mac App Store
3. **Command Line Tools** - Already installed ✓
4. **OpenZFS** - Install via Homebrew:
   ```bash
   brew install openzfs
   ```

## First-Time Setup

### 1. Install Xcode

```bash
# Download Xcode from Mac App Store
# Then accept the license
sudo xcodebuild -license accept

# Verify installation
xcodebuild -version
```

### 2. Open the Project

```bash
cd /path/to/ZFSAutoMount
open ZFSAutoMount.xcodeproj
```

## Building from Xcode

### Debug Build (for development)

1. Open `ZFSAutoMount.xcodeproj` in Xcode
2. Select **ZFSAutoMount** scheme in the toolbar
3. Product → Build (⌘+B)
4. Product → Run (⌘+R) to test

The app will be built to:
```
~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app
```

### Release Build (for distribution)

1. Select **ZFSAutoMount** scheme
2. Product → Scheme → Edit Scheme (⌘+<)
3. Change "Run" build configuration to "Release"
4. Product → Build (⌘+B)

Or via command line:
```bash
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-"
```

The app will be in: `./build/Build/Products/Release/ZFSAutoMount.app`

## Building from Command Line

### Debug Build
```bash
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-"
```

### Release Build
```bash
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  CODE_SIGN_IDENTITY="-"
```

### Build Both Targets
```bash
# Build main app
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release

# Build privileged helper
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme PrivilegedHelper \
  -configuration Release
```

## Code Signing

### For Local Development (Ad-Hoc Signing)

No Apple Developer account needed. Use:
```bash
CODE_SIGN_IDENTITY="-"
```

This is already configured in the project settings.

### For Distribution (Developer ID)

You'll need:
1. Apple Developer Account ($99/year)
2. Developer ID Application certificate
3. Notarization setup

Steps:
```bash
# 1. Create signing certificate in Xcode
# Xcode → Preferences → Accounts → Manage Certificates → +

# 2. Build with Developer ID
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name"

# 3. Notarize (required for macOS 10.15+)
xcrun notarytool submit ZFSAutoMount.app.zip \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --wait

# 4. Staple the notarization
xcrun stapler staple ZFSAutoMount.app
```

## Testing Your Build

### 1. Check if OpenZFS is installed
```bash
which zpool
which zfs
zpool status
```

### 2. Run the app
```bash
# From Xcode build
open ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app

# Or from command line build
open ./build/Build/Products/Release/ZFSAutoMount.app
```

### 3. Test with your pools

The app should detect your pools:
- **media** (3.43T)
  - media/enc2 (encrypted)
- **tank** (8.21T)
  - tank/airback
  - tank/enc1 (encrypted)

### 4. Test encryption key prompt

1. Unmount an encrypted dataset:
   ```bash
   sudo zfs unmount media/enc2
   sudo zfs unload-key media/enc2
   ```

2. Use the app to mount it (should prompt for key)

3. Save key to Keychain when prompted

4. Try mounting again (should use saved key)

## Troubleshooting

### Error: "Developer cannot be verified"

macOS Gatekeeper is blocking the app. To allow:
```bash
sudo xattr -rd com.apple.quarantine /path/to/ZFSAutoMount.app
```

### Error: "SMJobBless failed"

The privileged helper couldn't install. Try:
1. Open Preferences in the app
2. Click "Install/Update Helper"
3. Enter your password when prompted

### Swift compilation errors

Make sure you're using Xcode 16.0+ for macOS 26.0 SDK:
```bash
xcodebuild -version
# Should show Xcode 16.0 or later
```

### Build succeeds but app crashes

Check the console for errors:
```bash
# In Xcode: Window → Devices and Simulators → Show Console
# Or via command line:
log stream --predicate 'process == "ZFSAutoMount"' --level debug
```

## Creating Distribution Package

### 1. Build release version
```bash
xcodebuild -project ZFSAutoMount.xcodeproj \
  -scheme ZFSAutoMount \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-"
```

### 2. Copy to Applications
```bash
cp -R ./build/Build/Products/Release/ZFSAutoMount.app /Applications/
```

### 3. Create ZIP for Homebrew
```bash
cd ./build/Build/Products/Release
ditto -c -k --sequesterRsrc --keepParent ZFSAutoMount.app ../../../../ZFSAutoMount.app.zip
cd ../../../../

# Update the SHA256 in Formula/zfs-automount.rb
shasum -a 256 ZFSAutoMount.app.zip
```

### 4. Test Homebrew installation
```bash
brew install --cask Formula/zfs-automount.rb
```

## Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount.xcodeproj/        # Xcode project
├── ZFSAutoMount/                  # Main app source
│   ├── ZFSAutoMountApp.swift      # App entry point
│   ├── MenuBarController.swift    # Menu bar UI
│   ├── ZFSManager.swift           # ZFS operations
│   ├── KeychainHelper.swift       # Keychain integration
│   ├── PrivilegedHelperManager.swift  # Helper communication
│   ├── ConfigParser.swift         # Config file parser
│   ├── PreferencesView.swift      # Settings UI
│   ├── Assets.xcassets/           # App icons
│   ├── Info.plist                 # App metadata
│   └── ZFSAutoMount.entitlements  # Security entitlements
├── PrivilegedHelper/              # Root-level operations
│   ├── HelperMain.swift           # Helper entry point
│   ├── HelperProtocol.swift       # XPC interface
│   ├── Info.plist                 # Helper metadata
│   └── Launchd.plist              # LaunchD configuration
├── Formula/                       # Homebrew
│   └── zfs-automount.rb           # Cask formula
├── org.openzfs.automount.daemon.plist  # Boot daemon
├── README.md                      # User documentation
├── BUILD.md                       # This file
└── .gitignore                     # Git ignore rules
```

## Development Workflow

### 1. Make changes to source files
```bash
# Edit in your favorite editor or Xcode
vim ZFSAutoMount/ZFSManager.swift
```

### 2. Build and test
```bash
xcodebuild -scheme ZFSAutoMount -configuration Debug
```

### 3. Run from Xcode
- Set breakpoints
- Step through code
- View console output

### 4. Test with real ZFS pools
- Use your test Mac with actual ZFS datasets
- Test encryption key handling
- Verify boot-time mounting

### 5. Commit changes
```bash
git add .
git commit -m "feat: add feature"
git push
```

## Next Steps

After successfully building:

1. **Test thoroughly** with your ZFS pools
2. **Test encryption** with your encrypted datasets (media/enc2, tank/enc1)
3. **Set up boot mounting** via LaunchDaemon
4. **Create Homebrew tap** for distribution
5. **Get Apple Developer account** when ready for wider distribution

## Getting Help

If you encounter issues:

1. Check Xcode build logs
2. Check system logs: `log show --predicate 'process == "ZFSAutoMount"'`
3. Verify OpenZFS is working: `zpool status`
4. Check helper status: `sudo launchctl list | grep openzfs`

## Clean Build

To start fresh:
```bash
# Clean Xcode build
rm -rf ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*

# Or from command line
xcodebuild clean -project ZFSAutoMount.xcodeproj -scheme ZFSAutoMount
```
