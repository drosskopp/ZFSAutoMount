# ZFSAutoMount Documentation

This directory contains technical documentation, design decisions, and project history for ZFSAutoMount.

## Core Documentation

### [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
Overview of the codebase structure, architecture, and component relationships.

### [KEYCHAIN_INVESTIGATION.md](KEYCHAIN_INVESTIGATION.md)
Detailed investigation into macOS Keychain integration attempts and why we recommend using config files instead.

**Key Takeaway**: Use `/etc/zfs/automount.conf` with keyfiles in `/etc/zfs/keys/` for reliable boot-time mounting.

### [IMPROVEMENTS_FROM_ZFS_POOL_IMPORTER.md](IMPROVEMENTS_FROM_ZFS_POOL_IMPORTER.md)
Analysis of improvements made when transitioning from an earlier prototype to the current architecture.

### [PHASE2_MAINTENANCE.md](PHASE2_MAINTENANCE.md)
Future enhancements and maintenance features planned for Phase 2, including:
- Pool scrub scheduling
- TRIM scheduling
- Health monitoring
- Desktop widgets

## For New Contributors

Start with these documents in order:

1. **[Main README.md](../README.md)** - Installation and basic usage
2. **[CONTRIBUTING.md](../CONTRIBUTING.md)** - How to contribute
3. **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Understand the codebase
4. **[KEYCHAIN_INVESTIGATION.md](KEYCHAIN_INVESTIGATION.md)** - Why certain design decisions were made

## For Users

### Quick Start
See the main [README.md](../README.md) for installation and usage instructions.

### Configuration Examples
See [Examples/](../Examples/) directory for:
- `automount.conf.example` - Configuration file format
- `org.openzfs.automount.daemon.plist.example` - LaunchDaemon setup

### Helper Scripts
See [Scripts/](../Scripts/) directory for:
- `setup-encryption-keys-example.sh` - How to set up encryption keys
- `test-mount-example.sh` - Test mounting sequence
- `deploy-all.sh` - Deploy updates during development

## Architecture Overview

ZFSAutoMount uses a three-component architecture:

```
┌─────────────────────────────────────────────────────────┐
│  ZFSAutoMount.app (User Level)                          │
│  - Menu bar interface                                   │
│  - Configuration management                             │
│  - User preferences                                     │
└─────────────────────────────────────────────────────────┘
                        │
                        │ XPC Communication
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Privileged Helper (Root Level)                         │
│  - zpool import/export                                  │
│  - zfs mount/unmount                                    │
│  - zfs load-key (encryption)                            │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Invokes at boot
                        ▼
┌─────────────────────────────────────────────────────────┐
│  LaunchDaemon (Boot Time)                               │
│  - Runs before user login                               │
│  - Imports all pools                                    │
│  - Mounts encrypted datasets                            │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### Why Config Files Instead of Keychain?
See [KEYCHAIN_INVESTIGATION.md](KEYCHAIN_INVESTIGATION.md) for the full story.

**Summary**: macOS security restrictions make reliable automated keychain access at boot time extremely difficult. Using config files (`/etc/zfs/automount.conf`) with secure keyfiles (`/etc/zfs/keys/`) is simpler and more reliable.

### Why Privileged Helper?
Root privileges are required for:
- `zpool import/export`
- `zfs mount/unmount`
- `zfs load-key`

Apple's SMJobBless framework provides a secure way to run these operations without making the entire app run as root.

### Why Menu Bar Only?
- Lightweight presence (no dock icon)
- Quick access to pool status
- Minimal resource usage
- Follows macOS design patterns for system utilities

## Development Workflow

### Building from Source
```bash
cd ZFSAutoMount
xcodebuild -scheme ZFSAutoMount -configuration Debug
```

### Installing Privileged Helper
The helper is installed via SMJobBless when you first run the app. To reinstall:

1. Open Preferences
2. Click "Install/Update Helper"
3. Enter admin password when prompted

### Testing Changes
```bash
# Deploy updated app and helper
./Scripts/deploy-all.sh

# Test boot-time mounting sequence
./Scripts/test-mount-example.sh
```

### Debugging
- App logs: `Console.app` → search for "ZFSAutoMount"
- Helper logs: `sudo log show --predicate 'eventMessage contains "ZFSAutoMount"'`
- LaunchDaemon logs: `/var/log/zfs-automount.log`

## File Locations

| Component | Location | Purpose |
|-----------|----------|---------|
| Main App | `/Applications/ZFSAutoMount.app` | Menu bar application |
| Privileged Helper | `/Library/PrivilegedHelperTools/org.openzfs.automount.helper` | Root operations |
| LaunchDaemon | `/Library/LaunchDaemons/org.openzfs.automount.daemon.plist` | Boot-time mounting |
| Config File | `/etc/zfs/automount.conf` | Dataset configuration |
| Encryption Keys | `/etc/zfs/keys/` | Secure keyfile storage |
| Logs | `/var/log/zfs-automount*.log` | Boot mount logs |

## Troubleshooting

### Common Issues

**Pools don't import at boot**
- Check `/var/log/zfs-automount-error.log`
- Verify OpenZFS kext is loaded: `kextstat | grep zfs`
- Manually test: `sudo zpool import -a`

**Encryption keys not working**
- Verify keyfile permissions: `ls -la /etc/zfs/keys/`
- Should be: `400 root:wheel`
- Check config: `cat /etc/zfs/automount.conf`

**Helper not responding**
- Reinstall via Preferences → Install/Update Helper
- Check status: `sudo launchctl list | grep openzfs`

See main [README.md](../README.md) for more troubleshooting tips.

## Project History

### Phase 1 (Current)
✅ Core mounting functionality
✅ Encryption key management via config files
✅ Boot-time auto-mount
✅ Menu bar interface
✅ Privileged helper via XPC

### Phase 2 (Future)
Planned enhancements documented in [PHASE2_MAINTENANCE.md](PHASE2_MAINTENANCE.md)

## Archive

The `archive/` subdirectory contains:
- Historical investigation notes
- Deprecated approaches
- Debugging scripts from keychain investigation

These are kept for reference but not actively maintained.

## Questions or Feedback?

- Open an issue on GitHub
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
- Review existing documentation before asking questions

---

**Last Updated**: 2025-10-16
**Project Status**: Phase 1 Complete
