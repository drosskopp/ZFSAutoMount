# Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount/               # Main application source
│   ├── ZFSAutoMountApp.swift   # App entry point
│   ├── MenuBarController.swift  # Menu bar UI
│   ├── ZFSManager.swift        # Core ZFS operations
│   ├── KeychainHelper.swift    # Keychain integration (optional)
│   ├── ConfigParser.swift      # Config file parser
│   └── PrivilegedHelperManager.swift  # XPC client
│
├── PrivilegedHelper/           # Root-level helper daemon
│   ├── HelperMain.swift        # XPC server
│   └── HelperProtocol.swift    # XPC interface
│
├── Scripts/                    # Deployment and utility scripts
│   ├── deploy-all.sh           # Deploy app + helper
│   ├── install-helper.sh       # Install privileged helper
│   ├── setup-encryption-keys-example.sh  # Setup guide
│   └── test-mount-example.sh   # Testing guide
│
├── Examples/                   # Configuration examples
│   ├── automount.conf.example  # Config file template
│   └── org.openzfs.automount.daemon.plist.example
│
├── Documentation/              # Project documentation
│   ├── README.md               # User guide
│   ├── BUILD.md                # Build instructions
│   ├── USAGE.md                # Usage guide
│   ├── PROJECT_SUMMARY.md      # Technical overview
│   ├── KEYCHAIN_INVESTIGATION.md  # Keychain research
│   └── archive/                # Archived investigation scripts
│
├── CLAUDE.md                   # Claude Code context
├── .gitignore                  # Git ignore rules
└── ZFSAutoMount.xcodeproj/     # Xcode project
```

## Key Files

### Application Code
- **ZFSManager.swift**: Core logic for pool management, encryption, mounting
- **ConfigParser.swift**: Reads `/etc/zfs/automount.conf`
- **MenuBarController.swift**: User interface

### Configuration
- **automount.conf**: `/etc/zfs/automount.conf` - Dataset configuration
- **Encryption keys**: `/etc/zfs/keys/*.key` - Keyfiles (root-only access)

### Scripts
- **deploy-all.sh**: One-command deployment
- **setup-encryption-keys-example.sh**: Initial setup for encrypted datasets

## Build Products
- **ZFSAutoMount.app**: Main menu bar application
- **org.openzfs.automount.helper**: Privileged helper daemon

## Installation Locations
- Application: `/Applications/ZFSAutoMount.app`
- Helper: `/Library/PrivilegedHelperTools/org.openzfs.automount.helper`
- LaunchDaemon plist: `/Library/LaunchDaemons/org.openzfs.automount.daemon.plist`
- Config: `/etc/zfs/automount.conf`
- Keys: `/etc/zfs/keys/` (chmod 400, root:wheel)
