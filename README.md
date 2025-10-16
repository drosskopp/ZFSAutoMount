# ZFSAutoMount

A native macOS menu bar application for seamless OpenZFS pool and dataset management with automated scrubbing and TRIM scheduling.

![macOS](https://img.shields.io/badge/macOS-26.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Core Functionality
- **Automatic Pool Import** - Import all ZFS pools at boot time, before user login
- **Encryption Support** - Manage encryption keys via macOS Keychain or keyfiles
- **Menu Bar Interface** - Native SwiftUI menu bar app showing pool status and capacity
- **Real-Time Monitoring** - Automatic updates when pools or datasets change
- **Dataset Management** - Mount/unmount datasets with one click

### Maintenance & Scheduling
- **Automated Scrubbing** - Schedule regular pool integrity checks (weekly/monthly/quarterly)
- **Automated TRIM** - Schedule TRIM operations for SSD-based pools (daily/weekly/monthly)
- **SSD Detection** - Automatically detect SSDs and determine TRIM eligibility
- **Manual Operations** - "Run Now" buttons for immediate scrub/TRIM execution
- **Status Display** - View scrub and TRIM status directly in the menu bar

### Security
- **Privileged Helper** - Secure root-level operations via XPC
- **Keychain Integration** - Store encryption keys securely in macOS Keychain
- **Keyfile Support** - Reference keyfiles stored in `/etc/zfs/keys/`
- **Boot-Time Access** - Support for both system and user keychains

## Screenshots

### Menu Bar
```
📦 mypool
   ✅ Health: ONLINE
   💾 Used: 500G / 2T
   🔍 Last Scrub: Oct 16, 2025 - Clean
   ✂️ TRIM: Eligible

   Datasets:
   ✅ mypool/data 🔒
      → Mounted
```

### Maintenance Tab
- Scrub scheduling with frequency selection
- TRIM scheduling for SSD pools
- Per-pool status display
- Manual "Run Now" buttons

### Encryption Tab
- View all encrypted datasets
- Manage keychain and keyfile keys
- Edit or switch between key types
- Visual badges for key sources

## Requirements

- macOS 26.0 (Tahoe) or later
- [OpenZFS](https://openzfsonosx.org) installed
- Xcode 16.0+ (for building from source)

## Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/ZFSAutoMount.git
cd ZFSAutoMount

# Build and deploy
./deploy-simple.sh
```

The script will:
1. Build the app and privileged helper
2. Deploy to `/Applications/`
3. Install the privileged helper
4. Launch the app

### Option 2: Manual Build

```bash
# Build in Xcode
xcodebuild -scheme ZFSAutoMount -configuration Debug build

# Copy to Applications
cp -R ~/Library/Developer/Xcode/DerivedData/ZFSAutoMount-*/Build/Products/Debug/ZFSAutoMount.app /Applications/

# Launch
open /Applications/ZFSAutoMount.app
```

## Quick Start

### 1. First Launch

On first launch, the app will:
- Install the privileged helper (requires admin password)
- Scan for ZFS pools
- Display pool status in menu bar

### 2. Enable Boot Automation

1. Open **Preferences** → **General**
2. Check **"Auto-import pools on boot"**
3. Check **"Auto-mount datasets on boot"**
4. Enter admin password when prompted

The boot daemon will be installed and pools will auto-mount at startup.

### 3. Configure Encryption (Optional)

If you have encrypted datasets:

1. Open **Preferences** → **Encryption**
2. Click **Edit** on a dataset
3. Choose key source:
   - **Keychain**: Enter passphrase or hex key
   - **Keyfile**: Enter path to keyfile (e.g., `/etc/zfs/keys/mypool.key`)
4. Click **Save**

### 4. Enable Maintenance (Recommended)

1. Open **Preferences** → **Maintenance**
2. Enable **automatic scrubbing** (recommended: Monthly)
3. Enable **automatic TRIM** for SSD pools (recommended: Weekly)
4. Click **Run Now** to test

## Configuration

### Boot Automation

Located at: `/Library/LaunchDaemons/org.openzfs.automount.daemon.plist`

Controlled via Preferences → General toggles.

### Encryption Keys

**Keychain Storage:**
- Service: `org.openzfs.automount`
- Account: `poolname/dataset`

**Keyfile Storage:**
- Config: `/etc/zfs/automount.conf`
- Keys: `/etc/zfs/keys/`

Example config:
```
# Format: dataset option=value
mypool/encrypted keylocation=file:///etc/zfs/keys/mypool.key
```

### Scrub & TRIM Schedules

Located at:
- `/Library/LaunchDaemons/org.openzfs.automount.scrub.plist`
- `/Library/LaunchDaemons/org.openzfs.automount.trim.plist`

Managed via Preferences → Maintenance tab.

## Usage

### Menu Bar Actions

- **Mount All Datasets** - Mount all unmounted datasets
- **Preferences** - Open preferences window
- Click on pool name to see detailed status

### Keyboard Shortcuts

- `⌘,` - Open Preferences
- `⌘M` - Mount All Datasets
- `⌘Q` - Quit ZFSAutoMount

### Manual Operations

```bash
# Check helper status
./Scripts/check-helper-status.sh

# View comprehensive status
./Scripts/check-all-status.sh

# View logs
sudo tail -f /var/log/org.openzfs.automount.helper.log
tail -f /var/log/zfs-scrub.log
tail -f /var/log/zfs-trim.log
```

## Architecture

### Two-Process Design

1. **Main App** (user-level)
   - Menu bar interface
   - Configuration management
   - Keychain access
   - User interactions

2. **Privileged Helper** (root-level)
   - Executes `zpool` and `zfs` commands
   - Communicates via XPC
   - Installed manually (no code signing required for development)

3. **LaunchDaemons**
   - Boot automation daemon
   - Scrub scheduler
   - TRIM scheduler

### Key Components

- **ZFSManager** - Core ZFS operations coordinator
- **DiskTypeDetector** - SSD detection and TRIM eligibility
- **KeychainHelper** - Secure key storage
- **ConfigParser** - Configuration file management
- **MenuBarController** - User interface
- **PrivilegedHelper** - Root-level command execution

## Development

### Building

```bash
# Build both app and helper
xcodebuild -scheme ZFSAutoMount -configuration Debug build
xcodebuild -scheme PrivilegedHelper -configuration Debug build

# Or use the deployment script
./deploy-simple.sh
```

### Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount/           # Main application
│   ├── ZFSAutoMountApp.swift
│   ├── MenuBarController.swift
│   ├── ZFSManager.swift
│   ├── DiskTypeDetector.swift
│   ├── KeychainHelper.swift
│   └── PreferencesView.swift
├── PrivilegedHelper/       # Root-level helper
│   ├── HelperMain.swift
│   └── HelperProtocol.swift
├── Documentation/          # Comprehensive docs
├── Examples/               # Configuration examples
└── Scripts/                # Utility scripts
```

### Adding Features

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

### Deployment Workflow

```bash
# Make code changes
# Then deploy everything:
./deploy-simple.sh

# This rebuilds app, helper, and installs everything
```

## Troubleshooting

### Helper Installation Issues

If you get errors about the privileged helper:

```bash
# Check helper status
./Scripts/check-helper-status.sh

# Reinstall manually
./Scripts/manual-install-helper.sh
```

### Scrub/TRIM Not Working

```bash
# Check comprehensive status
./Scripts/check-all-status.sh

# View helper logs
sudo tail -f /var/log/org.openzfs.automount.helper.log
```

### Boot Automation Not Working

```bash
# Check if daemon is loaded
sudo launchctl list | grep automount.daemon

# View boot logs
sudo log show --predicate 'process == "ZFSAutoMount"' --last 1h
```

See [Documentation/TROUBLESHOOTING_SCRUB_TRIM.md](Documentation/TROUBLESHOOTING_SCRUB_TRIM.md) for detailed troubleshooting.

## Documentation

- **[Quick Start](Documentation/QUICKSTART.md)** - Get started quickly
- **[Build Guide](Documentation/BUILD.md)** - Detailed build instructions
- **[Usage Guide](Documentation/USAGE.md)** - Complete usage documentation
- **[Project Summary](Documentation/PROJECT_SUMMARY.md)** - Technical overview
- **[Deployment Workflow](Documentation/DEPLOYMENT_WORKFLOW.md)** - Development workflow
- **[CLAUDE.md](CLAUDE.md)** - AI assistant context

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [OpenZFS on macOS](https://openzfsonosx.org)
- Developed with assistance from [Claude Code](https://claude.com/claude-code)
- Inspired by the need for native macOS ZFS integration

## Support

- **Issues**: Report bugs via [GitHub Issues](https://github.com/yourusername/ZFSAutoMount/issues)
- **Documentation**: See the [Documentation](Documentation/) directory
- **Community**: [OpenZFS macOS discussions](https://openzfsonosx.org)

## Roadmap

### Current Features (v1.0)
- ✅ Pool auto-import at boot
- ✅ Encryption key management
- ✅ Menu bar interface
- ✅ Automated scrub/TRIM scheduling
- ✅ Real-time monitoring

### Future Enhancements
- [ ] Health monitoring with notifications
- [ ] Historical scrub/TRIM statistics
- [ ] Pool health dashboard
- [ ] iOS companion app
- [ ] iCloud configuration sync

## FAQ

**Q: Does this work without code signing?**
A: Yes! The deployment script installs the privileged helper manually, bypassing SMJobBless.

**Q: Which versions of macOS are supported?**
A: macOS 26.0 (Tahoe) and later. Earlier versions may work but are untested.

**Q: Can I use this in production?**
A: Yes, but test thoroughly first. The app has been designed for reliability and daily use.

**Q: Does it support pool creation?**
A: No, pool creation is intentionally excluded. Use `zpool create` commands for that.

**Q: How does TRIM detection work?**
A: The app uses `diskutil` to detect SSDs and their protocols (NVMe, SATA, USB, Thunderbolt), then determines TRIM eligibility automatically.

---

**Made with ❤️ for the macOS + ZFS community**
