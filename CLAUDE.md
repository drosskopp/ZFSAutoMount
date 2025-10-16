# ZFSAutoMount - Project Context for Claude

> **Note**: This file provides context for AI assistants (like Claude Code) when working on this project.
> It contains the project's architecture, design decisions, and development guidelines.

# ZFSAutoMount - Project Context for Claude

## Project Overview

**ZFSAutoMount** is a native macOS menu bar application that provides seamless integration of OpenZFS pools with macOS 26.0 (Tahoe) and later. It automatically imports ZFS pools at boot time, manages encryption keys, and provides a user-friendly interface for ZFS dataset management.

## What This Project Does

### Core Functionality
- **Auto-import at Boot**: Automatically imports all ZFS pools before user login
- **Encryption Key Management**: Handles passphrase and keyfile-based encryption with macOS Keychain integration
- **Menu Bar Interface**: Native SwiftUI menu bar app showing pool status and capacity
- **Privileged Operations**: Uses SMJobBless and XPC for secure root-level ZFS commands
- **Configuration File**: `/etc/zfs/automount.conf` for per-dataset mount options

### Key Features Implemented
- Pool listing with health and capacity information
- Automatic and manual dataset mounting
- Encryption key storage in macOS Keychain
- Boot-time LaunchDaemon for pre-login mounting
- SwiftUI preferences window with tabs for General, Encryption, and About
- Homebrew cask formula for easy distribution

## Technology Stack

- **Language**: Swift 5.0+
- **Frameworks**: SwiftUI, AppKit, Foundation, Security (Keychain), ServiceManagement (SMJobBless), XPC
- **Build System**: Xcode 16.0+ with two targets (main app + privileged helper)
- **Distribution**: Homebrew cask
- **Requirements**: macOS 26.0+, OpenZFS installed via Homebrew

## Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount/                    # Main application (user-level)
│   ├── ZFSAutoMountApp.swift        # App entry point, --boot-mount handler
│   ├── MenuBarController.swift      # Menu bar UI
│   ├── ZFSManager.swift             # Core ZFS operations
│   ├── KeychainHelper.swift         # Keychain integration
│   ├── PrivilegedHelperManager.swift # XPC client
│   ├── ConfigParser.swift           # Config file parser
│   ├── PreferencesView.swift        # SwiftUI preferences
│   └── *.entitlements, Info.plist   # Configuration
│
├── PrivilegedHelper/                # Root-level operations
│   ├── HelperMain.swift             # XPC server
│   ├── HelperProtocol.swift         # XPC interface
│   └── Launchd.plist                # Helper daemon config
│
├── org.openzfs.automount.daemon.plist # Boot-time daemon
├── Formula/zfs-automount.rb         # Homebrew formula
│
└── Documentation/                   # Comprehensive docs
    ├── README.md                    # User documentation
    ├── PROJECT_SUMMARY.md           # Technical overview
    ├── BUILD.md, USAGE.md, etc.    # Various guides
```

## Current State

### Status: Feature Complete (Phase 1)

**What's Working:**
- ✅ Full Xcode project with proper architecture
- ✅ Menu bar UI with pool status display
- ✅ Privileged helper with XPC communication
- ✅ Keychain integration for key storage
- ✅ Configuration file parser
- ✅ Boot-time mounting via LaunchDaemon
- ✅ Homebrew distribution setup

**Needs Testing:**
- ⚠️ SMJobBless privileged helper installation
- ⚠️ XPC communication end-to-end
- ⚠️ Encryption key loading from keyfiles
- ⚠️ Boot-time mounting sequence
- ⚠️ Full integration with actual ZFS pools

**Test Environment:**
Example test environment:
- `backup` pool with `backup/encrypted` dataset
- `pool` pool with `pool/encrypted` dataset

## Where This Project Is Going

### Immediate Next Steps
1. Build and test the application in Xcode
2. Install and verify privileged helper
3. Test encryption key flows with actual datasets
4. Validate boot-time auto-mounting
5. Deploy to Mac mini for daily use

### Phase 1 Goals (Current Focus)
- Ensure reliable auto-mounting at boot
- Perfect encryption key management
- Stable daily usage on Mac mini
- Basic pool health monitoring

### Phase 2 (Future Enhancements)
Intentionally deferred features:
- Pool scrub scheduling and automation
- TRIM scheduling for SSDs
- Health monitoring with notifications
- Advanced statistics dashboard
- Desktop widgets
- iOS companion app
- iCloud sync for configuration

### Distribution Path
1. Local testing and refinement
2. GitHub repository (public or private)
3. Homebrew tap for wider distribution
4. Optional: Mac App Store (requires Developer Account)
5. Code signing and notarization

## Architecture Overview

The app uses a two-process architecture:

1. **Main App (user-level)**:
   - Menu bar interface
   - Configuration management
   - Keychain access
   - User interactions

2. **Privileged Helper (root-level)**:
   - Executes `zpool` and `zfs` commands
   - Communicates via XPC
   - Installed via SMJobBless

3. **LaunchDaemon**:
   - Runs at boot before user login
   - Calls app with `--boot-mount` flag
   - Ensures datasets ready for user

## Development Context

### Why This Project Exists
macOS lacks native support for ZFS pool auto-mounting at boot, especially for encrypted datasets. This app fills that gap by providing a native, secure, user-friendly solution that integrates with macOS Keychain and follows Apple's security best practices.

### Design Decisions
- **Menu bar only**: No dock icon, lightweight presence
- **Keychain integration**: Secure key storage using macOS native security
- **SMJobBless**: Apple's recommended approach for privileged operations
- **Configuration file**: Simple text-based config for power users
- **Phase 1 focus**: Core functionality first, monitoring/scheduling later

### Known Limitations
- Requires OpenZFS pre-installed (via Homebrew)
- macOS 26.0+ only (Tahoe)
- No GUI for editing configuration file
- Minimal error reporting UI (by design)
- No real-time pool health monitoring (Phase 1)

## Key Files to Know

| File | Purpose | Lines |
|------|---------|-------|
| `ZFSAutoMountApp.swift` | Main entry point, boot mount logic | ~95 |
| `ZFSManager.swift` | Core ZFS operations coordinator | ~263 |
| `MenuBarController.swift` | Menu bar UI and interactions | ~170 |
| `HelperMain.swift` | Privileged helper XPC server | ~140 |
| `KeychainHelper.swift` | Keychain API wrapper | ~91 |
| `PROJECT_SUMMARY.md` | Comprehensive technical docs | ~585 |

## Working with This Project

### When Making Changes
1. **Read Documentation First**: Check `Documentation/PROJECT_SUMMARY.md` for architecture details
2. **Security First**: Any privileged operations must go through the helper
3. **Test with Real Pools**: The Mac mini test environment is critical
4. **Preserve XPC Protocol**: Changes to `HelperProtocol.swift` affect both targets

### Testing Checklist
See `Documentation/NEXT_SESSION_CHECKLIST.md` for detailed testing tasks

### Build Requirements
- Xcode 16.0+
- macOS 26.0+ SDK
- Swift 5.0+
- OpenZFS installed for testing

## Questions to Ask When Working on This Project

1. **Does this need root privileges?** → If yes, must go through privileged helper
2. **Does this involve encryption keys?** → Use Keychain, never store in plaintext
3. **Is this a boot-time operation?** → Consider LaunchDaemon timing and --boot-mount flag
4. **Does this affect security?** → Review entitlements and XPC protocol
5. **Is this Phase 1 or Phase 2?** → Focus on core mounting functionality first

## Success Criteria

The project is successful when:
- ✅ ZFS pools auto-import and mount at every boot
- ✅ Encrypted datasets unlock automatically using saved keys
- ✅ Menu bar shows current pool status
- ✅ No manual terminal commands needed for daily use
- ✅ Keys stored securely in Keychain
- ✅ Reliable operation on Mac mini test environment

## Contact & Context

This project was created with Claude Code and is designed for personal use on a Mac mini with multiple ZFS pools. The focus is on reliability and security over features, with a clean native macOS feel.

---

**Last Updated**: 2025-10-16
**Project Status**: Phase 1 Complete, Ready for Testing
**Next Milestone**: Deploy and validate on Mac mini hardware
