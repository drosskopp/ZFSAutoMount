# ZFS AutoMount for macOS

Automatic mounting and encryption key management for OpenZFS on macOS Tahoe (26.0+).

## Features

- 🚀 **Auto-import** ZFS pools at boot (before user login)
- 🔒 **Encryption support** via secure keyfiles
  - Passphrase and raw keyfile support
  - Per-dataset encryption keys
  - Boot-time key access via `/etc/zfs/keys/`
- 📊 **Menu bar app** showing pool status and capacity
- ⚙️ **Configuration file** for custom mount options (`/etc/zfs/automount.conf`)
- 🔐 **Privileged helper** for secure root operations via XPC
- 🎯 **Native macOS integration** with SwiftUI and AppKit

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

### Encryption Setup

For encrypted datasets, store keyfiles securely:

```bash
# 1. Create secure key directory
sudo mkdir -p /etc/zfs/keys
sudo chmod 700 /etc/zfs/keys

# 2. Copy your keyfile
sudo cp /path/to/your/keyfile /etc/zfs/keys/encryption.key
sudo chmod 400 /etc/zfs/keys/encryption.key
sudo chown root:wheel /etc/zfs/keys/encryption.key
```

### Configuration File

Create `/etc/zfs/automount.conf` with dataset options:

```bash
# Format: dataset_name [options]

# Encrypted datasets (point to keyfile)
pool/encrypted1 keylocation=file:///etc/zfs/keys/encryption.key
pool/encrypted2 keylocation=file:///etc/zfs/keys/encryption.key

# Different keys for different datasets
backup/sensitive keylocation=file:///etc/zfs/keys/backup.key

# Non-encrypted datasets (auto-mount)
pool
backup
```

See `Examples/automount.conf.example` for more details.

## Boot-Time Mounting

The LaunchDaemon handles automatic mounting at boot:

1. Wait for disk subsystem to be ready (InvariantDisks daemon)
2. Import all pools (`zpool import -a`)
3. Load encryption keys from configured keyfiles
4. Mount all datasets (`zfs mount -a`)
5. Verify mounts and report status

Check logs:
```bash
tail -f /var/log/zfs-automount.log
sudo log show --predicate 'eventMessage contains "ZFSAutoMount"' --last 10m
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
