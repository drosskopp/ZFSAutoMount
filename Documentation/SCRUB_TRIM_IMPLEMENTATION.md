# Scrub & TRIM Implementation - Complete

## Overview

The ZFSAutoMount app now has full support for automated ZFS pool scrubbing and TRIM operations. This includes:
- Automatic SSD detection
- Scheduling UI with dropdown presets
- LaunchDaemon generation for automated runs
- Manual "Run Now" buttons
- Menu bar status display

## What Was Implemented

### 1. Disk Type Detection (DiskTypeDetector.swift)

**Purpose:** Automatically detect if pool disks are SSDs and determine TRIM eligibility.

**Features:**
- Detects disk protocol (NVMe, SATA, USB, Thunderbolt)
- Identifies SSDs vs HDDs using `diskutil`
- Determines TRIM support level:
  - ✅ **Supported** - All SSDs with native TRIM (NVMe, SATA)
  - ❌ **Not Supported** - HDDs or mixed pools
  - ⚠️ **Maybe Supported** - USB/Thunderbolt SSDs (needs user testing)

**Usage:**
```swift
let diskInfo = DiskTypeDetector.shared.getPoolDiskInfo("tank")
if diskInfo.trimSupport == .supported {
    // Pool is TRIM-eligible
}
```

### 2. Scrub/TRIM Status in Menu Bar

**Location:** `MenuBarController.swift` (lines 94-108)

**What It Shows:**
```
📦 tank
   ✅ Health: ONLINE
   💾 Used: 500G / 2T
   🔍 Last Scrub: Oct 16, 2025 - Clean
   ✂️ TRIM: Eligible

   Datasets:
   ✅ mypool/data 🔒
      → Mounted
```

- Scrub status shows for **all pools**
- TRIM status shows **only for SSD-eligible pools**

### 3. Maintenance Tab (PreferencesView.swift)

**Location:** New "Maintenance" tab in Preferences (lines 626-1134)

**Features:**

#### Scrub Schedule Section
- Toggle: Enable/disable automatic scrubbing
- Frequency dropdown: Weekly, Monthly, Quarterly
- Day picker: Sunday-Saturday
- Time picker: 00:00-23:00 (hourly intervals)
- Shows next scheduled run date

**Defaults:**
- Frequency: Monthly
- Day: Sunday
- Time: 02:00

#### TRIM Schedule Section
- Toggle: Enable/disable automatic TRIM
- Frequency dropdown: Daily, Weekly, Monthly
- Day picker: Sunday-Saturday (hidden for daily)
- Time picker: 00:00-23:00
- Shows next scheduled run date

**Defaults:**
- Frequency: Weekly
- Day: Sunday
- Time: 03:00

#### Pool Status Section
For each pool:
- Shows last scrub date and status
- Shows TRIM eligibility (for SSD pools only)
- "Run Now" buttons for manual execution
- Refresh button to update pool list

### 4. LaunchDaemon Generation

**Files Created:**
- `/Library/LaunchDaemons/org.openzfs.automount.scrub.plist`
- `/Library/LaunchDaemons/org.openzfs.automount.trim.plist`

**How It Works:**
1. User enables scheduling in Maintenance tab
2. App generates appropriate plist file
3. Uses AppleScript with admin privileges to install
4. LaunchDaemon calls app with `--run-scrub` or `--run-trim`

**Schedule Formats:**
- **Daily**: Runs every day at specified hour
- **Weekly**: Runs on specified day of week at specified hour
- **Monthly**: Runs on 1st of each month at specified hour
- **Quarterly**: Runs on 1st of Jan/Apr/Jul/Oct at specified hour

**Example Plist (Scrub, Monthly, Sunday, 2 AM):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>org.openzfs.automount.scrub</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount</string>
        <string>--run-scrub</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Day</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/var/log/zfs-scrub.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/zfs-scrub-error.log</string>
</dict>
</plist>
```

### 5. Command Handlers (ZFSAutoMountApp.swift)

**New CLI Flags:**
- `--run-scrub` - Scrub all pools
- `--run-trim` - TRIM all SSD-eligible pools

**How They Work:**

`--run-scrub`:
1. Refresh pool list
2. For each pool: `zpool scrub <pool>`
3. Log results to `/var/log/zfs-scrub.log`
4. Exit with status 0 (success) or 1 (failure)

`--run-trim`:
1. Refresh pool list
2. Filter to only SSD-eligible pools (trimEligible == true)
3. For each eligible pool: `zpool trim <pool>`
4. Log results to `/var/log/zfs-trim.log`
5. Exit with status 0 (success) or 1 (failure)

### 6. Privileged Helper Commands (HelperMain.swift)

**New Commands:**
- `scrub_pool:<poolName>` - Execute `zpool scrub <pool>`
- `trim_pool:<poolName>` - Execute `zpool trim <pool>`

**Implementation:**
```swift
private func scrubPool(poolName: String, reply: @escaping (String?, String?) -> Void) {
    NSLog("ZFSAutoMount Helper: Starting scrub on pool: \(poolName)")
    let result = runCommand(zpoolPath, args: ["scrub", poolName])
    if result.status == 0 {
        reply(result.output, nil)
    } else {
        reply(nil, result.error)
    }
}
```

## User Workflows

### Workflow 1: Enable Automatic Scrubbing

1. Open Preferences → Maintenance tab
2. Check "Enable automatic scrubbing"
3. Select frequency (e.g., "Monthly")
4. Select day (e.g., "Sunday")
5. Select time (e.g., "02:00")
6. Click away from dropdown (auto-saves)
7. Enter admin password when prompted
8. ✅ LaunchDaemon installed

**Result:** Pool will be scrubbed on 1st of each month at 2 AM

### Workflow 2: Enable Automatic TRIM

1. Open Preferences → Maintenance tab
2. Check "Enable automatic TRIM"
3. Select frequency (e.g., "Weekly")
4. Select day (e.g., "Sunday")
5. Select time (e.g., "03:00")
6. Enter admin password when prompted
7. ✅ LaunchDaemon installed

**Result:** SSD pools will be TRIMmed every Sunday at 3 AM

### Workflow 3: Manual Scrub

1. Open Preferences → Maintenance tab
2. Scroll to "Pool Status" section
3. Find the pool you want to scrub
4. Click "Run Now" button next to "🔍 Scrub:"
5. ✅ Scrub starts immediately

**Result:** Can check status in menu bar or with `zpool status <pool>`

### Workflow 4: Manual TRIM

1. Open Preferences → Maintenance tab
2. Scroll to "Pool Status" section
3. Find an SSD-eligible pool
4. Click "Run Now" button next to "✂️ TRIM:"
5. ✅ TRIM starts immediately

**Result:** Can check status with `zpool status -t <pool>`

### Workflow 5: Disable Scheduling

1. Open Preferences → Maintenance tab
2. Uncheck "Enable automatic scrubbing" or "Enable automatic TRIM"
3. Enter admin password when prompted
4. ✅ LaunchDaemon removed

## Logging

All operations are logged for troubleshooting:

**Scrub Logs:**
- `/var/log/zfs-scrub.log` - Standard output
- `/var/log/zfs-scrub-error.log` - Error output

**TRIM Logs:**
- `/var/log/zfs-trim.log` - Standard output
- `/var/log/zfs-trim-error.log` - Error output

**View Logs:**
```bash
# View scrub log
tail -f /var/log/zfs-scrub.log

# View TRIM log
tail -f /var/log/zfs-trim.log
```

## Technical Details

### ZFS Commands Used

**Scrub:**
```bash
zpool scrub <pool>
```
- Verifies all data integrity
- Repairs errors if possible
- Can run while pool is online
- Safe for production use

**TRIM:**
```bash
zpool trim <pool>
```
- Reclaims unused SSD blocks
- Improves SSD performance
- Only works on SSDs
- Safe for production use

**Status:**
```bash
# Check scrub status
zpool status <pool>

# Check TRIM status
zpool status -t <pool>
```

### Disk Detection Logic

**How it identifies SSDs:**
1. Run `zpool status <pool>` to get disk list
2. For each disk, run `diskutil info <disk>`
3. Check "Solid State:" field
4. Check "Protocol:" field (NVMe = always SSD)
5. Check "Media Name:" for "SSD" or "NVME"

**TRIM eligibility rules:**
- ✅ All disks are SSDs AND protocol is NVMe or SATA
- ⚠️ All disks are SSDs BUT protocol is USB or Thunderbolt
- ❌ Any disk is HDD OR mixed SSD/HDD

## Files Modified

1. **ZFSAutoMount/DiskTypeDetector.swift** (NEW)
   - Disk detection logic
   - TRIM eligibility determination

2. **ZFSAutoMount/ZFSManager.swift**
   - Added scrub/TRIM fields to ZFSPool struct
   - parseScrubStatus() method
   - getTRIMStatusLabel() method
   - Integration with DiskTypeDetector

3. **ZFSAutoMount/MenuBarController.swift**
   - Display scrub status in pool submenu
   - Display TRIM status for SSD pools

4. **ZFSAutoMount/PreferencesView.swift**
   - New MaintenanceTab struct
   - LaunchDaemon install/remove methods
   - Run Now button handlers
   - Schedule management

5. **ZFSAutoMount/ZFSAutoMountApp.swift**
   - handleRunScrub() command handler
   - handleRunTRIM() command handler
   - CLI argument parsing

6. **PrivilegedHelper/HelperMain.swift**
   - scrubPool() method
   - trimPool() method
   - Command routing

## Testing Checklist

### Manual Testing

- [ ] Enable scrub scheduling
  - [ ] Check LaunchDaemon created at `/Library/LaunchDaemons/org.openzfs.automount.scrub.plist`
  - [ ] Verify plist has correct schedule
  - [ ] Test `sudo launchctl list | grep scrub`

- [ ] Enable TRIM scheduling
  - [ ] Check LaunchDaemon created at `/Library/LaunchDaemons/org.openzfs.automount.trim.plist`
  - [ ] Verify plist has correct schedule
  - [ ] Test `sudo launchctl list | grep trim`

- [ ] Test manual scrub
  - [ ] Click "Run Now" for scrub
  - [ ] Verify `zpool status` shows scrub in progress
  - [ ] Wait for completion
  - [ ] Check menu bar updates with scrub status

- [ ] Test manual TRIM
  - [ ] Click "Run Now" for TRIM
  - [ ] Verify `zpool status -t` shows TRIM in progress
  - [ ] Wait for completion

- [ ] Test CLI handlers
  - [ ] Run `/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --run-scrub`
  - [ ] Check `/var/log/zfs-scrub.log`
  - [ ] Run `/Applications/ZFSAutoMount.app/Contents/MacOS/ZFSAutoMount --run-trim`
  - [ ] Check `/var/log/zfs-trim.log`

- [ ] Test disk detection
  - [ ] Verify SSD pools show TRIM status
  - [ ] Verify HDD pools don't show TRIM status
  - [ ] Check menu bar shows correct icons

### Edge Cases

- [ ] Cancel admin password during LaunchDaemon install (should revert toggle)
- [ ] Disable scheduling (should remove LaunchDaemon)
- [ ] Change schedule while enabled (should update LaunchDaemon)
- [ ] Pool with no disks
- [ ] Mixed SSD/HDD pool (should be ineligible for TRIM)
- [ ] USB SSD pool (should show "Maybe" status)

## Recommendations

### For Most Users

**Scrub:**
- Frequency: Monthly
- Day: First Sunday
- Time: 02:00 AM

**TRIM:**
- Frequency: Weekly
- Day: Sunday
- Time: 03:00 AM

### For Heavy Usage

**Scrub:**
- Frequency: Weekly
- Day: Sunday
- Time: 02:00 AM

**TRIM:**
- Frequency: Daily
- Time: 03:00 AM

### For Light Usage

**Scrub:**
- Frequency: Quarterly
- Day: First Sunday
- Time: 02:00 AM

**TRIM:**
- Frequency: Monthly
- Day: First Sunday
- Time: 03:00 AM

## Known Limitations

1. **Next run date calculation** - Currently shows "Not scheduled", needs implementation
2. **TRIM test functionality** - No "Test TRIM" button for USB/Thunderbolt SSDs yet
3. **Scrub progress** - No real-time progress indicator
4. **TRIM progress** - No real-time progress indicator
5. **History tracking** - No historical log of past scrubs/TRIMs

## Future Enhancements (Optional)

1. Calculate and display actual next run date
2. Add "Test TRIM" button for USB/Thunderbolt SSDs
3. Show scrub/TRIM progress percentage
4. Historical log viewer in UI
5. Notifications when scrub/TRIM completes
6. Email alerts on scrub errors
7. Per-pool schedule overrides
8. Scrub/TRIM health metrics dashboard

---

**Status:** ✅ Fully implemented and ready for testing
**Last Updated:** 2025-10-16
**Build Status:** ✅ Build succeeded
