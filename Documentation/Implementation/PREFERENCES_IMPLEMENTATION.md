# Preferences Implementation

## Overview

The Preferences window now **actually works**! Toggles control real system behavior:
- Auto-import/mount on boot → Installs/removes LaunchDaemon
- Show notifications → Enables/disables notification popups

## What Was Implemented

### 1. Boot Automation Toggles

**Before:** Toggles saved to UserDefaults but did nothing
**After:** Toggles install/remove the LaunchDaemon automatically

When you enable "Auto-import pools on boot" or "Auto-mount datasets on boot":
1. App creates LaunchDaemon plist at `/tmp/org.openzfs.automount.daemon.plist`
2. Uses AppleScript to request admin privileges
3. Copies plist to `/Library/LaunchDaemons/`
4. Sets proper ownership (root:wheel) and permissions (644)
5. Loads the LaunchDaemon
6. Shows success alert

When you disable both toggles:
1. Unloads the LaunchDaemon
2. Removes the plist file
3. Shows confirmation alert

### 2. Notification Toggle

**Before:** Saved to UserDefaults but always showed notifications
**After:** Actually controls whether notifications appear

The `showNotifications` preference is checked before displaying any notification:
- Enabled → Shows notification with sound
- Disabled → Silently skips notification (prints to console only)

### 3. Verification Script

Created `check-boot-automation.sh` to verify the setup:
- Checks if LaunchDaemon file exists
- Checks if LaunchDaemon is loaded
- Shows UserDefaults preferences
- Displays boot logs
- Shows privileged helper status
- Provides summary and troubleshooting

## Code Changes

### PreferencesView.swift

**Added methods:**
- `updateLaunchDaemon()` - Decides whether to install/remove based on toggle state
- `installLaunchDaemon()` - Creates and installs LaunchDaemon plist
- `removeLaunchDaemon()` - Unloads and removes LaunchDaemon
- `showAlert()` - Displays feedback to user

**Toggle behavior:**
```swift
Toggle("Auto-import pools on boot", isOn: $autoImportOnBoot)
    .onChange(of: autoImportOnBoot) { _, newValue in
        UserDefaults.standard.set(newValue, forKey: "autoImportOnBoot")
        updateLaunchDaemon()  // ← NEW: Actually does something!
    }
```

### MenuBarController.swift

**Updated notification method:**
```swift
private func showNotification(title: String, message: String) {
    // Check if notifications are enabled
    let showNotifications = UserDefaults.standard.bool(forKey: "showNotifications")
    guard showNotifications else {
        print("Notifications disabled, skipping: \(title)")
        return
    }
    // ... show notification
}
```

## How to Test

### 1. Deploy the Updated App

```bash
./deploy-simple.sh
```

### 2. Check Current Status

```bash
./check-boot-automation.sh
```

This will show you:
- Whether LaunchDaemon is installed
- Whether it's loaded
- Current preference settings
- Boot logs (if any)

### 3. Test Boot Automation Toggle

1. Open Preferences (click menu bar icon → Preferences)
2. Turn ON "Auto-import pools on boot"
3. You'll be prompted for admin password
4. Should see "Success" alert
5. Run verification:
   ```bash
   ./check-boot-automation.sh
   ```
6. Should show LaunchDaemon is installed and loaded

### 4. Test Notification Toggle

1. In Preferences, turn ON "Show notifications"
2. Click "Mount All Datasets" from menu bar
3. Should see notification popup
4. Turn OFF "Show notifications"
5. Click "Mount All Datasets" again
6. Should NOT see notification (check Console.app for log message)

### 5. Verify LaunchDaemon Files

```bash
# Check if LaunchDaemon file exists
ls -la /Library/LaunchDaemons/org.openzfs.automount.daemon.plist

# Check if it's loaded
sudo launchctl list | grep openzfs

# View the plist content
cat /Library/LaunchDaemons/org.openzfs.automount.daemon.plist

# Check boot logs
tail -20 /var/log/zfs-automount.log
tail -20 /var/log/zfs-automount-error.log
```

## Expected Behavior

### Boot Automation ON
- LaunchDaemon file exists: ✅
- LaunchDaemon loaded: ✅
- On next boot: Pools auto-import and datasets auto-mount
- Logs appear in `/var/log/zfs-automount.log`

### Boot Automation OFF
- LaunchDaemon file: ❌ Removed
- LaunchDaemon loaded: ❌ Unloaded
- On next boot: Nothing happens automatically
- Must manually import/mount from menu bar

### Notifications ON
- Mount success: Shows green notification
- Mount failure: Shows alert dialog
- Console.app: Shows all messages

### Notifications OFF
- No popup notifications
- Alerts still shown (for errors)
- Console.app: Shows "Notifications disabled, skipping: ..."

## Troubleshooting

### LaunchDaemon Not Installing

**Problem:** Toggle is on but LaunchDaemon doesn't install

**Solutions:**
1. Check Console.app for error messages (search "ZFSAutoMount")
2. Ensure you entered admin password correctly
3. Manually check permissions:
   ```bash
   ls -la /Library/LaunchDaemons/ | grep openzfs
   ```
4. Try installing privileged helper first (Preferences → Install/Update Helper)

### Boot Mounting Not Working

**Problem:** LaunchDaemon installed but pools don't mount at boot

**Debugging:**
1. Check boot logs:
   ```bash
   cat /var/log/zfs-automount.log
   cat /var/log/zfs-automount-error.log
   ```
2. Manually test boot mount:
   ```bash
   sudo /Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --boot-mount
   ```
3. Check if OpenZFS is loaded at boot:
   ```bash
   kextstat | grep zfs
   ```

### Notifications Not Appearing

**Problem:** Notifications toggle is on but no popups

**Solutions:**
1. Check System Settings → Notifications → ZFSAutoMount
2. Ensure "Allow Notifications" is enabled
3. Check "Show notifications on lock screen" and other options
4. Restart the app after changing settings

### Preferences Not Saving

**Problem:** Toggles reset when reopening Preferences

**Check:**
```bash
# View saved preferences
defaults read org.openzfs.ZFSAutoMount

# Should show:
# autoImportOnBoot = 1;
# autoMountOnBoot = 1;
# showNotifications = 1;
```

If empty, preferences aren't being saved. Check Console.app for errors.

## Security Notes

### AppleScript Admin Privileges

The app uses AppleScript's `with administrator privileges` to:
- Install LaunchDaemon (requires root)
- Set file ownership to root:wheel
- Load/unload LaunchDaemon

This is safe because:
- User explicitly toggles the setting
- System prompts for password
- Code is visible and auditable
- Standard macOS security practice

### LaunchDaemon Security

The LaunchDaemon:
- Runs as root (required for `zpool import`)
- Only runs at boot (not constantly)
- Executes only the app with `--boot-mount` flag
- Logs all output to `/var/log/`

## Files Modified

- `ZFSAutoMount/PreferencesView.swift` - Added LaunchDaemon install/remove logic
- `ZFSAutoMount/MenuBarController.swift` - Added notification preference check
- `check-boot-automation.sh` - NEW verification script

## Next Steps

After deploying, you should:

1. ✅ Enable boot automation toggles
2. ✅ Verify LaunchDaemon is installed
3. ✅ Test manual mount with notifications on/off
4. ✅ Reboot and check logs
5. ✅ Verify pools auto-imported and datasets auto-mounted

---

**Last Updated:** 2025-10-16
**Status:** ✅ Fully implemented and ready to test
