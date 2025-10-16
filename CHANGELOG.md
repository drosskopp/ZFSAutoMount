# Changelog

## [0.1.2] - 2025-10-16 12:25

### Fixed
- **Helper installation SMJobBless error** - CFErrorDomainLaunchd error 2 due to code signing requirements
- Created manual LaunchDaemon installation method for development (bypasses SMJobBless)
- Relaxed code signing requirements in Info.plist files
- Fixed HelperMain.swift to use `@main` attribute properly

### Added
- `INSTALL_HELPER_ON_MINI.sh` - Manual helper installation script
- `HELPER_INSTALLATION.md` - Documentation for helper installation
- Helper logs at `/var/log/zfs-automount-helper.log`

### Note
- For production use with proper code signing, SMJobBless will work
- For development/personal use, manual LaunchDaemon installation is recommended

## [0.1.1] - 2025-10-16 12:10

### Fixed
- **Preferences window not opening** - Added fallback to create NSWindow manually when Settings scene doesn't respond
- Improved preferences window opening reliability on macOS 26

### Changes
- MenuBarController now keeps reference to preferences window
- Added dual approach: try Settings scene first, fall back to manual window creation

## [0.1.0] - 2025-10-16 11:50

### Added
- Initial release
- Auto-detection of ZFS pools and datasets
- Menu bar interface showing pool health and capacity
- Support for OpenZFS at `/usr/local/zfs/bin/` (OpenZFS on OS X default path)
- Auto-detection of ZFS binaries in multiple locations
- Keychain integration for encryption key storage
- Configuration file support (`/etc/zfs/automount.conf`)
- Privileged helper for root operations
- SwiftUI preferences interface

### Fixed
- ZFS path detection (was looking in `/usr/local/bin/`, now checks `/usr/local/zfs/bin/` first)
- Build errors with Process API (updated to use `executableURL`)
- AppKit imports and API usage
- Top-level expression error in HelperMain.swift

### Known Issues
- Privileged helper installation not yet tested
- Boot-time mounting not yet configured
- Some deprecation warnings (non-critical)
