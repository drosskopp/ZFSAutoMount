# Real-Time Pool Monitoring

## Overview

ZFSAutoMount now includes **real-time disk monitoring** that automatically updates the menu bar whenever volumes are mounted or unmounted. This means you get instant feedback without waiting for the 30-second timer.

## How It Works

The app uses macOS's `NSWorkspace` notification system to monitor three types of events:

1. **Volume Mount** (`didMountNotification`)
   - Triggered when any volume is mounted
   - Includes ZFS datasets, external drives, disk images, etc.

2. **Volume Unmount** (`didUnmountNotification`)
   - Triggered when any volume is unmounted
   - Includes explicit unmounts and ejected drives

3. **Volume Rename** (`didRenameVolumeNotification`)
   - Triggered when a volume is renamed (rare but supported)

When any of these events occur:
- Event is detected immediately
- Wait 0.5 seconds (gives ZFS time to update its state)
- Refresh pool information via `ZFSManager.refreshPools()`
- Update menu bar display
- Post notification to `ZFSPoolsDidChange`

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  macOS System                                          │
│  - Volume mounted/unmounted                            │
└────────────────────────────────────────────────────────┘
                      ↓
        NSWorkspace.didMountNotification
        NSWorkspace.didUnmountNotification
        NSWorkspace.didRenameVolumeNotification
                      ↓
┌────────────────────────────────────────────────────────┐
│  DiskMonitor.swift                                     │
│  - Observes NSWorkspace notifications                  │
│  - Logs events with NSLog                              │
│  - Triggers callback after 0.5 second delay            │
└────────────────────────────────────────────────────────┘
                      ↓
┌────────────────────────────────────────────────────────┐
│  MenuBarController.swift                               │
│  - Receives onDiskChanged callback                     │
│  - Calls ZFSManager.refreshPools()                     │
│  - Updates menu bar UI                                 │
└────────────────────────────────────────────────────────┘
                      ↓
┌────────────────────────────────────────────────────────┐
│  ZFSManager.swift                                      │
│  - Queries zpool list and zfs list                     │
│  - Updates internal state                              │
│  - Posts ZFSPoolsDidChange notification                │
└────────────────────────────────────────────────────────┘
```

## Implementation Details

### DiskMonitor.swift

**Location**: `ZFSAutoMount/DiskMonitor.swift`

**Key Features**:
- Singleton pattern (`DiskMonitor.shared`)
- Uses `NSWorkspace.shared.notificationCenter` for system-wide volume events
- Callback-based design: `onDiskChanged: (() -> Void)?`
- Automatic cleanup via `deinit`

**Usage**:
```swift
let monitor = DiskMonitor.shared

// Set up callback
monitor.onDiskChanged = {
    print("Disk changed!")
    self.refreshPools()
}

// Start monitoring
monitor.startMonitoring()

// Stop monitoring (optional, done automatically in deinit)
monitor.stopMonitoring()
```

### Integration with MenuBarController

**Changes to MenuBarController.swift**:

1. Added `diskMonitor` property
2. Added `startDiskMonitoring()` method
3. Configured callback to refresh pools when events occur
4. Kept 30-second timer as backup

**Code**:
```swift
private func startDiskMonitoring() {
    diskMonitor.onDiskChanged = { [weak self] in
        NSLog("MenuBarController: Disk event detected, refreshing pools")
        self?.zfsManager.refreshPools()
    }
    diskMonitor.startMonitoring()
}
```

## Benefits

### Instant Updates
- Menu bar updates within 0.5 seconds of mount/unmount
- No waiting for 30-second polling interval
- Better user experience

### Resource Efficient
- Event-driven (not polling)
- Only runs `zpool list` when needed
- Minimal CPU usage when idle

### Reliable
- Built on macOS's native notification system
- Works for all volume types (not just ZFS)
- 30-second timer provides backup in case events are missed

## Testing

### Manual Testing

1. **Deploy the updated app**:
   ```bash
   ./deploy-updated-app-with-diskmonitor.sh
   ```

2. **Watch the logs**:
   ```bash
   log stream --predicate 'eventMessage contains "DiskMonitor"' --level info
   ```

3. **Mount/unmount a dataset**:
   ```bash
   sudo zfs unmount mypool/dataset1
   # Check menu bar - should update immediately!

   sudo zfs mount mypool/dataset1
   # Check menu bar - should update again!
   ```

### Expected Log Output

```
DiskMonitor: Started monitoring volume events via NSWorkspace
DiskMonitor: Volume unmounted - /Volumes/enc1
MenuBarController: Disk event detected, refreshing pools
DiskMonitor: Volume mounted - /Volumes/enc1
MenuBarController: Disk event detected, refreshing pools
```

## Debugging

### Enable Verbose Logging

All DiskMonitor events are logged via `NSLog()`, which can be viewed with:

```bash
# Real-time log streaming
log stream --predicate 'eventMessage contains "DiskMonitor"' --level info

# Or include MenuBarController events
log stream --predicate 'eventMessage contains "DiskMonitor" OR eventMessage contains "MenuBarController"' --level info

# View last 5 minutes
log show --predicate 'eventMessage contains "DiskMonitor"' --last 5m --info
```

### Common Issues

**Menu bar not updating?**
1. Check if DiskMonitor started:
   ```bash
   log show --predicate 'eventMessage contains "Started monitoring"' --last 1m
   ```
2. Verify events are being received:
   ```bash
   log stream --predicate 'eventMessage contains "DiskMonitor"' --level info
   # Then mount/unmount something
   ```

**Too many updates?**
- If you have many external drives, you may see frequent updates
- The 0.5 second delay helps batch multiple events
- Consider increasing the delay if needed (in `DiskMonitor.swift:86`)

**Updates still slow?**
- Check if ZFS commands are slow:
  ```bash
  time sudo zpool list
  time sudo zfs list
  ```
- If slow, the 0.5 second delay may not be enough

## Performance Considerations

### Update Frequency
- Event-driven: Only updates when volumes change
- Typical scenarios:
  - Boot: 1-2 updates as pools import
  - USB drive plugged in: 1 update
  - Dataset mounted: 1 update
  - Idle: 0 updates (except 30-second timer)

### CPU Usage
- Monitoring itself: negligible (built into macOS)
- Per update: ~0.1-0.2 seconds (running `zpool list` and `zfs list`)
- Much lower than continuous polling

### Memory Usage
- DiskMonitor: ~1-2 KB (observer callbacks)
- Same as before (no significant increase)

## Future Enhancements

### Possible Improvements
1. **Selective monitoring**: Only trigger on ZFS-related events
   - Filter by volume path or filesystem type
   - Reduce unnecessary updates

2. **Debouncing**: Batch multiple rapid events
   - If 5 volumes mount in 2 seconds, only refresh once
   - Currently handled by 0.5s delay, but could be smarter

3. **Event details**: Show what changed in menu bar
   - "mypool/dataset1 mounted"
   - "backup/data unmounted"

4. **Notification support**: macOS user notifications
   - Optional: notify when critical datasets mount/unmount
   - Configurable in Preferences

## Related Files

- `ZFSAutoMount/DiskMonitor.swift` - Volume monitoring class
- `ZFSAutoMount/MenuBarController.swift` - Integration with menu bar
- `ZFSAutoMount/ZFSManager.swift` - Pool refresh logic
- `deploy-updated-app-with-diskmonitor.sh` - Deployment script

## Version History

- **2025-10-16**: Initial implementation using NSWorkspace notifications
- **Phase 1 Complete**: Real-time monitoring enabled by default

---

**Last Updated**: 2025-10-16
**Status**: ✅ Implemented and tested
