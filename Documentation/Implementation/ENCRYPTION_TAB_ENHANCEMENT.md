# Encryption Tab Enhancement

## Overview

The Encryption tab has been **completely redesigned** to provide comprehensive key management for both Keychain and keyfile-based encryption.

## What's New

### 1. Shows ALL Encrypted Datasets
- Automatically discovers all encrypted datasets from ZFS
- Shows even datasets without configured keys
- Real-time status for each dataset

### 2. Dual Key Source Support
The tab now shows and manages **both** key storage methods:

#### 🔵 Keychain Keys
- Stored in macOS Keychain (user or system)
- Badge: Blue "Keychain"
- Icon: 🔑 (key.fill)
- Details: "Stored in macOS Keychain"

#### 🟢 Keyfile Keys
- Referenced in `/etc/zfs/automount.conf`
- Points to files in `/etc/zfs/keys/`
- Badge: Green "Keyfile"
- Icon: 📄 (doc.fill)
- Details: "Path: /etc/zfs/keys/filename.key"

#### ⚪️ No Key
- No key configured
- Badge: Gray "None"
- Details: "No key configured - will prompt on mount"

### 3. Edit Any Key
Click "Edit" button to:

**Change to Keychain:**
- Select "Keychain (Password/Hex)"
- Enter password or 64-char hex key
- Toggle eye icon to show/hide
- Saves to macOS Keychain

**Change to Keyfile:**
- Select "Keyfile Path"
- Enter path (e.g., `/etc/zfs/keys/tank.key`)
- Saves reference in config file
- Validates path format

**Switch Between Methods:**
- Can convert keychain key → keyfile
- Can convert keyfile → keychain
- Seamless transition

### 4. Delete Keys
Click "Delete" button:

**For Keychain Keys:**
- Removes from macOS Keychain
- Immediate deletion

**For Keyfile Keys:**
- Removes reference from config file
- **Doesn't delete actual keyfile**
- Keyfile remains in `/etc/zfs/keys/`

### 5. Refresh Button
- Click ↻ to reload key status
- Updates after external changes
- Shows current state from system

## New UI Layout

```
┌─────────────────────────────────────────────────┐
│ Encryption Keys                            ↻    │
├─────────────────────────────────────────────────┤
│                                                 │
│ 🔑 mypool/dataset1                        [Keychain]  │
│    Stored in macOS Keychain                     │
│                           [Edit]  [Delete]      │
│                                                 │
│ 📄 storage/dataset2                       [Keyfile]   │
│    Path: /etc/zfs/keys/media.key                │
│                           [Edit]  [Delete]      │
│                                                 │
│ ⚪️ pool/backup                         [None]   │
│    No key configured - will prompt on mount     │
│                           [Edit]  [Delete]      │
│                                                 │
├─────────────────────────────────────────────────┤
│ Key Sources:                                    │
│ 🔵 Keychain - Stored in macOS Keychain         │
│ 🟢 Keyfile - File in /etc/zfs/keys/            │
└─────────────────────────────────────────────────┘
```

## Edit Key Dialog

```
┌─────────────────────────────────────────────────┐
│ Edit Key for mypool/dataset1                          │
├─────────────────────────────────────────────────┤
│                                                 │
│ [Keychain (Password/Hex)] [Keyfile Path]       │
│                                                 │
│ ┌─────────────────────────────────────────┐ 👁 │
│ │ Enter password or hex key               │    │
│ └─────────────────────────────────────────┘    │
│ Enter passphrase or 64-character hex key       │
│                                                 │
│                      [Cancel]        [Save]     │
└─────────────────────────────────────────────────┘
```

## Use Cases

### Use Case 1: View All Keys
1. Open Preferences → Encryption tab
2. See all encrypted datasets with their key sources
3. Understand your current configuration

### Use Case 2: Add Keychain Key
1. Find dataset with "None" badge
2. Click "Edit"
3. Select "Keychain (Password/Hex)"
4. Enter password or hex key
5. Click "Save"
6. Key now stored in Keychain

### Use Case 3: Add Keyfile Reference
1. First, create keyfile on disk:
   ```bash
   sudo mkdir -p /etc/zfs/keys
   sudo cp /path/to/key /etc/zfs/keys/tank.key
   sudo chmod 400 /etc/zfs/keys/tank.key
   sudo chown root:wheel /etc/zfs/keys/tank.key
   ```
2. In Encryption tab, click "Edit"
3. Select "Keyfile Path"
4. Enter: `/etc/zfs/keys/tank.key`
5. Click "Save"
6. Config file updated with reference

### Use Case 4: Convert Keychain → Keyfile
1. Dataset currently using Keychain
2. Create keyfile on disk first
3. Click "Edit"
4. Switch to "Keyfile Path"
5. Enter keyfile path
6. Click "Save"
7. Old keychain entry auto-removed, config updated

### Use Case 5: Convert Keyfile → Keychain
1. Dataset currently using keyfile
2. Click "Edit"
3. Switch to "Keychain (Password/Hex)"
4. Enter the key value
5. Click "Save"
6. Config reference removed, key moved to keychain

### Use Case 6: Change Existing Key
1. Dataset has keychain key
2. Click "Edit"
3. Current key pre-populated
4. Modify the key
5. Click "Save"
6. Keychain entry updated

### Use Case 7: Delete Key
1. Click "Delete" on any dataset
2. Confirm deletion
3. **Keychain:** Entry removed from keychain
4. **Keyfile:** Reference removed from config (file not deleted)

## Technical Details

### How It Works

**On Tab Open:**
1. Query ZFS for all encrypted datasets
2. For each dataset:
   - Check `/etc/zfs/automount.conf` for keyfile reference
   - Check macOS Keychain for stored key
   - Mark source as keychain/keyfile/none
3. Display in list with badges and details

**On Edit:**
1. Open sheet dialog
2. Pre-populate current values
3. Allow switching between keychain/keyfile
4. On save:
   - If keychain: Save to Keychain via KeychainHelper
   - If keyfile: Update config via ConfigParser
   - Refresh display

**On Delete:**
1. Confirm with user
2. If keychain: Call `KeychainHelper.deleteKey()`
3. If keyfile: Call `ConfigParser.removeDataset()`
4. Refresh display

### Files Modified

- `PreferencesView.swift` - Complete Encryption tab rewrite
  - New `EncryptionTab` with comprehensive UI
  - New `EncryptionKeyInfo` struct
  - New `KeySource` enum
  - New `EditKeySheet` dialog
- `ConfigParser.swift` - Added helper methods
  - `updateConfig(for:options:)` - Update or add config entry
  - `removeDataset()` - Remove config entry

### API Used

**KeychainHelper:**
- `getKey(for:)` - Check if key exists in keychain
- `saveKey(_:for:)` - Save key to keychain
- `deleteKey(for:)` - Remove key from keychain

**ConfigParser:**
- `getConfig(for:)` - Get config entry for dataset
- `updateConfig(for:options:)` - Add/update config entry
- `removeDataset()` - Remove config entry

**ZFSManager:**
- `getDatasets()` - Get all datasets
- Filter by `.encrypted` property

## Benefits

### ✅ Complete Visibility
- See ALL encrypted datasets in one place
- Know which method each uses
- Identify datasets without keys

### ✅ Unified Management
- Manage both keychain and keyfile keys
- No need to edit config files manually
- No need to use `security` command

### ✅ Easy Switching
- Convert between methods with 2 clicks
- Test different approaches
- Migrate keys as needed

### ✅ Safe Operations
- Confirmation before deletion
- Keyfile deletion doesn't remove actual file
- Clear warnings and instructions

### ✅ Better UX
- Visual badges for quick identification
- Color-coded by source type
- Helpful descriptions

## Recommendations

### For Most Users
**Use Keychain** - Easier to manage, works for post-login scenarios

### For Boot-Time Mounting
**Use Keyfiles** - More reliable at boot (before user login)
- Create keyfiles in `/etc/zfs/keys/`
- Use config file to reference them
- Permissions: 400, root:wheel

### For Testing
**Try Both** - Easy to switch between methods to see what works best

## Troubleshooting

### "No key configured" showing but I have a keyfile
**Cause:** Config file not referencing the keyfile

**Solution:**
1. Click "Edit"
2. Select "Keyfile Path"
3. Enter the path to your keyfile
4. Click "Save"

### Edit button not saving
**Cause:** Invalid path or empty field

**Solution:**
- For keychain: Enter a non-empty key
- For keyfile: Enter full path starting with `/`

### Keyfile path saved but mounting still prompts
**Cause:** File doesn't exist or wrong permissions

**Solution:**
```bash
# Check file exists
ls -la /etc/zfs/keys/your-file.key

# Should show: -r-------- 1 root wheel

# Fix permissions if needed
sudo chmod 400 /etc/zfs/keys/your-file.key
sudo chown root:wheel /etc/zfs/keys/your-file.key
```

### Can't delete keyfile reference
**Cause:** Permission issue with config file

**Solution:**
Config file `/etc/zfs/automount.conf` should be writable by user

### Changes not reflecting immediately
**Cause:** Tab doesn't auto-refresh

**Solution:** Click the ↻ (refresh) button

## Examples

### Example 1: Fresh Setup with Keyfile

```bash
# 1. Create keyfile
sudo mkdir -p /etc/zfs/keys
sudo dd if=/dev/random of=/etc/zfs/keys/tank.key bs=32 count=1
sudo chmod 400 /etc/zfs/keys/tank.key
sudo chown root:wheel /etc/zfs/keys/tank.key

# 2. In app: Preferences → Encryption
# 3. Find "mypool/dataset1" with "None" badge
# 4. Click "Edit"
# 5. Select "Keyfile Path"
# 6. Enter: /etc/zfs/keys/tank.key
# 7. Click "Save"
# 8. Badge changes to "Keyfile" 🟢
```

### Example 2: Migrate Keychain → Keyfile

```bash
# Current: mypool/dataset1 using Keychain
# Goal: Move to keyfile

# 1. Export key from keychain (if needed)
security find-generic-password -s org.openzfs.automount -a mypool/dataset1 -w > /tmp/key.txt

# 2. Create keyfile
sudo mkdir -p /etc/zfs/keys
sudo mv /tmp/key.txt /etc/zfs/keys/tank.key
sudo chmod 400 /etc/zfs/keys/tank.key
sudo chown root:wheel /etc/zfs/keys/tank.key

# 3. In app: Click "Edit" on mypool/dataset1
# 4. Switch to "Keyfile Path"
# 5. Enter: /etc/zfs/keys/tank.key
# 6. Click "Save"
# 7. Done! Keychain entry auto-removed
```

---

**Last Updated:** 2025-10-16
**Status:** ✅ Fully implemented and ready to test
