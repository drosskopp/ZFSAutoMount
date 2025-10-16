# macOS Keychain Integration - Investigation Results

**Date**: 2025-10-16
**Status**: ⚠️ NOT RECOMMENDED - Use config file approach instead
**Reason**: macOS security restrictions prevent reliable automated keychain access

## Summary

We attempted to store ZFS encryption keys in macOS Keychain (both user and system keychains) to enable automated mounting at boot time. After extensive investigation and testing, we **recommend using the config file approach** instead.

## What We Tried

### Approach 1: User Keychain Only
- **Goal**: Store keys in user's login keychain for post-login access
- **Result**: ❌ Failed - keychain not available at boot time (before user login)
- **Issue**: Chicken-and-egg problem - need user logged in to access user keychain

### Approach 2: System Keychain Only
- **Goal**: Store keys in `/Library/Keychains/System.keychain` for boot-time access
- **Result**: ❌ Failed - permission issues even when running as root
- **Issue**: System keychain requires special ACLs and trust relationships

### Approach 3: Dual Keychain (User + System)
- **Goal**: Store in both keychains - system for boot, user for post-login
- **Result**: ❌ Failed - could not reliably add entries to either keychain
- **Issue**: Multiple technical barriers (see below)

### Approach 4: Privileged Helper Reads Keychain
- **Goal**: Have root-level helper read system keychain directly
- **Result**: ❌ Failed - helper couldn't read entries reliably
- **Issue**: NSLog from helper not visible, unclear what was happening

## Technical Issues Encountered

### Issue 1: `security add-generic-password` Behavior
**Problem**: The `security` command behaves unpredictably with stdin and command-line arguments

**Symptoms**:
- Adding newlines to stored passwords
- Reading wrong data from stdin
- "User interaction is not allowed" errors
- "Write permissions error" even when running as correct user

**Attempts**:
```bash
# These all failed in different ways:
security add-generic-password -w "$KEY"           # Adds newline
echo "$KEY" | security add-generic-password -w -  # Reads wrong data
printf "%s" "$KEY" | security add-generic-password -w -  # User interaction error
```

### Issue 2: sudo -u Keychain Access
**Problem**: `sudo -u username security add-generic-password` doesn't work as expected

**Symptoms**:
- Defaults to system keychain even when run as user
- Can't create new entries ("User interaction is not allowed")
- Can update existing entries but corrupts data
- Pipe (stdin) doesn't work through sudo -u

**Why**: macOS security framework requires the actual user session context, not just UID

### Issue 3: Binary vs Text Keys
**Problem**: Raw AES-256 keys are 32 bytes of binary data, need hex encoding

**Solution Found**: Must convert binary to hex string before storing
```swift
// Reading binary keyfile:
let keyData = Data(contentsOf: URL(fileURLWithPath: keyPath))
let hexKey = keyData.map { String(format: "%02x", $0) }.joined()
```

### Issue 4: Helper Logging
**Problem**: NSLog() from privileged helper daemon doesn't appear in console

**Impact**: Impossible to debug helper's keychain access attempts

**Attempted Solutions**:
- `sudo log show --predicate 'eventMessage contains "ZFSAutoMount Helper"'` - no output
- `/var/log/system.log` - no entries
- Console.app - no entries

**Likely Cause**: Privileged helpers run in different logging context

### Issue 5: Keychain Entry Conflicts
**Problem**: Entries in system keychain prevent user keychain entries

**Symptoms**:
- Delete from user keychain succeeds, but find-generic-password still finds entry in system keychain
- Add to user keychain tries to update system keychain entry
- "Write permissions error" because can't update system keychain as user

**Workaround Needed**: Must delete from BOTH keychains before adding

### Issue 6: Empty/Corrupted Entries
**Problem**: Multiple attempts created corrupted entries (0-2 characters instead of 64)

**Root Causes**:
- stdin contamination from previous command output
- Command-line argument processing adding newlines
- Update vs Create mode confusion
- Encoding issues (binary vs text vs hex)

## What DID Work

### Config File Approach ✅
**Location**: `/etc/zfs/automount.conf`

**Format**:
```
# dataset_name keylocation=file:///path/to/keyfile
tank/encrypted keylocation=file:///etc/zfs/keys/encrypted.key
```

**Keyfile Setup**:
```bash
sudo mkdir -p /etc/zfs/keys
sudo cp /path/to/key /etc/zfs/keys/encrypted.key
sudo chmod 400 /etc/zfs/keys/encrypted.key
sudo chown root:wheel /etc/zfs/keys/encrypted.key
```

**Why It Works**:
- Root can read `/etc/zfs/keys/` at boot time
- No keychain API complexity
- Direct file access (no security framework)
- Works identically at boot and post-login
- Easy to debug (just check file permissions)

**Code Support**: Already implemented in ZFSManager.swift:238-271

## Recommendations

### For New Projects
✅ **Use config file approach from the start**
- Simpler implementation
- Fewer failure modes
- Easier debugging
- Works reliably at boot

### For Existing Projects
If you absolutely need keychain integration:

1. **User Keychain Only** (for post-login scenarios):
   ```swift
   // Run in user context (not via sudo)
   let query: [String: Any] = [
       kSecClass as String: kSecClassGenericPassword,
       kSecAttrService as String: "your.service.id",
       kSecAttrAccount as String: "dataset-name",
       kSecValueData as String: hexKeyData,
       kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
   ]
   SecItemAdd(query as CFDictionary, nil)
   ```

2. **System Keychain** (for boot-time scenarios):
   ```bash
   # Must run as root, add trusted applications
   sudo security add-generic-password \
       -s "service" -a "account" -w "hex-key" \
       -T "/path/to/your/app" \
       -T "/path/to/helper" \
       "/Library/Keychains/System.keychain"
   ```

3. **Accept Manual Approval**:
   - User WILL be prompted on first access
   - Store in keychain after prompt for future use
   - Don't try to eliminate prompts entirely

## Lessons Learned

1. **macOS Security Framework is Restrictive** - By design, not a bug
2. **Automation Requires User Session** - Can't bypass security without user present
3. **Keychain API ≠ security CLI** - Different code paths, different behaviors
4. **Simpler is Better** - Config file approach has fewer dependencies
5. **Test Early** - We should have validated keychain approach before building features around it

## Alternative Solutions Considered

### 1. Keychain Access Framework (Swift)
Instead of `security` command, use Keychain Services API directly.
- **Pro**: More control, better error messages
- **Con**: Still has same security restrictions
- **Verdict**: Wouldn't solve core issues

### 2. Store Keys in App Container
- **Pro**: Easy file access
- **Con**: Security risk (not encrypted at rest)
- **Verdict**: Unacceptable for encryption keys

### 3. Prompt User at Boot
- **Pro**: User sees what's happening
- **Con**: Defeats purpose of automation
- **Verdict**: Not suitable for boot-time mounting

### 4. TPM/Secure Enclave
- **Pro**: Hardware-backed security
- **Con**: Requires T2/Apple Silicon, complex API
- **Verdict**: Over-engineered for this use case

## Conclusion

**Use the config file approach** (`/etc/zfs/automount.conf` + `/etc/zfs/keys/`).

It provides:
- ✅ Boot-time access
- ✅ Secure permissions (root-only)
- ✅ Simple implementation
- ✅ Easy debugging
- ✅ No user interaction required
- ✅ Works reliably across macOS versions

The keychain approach, while theoretically superior, introduces too many variables and failure modes for a critical system service like ZFS auto-mounting.

---

## Scripts Created During Investigation

Location: Project root (should be moved to `Documentation/archive/`)

- `fix-empty-keychain.sh` - Attempted to fix corrupted entries
- `fix-keychain-import.sh` - Early fix attempt
- `import-to-both-keychains.sh` - Dual keychain approach
- `copy-working-key.sh` - Tried to clone working entry
- `import-keys-simple.sh` - Simplified import attempt
- `diagnose-keychain.sh` - Debugging tool
- `check-keychain-keys.sh` - Verification tool
- `check-system-keychain.sh` - System keychain inspector

**Action**: Archive these for reference, don't include in releases

---

**Last Updated**: 2025-10-16
**Status**: Investigation complete, recommend config file approach
