# Boot Automation Toggles - How They Work

## The Two Toggles

There are **two independent toggles** in Preferences:

1. **Auto-import pools on boot**
2. **Auto-mount datasets on boot**

However, they control a **single LaunchDaemon** that runs at boot time.

## How They Work Together

### Toggle Combinations

| Import Toggle | Mount Toggle | What Happens at Boot |
|--------------|-------------|---------------------|
| ❌ OFF | ❌ OFF | Nothing (LaunchDaemon not installed) |
| ✅ ON | ❌ OFF | Import pools only, don't mount datasets |
| ❌ OFF | ✅ ON | Import pools + mount datasets (auto-enables import) |
| ✅ ON | ✅ ON | Import pools + mount datasets |

### Why This Design?

**ZFS Operation Order:**
1. **Import** - Makes pools visible to the system
2. **Mount** - Makes datasets accessible as filesystems

You **cannot mount datasets without importing pools first**. Therefore:
- If you enable "mount datasets" → pools are auto-imported too
- If you only enable "import pools" → pools are imported but datasets stay unmounted
- If both are off → LaunchDaemon is removed entirely

## The Single LaunchDaemon

There is **one LaunchDaemon file**:
```
/Library/LaunchDaemons/org.openzfs.automount.daemon.plist
```

This daemon:
- Runs at boot (before user login)
- Executes: `/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount`
- The app reads UserDefaults to decide what to do

## Boot Sequence

When the LaunchDaemon runs:

```
1. Check disk subsystem is ready
2. Read preferences: import=?, mount=?
3. ┌─ If EITHER toggle is ON:
   │   ├─ Import all pools (zpool import -a)
   │   └─ IF mount toggle is ON:
   │       └─ Mount all datasets (zfs mount -a)
   └─ If BOTH toggles are OFF:
       └─ Exit (shouldn't happen - daemon should be uninstalled)
4. Write logs to /var/log/zfs-automount.log
5. Exit
```

## Use Cases

### Use Case 1: Full Automation (Both ON)
**Who:** Most users who want everything "just working"

**Toggles:**
- ✅ Auto-import pools on boot
- ✅ Auto-mount datasets on boot

**Result:**
- Boot → Pools imported → Datasets mounted → Ready to use

### Use Case 2: Import Only (Import ON, Mount OFF)
**Who:** Users who want manual control over which datasets to mount

**Toggles:**
- ✅ Auto-import pools on boot
- ❌ Auto-mount datasets on boot

**Result:**
- Boot → Pools imported → Datasets NOT mounted
- User manually mounts specific datasets via menu bar or terminal

**Why:** Security/privacy - keep encrypted datasets unmounted until needed

### Use Case 3: Manual Everything (Both OFF)
**Who:** Advanced users who want full manual control

**Toggles:**
- ❌ Auto-import pools on boot
- ❌ Auto-mount datasets on boot

**Result:**
- Boot → Nothing happens
- User manually imports pools and mounts datasets when needed
- LaunchDaemon is uninstalled

## Implementation Details

### LaunchDaemon Installation

When you enable **either toggle**:
1. App creates `/tmp/org.openzfs.automount.daemon.plist`
2. Prompts for admin password
3. Copies to `/Library/LaunchDaemons/`
4. Loads with `launchctl load`

When you disable **both toggles**:
1. Prompts for admin password
2. Unloads with `launchctl unload`
3. Deletes from `/Library/LaunchDaemons/`

### Preference Storage

Preferences are stored in UserDefaults:
```bash
defaults read org.openzfs.ZFSAutoMount
# Output:
# autoImportOnBoot = 1;
# autoMountOnBoot = 1;
# showNotifications = 1;
```

The `--boot-mount` handler reads these preferences to decide what to do.

### Code Flow

**PreferencesView.swift:**
```swift
// Either toggle changes → calls updateLaunchDaemon()
Toggle("Auto-import pools on boot", isOn: $autoImportOnBoot)
    .onChange { oldValue, newValue in
        updateLaunchDaemon(oldValue: oldValue, newValue: newValue)
    }

// Decides: install or remove?
func updateLaunchDaemon(oldValue: Bool, newValue: Bool) {
    let shouldInstall = autoImportOnBoot || autoMountOnBoot

    if shouldInstall {
        installLaunchDaemon { success in ... }
    } else {
        removeLaunchDaemon { success in ... }
    }
}
```

**ZFSAutoMountApp.swift:**
```swift
func handleBootMount() {
    // Read preferences
    let shouldImport = UserDefaults.standard.bool(forKey: "autoImportOnBoot")
    let shouldMount = UserDefaults.standard.bool(forKey: "autoMountOnBoot")

    // Always import if either is on
    if shouldImport || shouldMount {
        importAllPools { success in
            // Only mount if that toggle is on
            if shouldMount {
                mountAllDatasets { ... }
            }
        }
    }
}
```

## Logging

Check what happened at boot:

```bash
# Main log
cat /var/log/zfs-automount.log

# Example output:
# [2025-10-16 08:00:01] ZFS AutoMount: Starting boot-time automation
# [2025-10-16 08:00:01] ZFS AutoMount: Preferences: import=true, mount=true
# [2025-10-16 08:00:01] ZFS AutoMount: Waiting for disk subsystem to be ready
# [2025-10-16 08:00:06] ZFS AutoMount: Disk subsystem ready - proceeding with pool import
# [2025-10-16 08:00:06] ZFS AutoMount: Importing all pools...
# [2025-10-16 08:00:07] ZFS AutoMount: ✅ Pools imported successfully
# [2025-10-16 08:00:07] ZFS AutoMount: Mounting all datasets...
# [2025-10-16 08:00:09] ZFS AutoMount: ✅ All datasets mounted successfully

# Error log (if any)
cat /var/log/zfs-automount-error.log
```

## Testing

### Test Scenario 1: Both OFF → Both ON
1. Start with both toggles OFF
2. Turn ON "Auto-import pools on boot"
3. Enter password → Success alert
4. LaunchDaemon installed
5. Turn ON "Auto-mount datasets on boot"
6. No password prompt (daemon already installed)
7. Reboot → Check logs → Both import and mount should happen

### Test Scenario 2: Both ON → Import Only
1. Start with both toggles ON
2. Turn OFF "Auto-mount datasets on boot"
3. No password prompt (daemon stays installed)
4. Reboot → Check logs → Only import happens, no mounting

### Test Scenario 3: Import Only → Both OFF
1. Start with import ON, mount OFF
2. Turn OFF "Auto-import pools on boot"
3. Password prompt → Daemon removed
4. Reboot → Nothing happens

## Common Questions

**Q: Why can't I mount datasets without importing pools?**
A: ZFS requires pools to be imported before their datasets are visible. It's a ZFS limitation, not an app limitation.

**Q: If I only turn on "mount", why does it also import?**
A: Because mounting requires importing first. The app does this automatically for convenience.

**Q: Why is there one LaunchDaemon for two toggles?**
A: Because the operations are sequential (import → mount). One daemon handles both steps based on your preferences.

**Q: Can I have pools auto-import but manually select which datasets to mount?**
A: Yes! Turn ON "import" and OFF "mount". Then use the menu bar to mount specific datasets after login.

**Q: What if I manually install the LaunchDaemon outside the app?**
A: The app will detect it on next launch and sync the toggles to ON.

## Recommendations

### For Most Users
✅ **Both toggles ON** - Simplest, everything works automatically

### For Privacy-Conscious Users
✅ **Import ON, Mount OFF** - Pools available, but encrypted datasets stay locked until you mount them manually

### For Advanced Users
✅ **Both OFF** - Full manual control via menu bar or terminal

---

**Last Updated:** 2025-10-16
**Status:** Implemented and tested
