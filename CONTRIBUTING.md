# Contributing to ZFSAutoMount

Thank you for your interest in contributing to ZFSAutoMount! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- macOS 26.0 (Tahoe) or later
- Xcode 16.0 or later
- OpenZFS installed via Homebrew (`brew install openzfs`)
- A ZFS pool for testing (required for integration tests)

### Setting Up Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ZFSAutoMount.git
   cd ZFSAutoMount
   ```

2. Open the project in Xcode:
   ```bash
   open ZFSAutoMount.xcodeproj
   ```

3. Build the project (⌘+B) to ensure everything compiles

## Project Structure

```
ZFSAutoMount/
├── ZFSAutoMount/              # Main application (user-level)
│   ├── ZFSAutoMountApp.swift  # App entry point
│   ├── MenuBarController.swift # Menu bar UI
│   ├── ZFSManager.swift       # Core ZFS operations
│   ├── KeychainHelper.swift   # Keychain integration
│   └── PreferencesView.swift  # Settings window
│
├── PrivilegedHelper/          # Root-level operations via XPC
│   ├── HelperMain.swift
│   └── HelperProtocol.swift
│
├── Documentation/             # Technical documentation
├── Examples/                  # Configuration examples
└── Scripts/                   # Helper scripts for testing
```

## Development Guidelines

### Code Style

- Follow Swift standard naming conventions
- Use descriptive variable and function names
- Add comments for complex logic
- Keep functions focused and single-purpose
- Maximum line length: 120 characters (soft limit)

### Security Considerations

This app handles sensitive operations (root privileges, encryption keys). Always:

1. **Never store encryption keys in plain text**
   - Keys should only be in `/etc/zfs/keys/` with proper permissions (400, root:wheel)
   - Or in macOS Keychain (if using keychain approach)

2. **Validate all XPC inputs**
   - The privileged helper receives commands from the user-level app
   - Always validate dataset names, paths, and commands

3. **Use proper privilege separation**
   - Only run operations that need root in the privileged helper
   - User-level app should handle UI and configuration

4. **Test with ad-hoc signing first**
   - Don't distribute builds with your Developer ID without thorough testing

### Testing

#### Unit Testing
- Add tests for new functionality in `ZFSAutoMountTests/`
- Run tests: ⌘+U in Xcode

#### Integration Testing
Create a test pool for development:
```bash
# Create a test pool (adjust size and path as needed)
dd if=/dev/zero of=/tmp/testpool.img bs=1m count=512
sudo zpool create testpool /tmp/testpool.img

# Create an encrypted dataset
sudo zfs create -o encryption=on -o keyformat=hex testpool/encrypted

# Test with the app
sudo /path/to/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount
```

#### Before Submitting PR
1. Build succeeds with no warnings
2. All tests pass
3. Test on actual ZFS pool (if possible)
4. Code follows style guidelines
5. Documentation updated if needed

## Making Changes

### Workflow

1. **Fork the repository** (for external contributors)

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**:
   - Write clear, focused commits
   - Include tests for new functionality
   - Update documentation as needed

4. **Test thoroughly**:
   - Build and run the app
   - Test with real ZFS pools
   - Verify privileged helper works

5. **Submit a Pull Request**:
   - Clear description of changes
   - Reference any related issues
   - Include screenshots for UI changes

### Commit Messages

Use clear, descriptive commit messages:

```
Add support for custom mount options in config file

- Parse additional mount options from automount.conf
- Pass options to zfs mount command
- Update documentation with examples
```

Format:
- First line: brief summary (50 chars or less)
- Blank line
- Detailed description with bullet points

## Areas for Contribution

### High Priority

1. **Testing on different macOS versions**
   - Verify compatibility with various macOS releases
   - Document any version-specific issues

2. **Testing with different ZFS configurations**
   - Various encryption types (aes-256-gcm, etc.)
   - Different pool layouts (mirrors, raidz, etc.)
   - Edge cases (corrupted pools, missing keys, etc.)

3. **Error handling improvements**
   - Better error messages for common issues
   - Recovery from failed mount attempts
   - Logging improvements

### Medium Priority

1. **UI/UX improvements**
   - Better visual feedback in menu bar
   - Preferences window enhancements
   - Notification support

2. **Documentation**
   - More detailed troubleshooting guides
   - Video tutorials
   - FAQ section

3. **Code cleanup**
   - Refactoring for better maintainability
   - Performance optimizations
   - Memory leak detection

### Future Enhancements (Phase 2)

These are intentionally deferred but welcome as separate projects:

- Pool scrub scheduling
- TRIM scheduling for SSDs
- Health monitoring with notifications
- Desktop widgets
- iOS companion app
- Statistics dashboard

## Code Review Process

1. Maintainer reviews the PR
2. Feedback provided via GitHub comments
3. Author addresses feedback
4. Maintainer approves and merges

**Review time**: Usually within 1-2 weeks, depending on PR complexity

## Security Issues

**Do not open public issues for security vulnerabilities.**

Instead, email details to: [your-security-email@example.com]

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Check existing documentation in `Documentation/` folder

## Getting Help

If you're stuck:

1. Check `Documentation/PROJECT_SUMMARY.md` for architecture details
2. Review existing code for similar functionality
3. Open a discussion on GitHub
4. Look at closed PRs for examples

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the project
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing others' private information
- Other conduct inappropriate in a professional setting

Thank you for contributing to ZFSAutoMount!
