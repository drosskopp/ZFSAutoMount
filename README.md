# ZFS AutoMount for macOS

Automatic mounting and encryption key management for OpenZFS on macOS Tahoe (26.0+).

## Features

- 🚀 **Auto-import** ZFS pools at boot
- 🔒 **Encryption support** with Keychain integration
  - Passphrase and keyfile support
  - Per-dataset encryption keys
- 📊 **Menu bar app** showing pool status
- ⚙️ **Configuration file** for custom mount options (`/etc/zfs/automount.conf`)
- 🔐 **Privileged helper** for secure root operations

## Requirements

- macOS 26.0 (Tahoe) or later
- OpenZFS installed via Homebrew
- Xcode 16.0+ (for development)

## Installation

### Via Homebrew (Recommended)

```bash
# Install OpenZFS first
brew install openzfs

# Install ZFS AutoMount
brew install --cask zfs-automount
```

### From Source

1. Clone the repository
2. Open `ZFSAutoMount.xcodeproj` in Xcode
3. Build the project (⌘+B)
4. The app will be in the build directory

## Usage

### First Launch

1. The app will check if OpenZFS is installed
2. If prompted, install the privileged helper tool (requires admin password)
3. The app icon will appear in the menu bar

### Menu Bar

- **Pool Status**: Shows health and capacity of each pool
- **Refresh Pools**: Manually refresh pool information
- **Mount All Datasets**: Mount all datasets (prompts for encryption keys if needed)
- **Preferences**: Configure auto-mount settings and manage saved keys

### Encryption Keys

When you mount an encrypted dataset for the first time:

1. You'll be prompted to enter the encryption key/passphrase
2. Option to save the key to macOS Keychain
3. Keys are automatically loaded on subsequent mounts

To manage saved keys:
- Open Preferences → Encryption tab
- View and delete saved keys

### Configuration File

Create custom mount options in `/etc/zfs/automount.conf`:

```bash
# Format: pool/dataset option=value

# Examples:
tank/enc1 keylocation=file:///path/to/keyfile
media/enc2 readonly=on
tank/backup canmount=noauto
```

## Boot-Time Mounting

The LaunchDaemon handles automatic mounting at boot:

1. Import all pools (`zpool import -a`)
2. Load encryption keys from Keychain
3. Mount all datasets (`zfs mount -a`)

Check logs:
```bash
tail -f /var/log/zfs-automount.log
```

## Tested Pools

This app has been tested with the following pool configuration:

```
media         3.43T  3.71T     2M  /Volumes/media
media/enc2    3.43T  3.71T  3.43T  /Volumes/media/enc2   [encrypted]
tank          8.21T  2.23T  2.16M  /Volumes/tank
tank/airback  2.21T  2.55T  1.90T  -
tank/enc1     6.00T  2.23T  6.00T  /Volumes/tank/enc1    [encrypted]
```

## Architecture

```
ZFSAutoMount.app
├── Main App (SwiftUI)
│   ├── Menu Bar Interface
│   ├── Preferences Window
│   └── ZFS Manager
│
├── Privileged Helper (XPC)
│   ├── zpool import/export
│   ├── zfs mount/unmount
│   └── zfs load-key
│
└── LaunchDaemon
    └── Boot-time mounting
```

## Development

### Building

```bash
cd ZFSAutoMount
xcodebuild -scheme ZFSAutoMount -configuration Debug
```

### Code Signing

For local development, ad-hoc signing is fine:
```bash
CODE_SIGN_IDENTITY="-" xcodebuild ...
```

For distribution, you'll need:
- Apple Developer Account
- Developer ID Application certificate
- Notarization for macOS 10.15+

### Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount/              # Main app
│   ├── ZFSAutoMountApp.swift
│   ├── MenuBarController.swift
│   ├── ZFSManager.swift       # ZFS operations
│   ├── KeychainHelper.swift   # Keychain integration
│   └── PreferencesView.swift  # Settings UI
│
├── PrivilegedHelper/          # Privileged operations
│   ├── HelperMain.swift
│   ├── HelperProtocol.swift
│   └── Info.plist
│
└── Formula/                   # Homebrew cask
    └── zfs-automount.rb
```

## Troubleshooting

### Pools not importing at boot

1. Check if OpenZFS kernel extension is loaded:
   ```bash
   kextstat | grep zfs
   ```

2. Check LaunchDaemon logs:
   ```bash
   cat /var/log/zfs-automount-error.log
   ```

3. Manually import pools:
   ```bash
   sudo zpool import -a
   ```

### Encryption keys not working

1. Check Keychain for saved keys:
   ```bash
   security find-generic-password -s org.openzfs.automount
   ```

2. Manually load key:
   ```bash
   sudo zfs load-key pool/dataset
   ```

### Privileged helper issues

1. Reinstall helper via Preferences → General → Install/Update Helper

2. Check helper status:
   ```bash
   sudo launchctl list | grep openzfs
   ```

## Roadmap

Future enhancements (separate project):
- [ ] Scrub scheduling
- [ ] TRIM scheduling
- [ ] Health monitoring & notifications
- [ ] Desktop widgets
- [ ] iOS companion app
- [ ] Statistics dashboard
- [ ] iCloud sync

## Contributing

Contributions welcome! Please open an issue or pull request.

## License

MIT License - see LICENSE file for details

## Credits

- Built for macOS Tahoe (26.0)
- Uses [OpenZFS on macOS](https://openzfsonosx.org)
- Inspired by the need for better ZFS integration on macOS
