# Scrub & TRIM Scheduling - Design Document

## Overview

Automated scheduling for ZFS pool maintenance:
- **Scrub** - Data integrity verification (all pools)
- **TRIM** - SSD optimization (SSD-based pools only)

## Disk Type Detection

### How to Detect SSDs on macOS

```bash
# Method 1: diskutil info
diskutil info disk0 | grep "Solid State"
# Output: "Solid State: Yes" or "Solid State: No"

# Method 2: system_profiler (more detailed)
system_profiler SPNVMeDataType SPSerialATADataType SPUSBDataType SPThunderboltDataType

# Method 3: Check protocol
diskutil info disk0 | grep "Protocol"
# Protocols that might be SSD:
# - NVMe
# - SATA (could be SSD or HDD)
# - USB (need to check if SSD)
# - Thunderbolt (need to check if SSD)
```

### Detection Strategy

For each disk in a ZFS pool:
1. **Check "Solid State" flag** - Direct indication
2. **Check Protocol**:
   - `NVMe` → SSD (definitely)
   - `SATA` → Check "Solid State" flag
   - `USB` → Check "Solid State" flag + "Media Name"
   - `Thunderbolt` → Check "Solid State" flag
3. **Check Media Name** - Contains "SSD" or "NVME"

### TRIM Eligibility

A pool is TRIM-eligible if:
- **All vdevs are SSDs** (no mixing with HDDs in same vdev)
- **Protocol supports TRIM**:
  - ✅ NVMe (native TRIM)
  - ✅ SATA SSD (TRIM via ATA)
  - ⚠️ USB SSD (depends on controller)
  - ⚠️ Thunderbolt SSD (usually works)

**User Decision:**
- App detects and suggests
- User can override (enable/disable TRIM per pool)
- Warning if USB/Thunderbolt without testing

## UI Design

### Maintenance Tab (New)

```
╔═══════════════════════════════════════════════════════════╗
║ Maintenance                                               ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║ ┌─────────────────────────────────────────────────────┐ ║
║ │ Scrub Schedule                                      │ ║
║ │                                                     │ ║
║ │ [✓] Enable automatic scrubbing                     │ ║
║ │                                                     │ ║
║ │ Frequency: [Monthly ▾]                             │ ║
║ │            Options: Weekly, Monthly, Quarterly     │ ║
║ │                                                     │ ║
║ │ Run on:    [First Sunday ▾]                        │ ║
║ │            Options: First/Second/Third/Last        │ ║
║ │                     Day of week selector           │ ║
║ │                                                     │ ║
║ │ Time:      [02:00 AM ▾]                            │ ║
║ │                                                     │ ║
║ │ Next scrub: Sunday, Nov 3, 2025 at 2:00 AM        │ ║
║ └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║ ┌─────────────────────────────────────────────────────┐ ║
║ │ TRIM Schedule                                       │ ║
║ │                                                     │ ║
║ │ [✓] Enable automatic TRIM                          │ ║
║ │                                                     │ ║
║ │ Frequency: [Weekly ▾]                              │ ║
║ │            Options: Daily, Weekly, Monthly         │ ║
║ │                                                     │ ║
║ │ Run on:    [Every Sunday ▾]                        │ ║
║ │                                                     │ ║
║ │ Time:      [03:00 AM ▾]                            │ ║
║ │                                                     │ ║
║ │ Next TRIM: Sunday, Oct 20, 2025 at 3:00 AM        │ ║
║ └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║ ┌─────────────────────────────────────────────────────┐ ║
║ │ Pool Status                                         │ ║
║ │                                                     │ ║
║ │ 📦 tank                                             │ ║
║ │    ├─ Scrub: ✅ Eligible (recommended)             │ ║
║ │    │  Last: Oct 1, 2025  Status: Clean             │ ║
║ │    │  [Run Scrub Now]                              │ ║
║ │    │                                                │ ║
║ │    └─ TRIM:  ✅ Eligible (all SSDs)                │ ║
║ │       Disks: 2x NVMe SSD                           │ ║
║ │       [Run TRIM Now]  [Disable for this pool]     │ ║
║ │                                                     │ ║
║ │ 📦 backup                                           │ ║
║ │    ├─ Scrub: ✅ Eligible (recommended)             │ ║
║ │    │  Last: Never  Status: N/A                     │ ║
║ │    │  [Run Scrub Now]                              │ ║
║ │    │                                                │ ║
║ │    └─ TRIM:  ❌ Not eligible (HDDs detected)       │ ║
║ │       Disks: 2x SATA HDD                           │ ║
║ │                                                     │ ║
║ │ 📦 media                                            │ ║
║ │    ├─ Scrub: ✅ Eligible (recommended)             │ ║
║ │    │  Last: Oct 5, 2025  Status: Clean             │ ║
║ │    │  [Run Scrub Now]                              │ ║
║ │    │                                                │ ║
║ │    └─ TRIM:  ⚠️ Maybe (USB SSD - test first)       │ ║
║ │       Disks: 1x USB SSD (Samsung T7)               │ ║
║ │       [Test TRIM]  [Enable]  [Disable]            │ ║
║ └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║ ┌─────────────────────────────────────────────────────┐ ║
║ │ History                                             │ ║
║ │ [View Scrub History]  [View TRIM History]          │ ║
║ └─────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════╝
```

## Scheduling System

### Option 1: launchd (Native macOS)

**Advantages:**
- ✅ Native to macOS
- ✅ System-level scheduling
- ✅ Runs even when user not logged in
- ✅ Power-aware (won't wake computer)
- ✅ Can queue if missed

**Implementation:**
```xml
<!-- /Library/LaunchDaemons/org.openzfs.automount.scrub.plist -->
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
        <key>Weekday</key>
        <integer>0</integer>  <!-- Sunday -->
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
```

### Option 2: Custom Scheduler (Overkill)

Create our own scheduling daemon - **NOT RECOMMENDED** (launchd is better)

### Recommended: launchd

Two separate LaunchDaemons:
1. `org.openzfs.automount.scrub.plist` - Scrub schedule
2. `org.openzfs.automount.trim.plist` - TRIM schedule

## User Interface Design

### Preset Schedules (Dropdowns)

**Scrub Frequency:**
```
Weekly         → Every Sunday at 2 AM
Monthly        → First Sunday of month at 2 AM (DEFAULT)
Quarterly      → First Sunday of Jan/Apr/Jul/Oct at 2 AM
Custom         → User picks day/time
```

**TRIM Frequency:**
```
Daily          → Every day at 3 AM
Weekly         → Every Sunday at 3 AM (DEFAULT)
Monthly        → First Sunday of month at 3 AM
Custom         → User picks day/time
```

**Time Picker:**
```
[02:00 AM ▾]
Options: 00:00 AM - 11:59 PM (30-min intervals)
```

**Day Picker (for weekly/monthly):**
```
For Weekly:
  [Every Sunday ▾]
  Options: Every [Mon/Tue/Wed/Thu/Fri/Sat/Sun]

For Monthly:
  [First Sunday ▾]
  Options: [First/Second/Third/Last] [Day of week]
```

### Per-Pool Settings

Each pool shows:
```
📦 pool-name
   ├─ Scrub: [Status badge] [Run Now button]
   │  Last run: Date/Never
   │  Status: Clean / Errors found / In progress
   │
   └─ TRIM: [Status badge] [Override buttons]
      Detection: Auto/Manual
      Status: Enabled/Disabled/Not eligible
```

**TRIM Status Badges:**
```
✅ Eligible        - All SSDs detected, TRIM recommended
❌ Not eligible    - HDDs or mixed, TRIM disabled
⚠️ Maybe eligible  - USB/Thunderbolt SSD (needs testing)
🔧 Manual override - User forced enable/disable
```

## Implementation Plan

### 1. DiskTypeDetector Class

```swift
class DiskTypeDetector {
    func getPoolDiskInfo(_ poolName: String) -> PoolDiskInfo
    func isSSD(_ diskPath: String) -> Bool
    func getProtocol(_ diskPath: String) -> DiskProtocol
    func isTRIMSupported(_ poolName: String) -> TRIMSupport
}

enum TRIMSupport {
    case supported      // All SSDs, native support
    case notSupported   // HDDs or no TRIM
    case maybeSupported // USB/TB, needs user confirmation
}

struct PoolDiskInfo {
    let poolName: String
    let disks: [DiskInfo]
    let allSSDs: Bool
    let trimSupport: TRIMSupport
}

struct DiskInfo {
    let path: String
    let isSSD: Bool
    let protocol: DiskProtocol
    let model: String
}

enum DiskProtocol {
    case nvme
    case sata
    case usb
    case thunderbolt
    case unknown
}
```

### 2. MaintenanceScheduler Class

```swift
class MaintenanceScheduler {
    func createScrubSchedule(frequency: Frequency, time: Time)
    func createTRIMSchedule(frequency: Frequency, time: Time)
    func removeScrubSchedule()
    func removeTRIMSchedule()
    func getNextRunDate(schedule: Schedule) -> Date
}

struct Schedule {
    let frequency: Frequency
    let dayOfWeek: Int?
    let weekOfMonth: Int?
    let hour: Int
    let minute: Int
}

enum Frequency {
    case daily
    case weekly
    case monthly
    case quarterly
    case custom
}
```

### 3. MaintenanceTab View

```swift
struct MaintenanceTab: View {
    @State private var scrubEnabled: Bool
    @State private var trimEnabled: Bool
    @State private var scrubSchedule: Schedule
    @State private var trimSchedule: Schedule
    @State private var poolInfo: [PoolDiskInfo]

    var body: some View {
        // Scrub section
        // TRIM section
        // Pool status section
        // History section
    }
}
```

### 4. Command-Line Handlers

Add to `ZFSAutoMountApp.swift`:

```swift
func handleRunScrub() {
    // Read list of enabled pools from config
    // Run: zpool scrub pool-name
    // Log results
}

func handleRunTRIM() {
    // Read list of TRIM-enabled pools
    // Run: zpool trim pool-name
    // Log results
}
```

## Disk Detection Implementation

```bash
# Get all disks in a pool
zpool status tank | grep -E "^\s+(sd|disk)" | awk '{print $1}'

# For each disk, check if SSD
diskutil info /dev/disk2 | grep -E "(Solid State|Protocol|Media Name)"

# Example output:
#   Solid State: Yes
#   Protocol: NVMe
#   Media Name: APPLE SSD AP0512N Media
```

## Configuration Storage

Store in UserDefaults:
```swift
// Scrub settings
scrubEnabled: Bool
scrubFrequency: String ("weekly", "monthly", "quarterly")
scrubDayOfWeek: Int (0-6, 0=Sunday)
scrubWeekOfMonth: Int (1-4, or -1 for last)
scrubHour: Int (0-23)
scrubMinute: Int (0, 30)

// TRIM settings
trimEnabled: Bool
trimFrequency: String ("daily", "weekly", "monthly")
trimDayOfWeek: Int?
trimHour: Int
trimMinute: Int

// Per-pool overrides
trimOverrides: [String: Bool] // pool-name: enabled/disabled
```

## Testing Plan

### Test Disk Detection

```bash
# Test script to verify detection
for disk in disk0 disk1 disk2; do
    echo "=== $disk ==="
    diskutil info /dev/$disk | grep -E "(Solid State|Protocol|Media Name)"
done
```

### Test TRIM

```bash
# Test if TRIM is supported (safe, read-only)
zpool status tank | grep -i trim

# Test TRIM on small pool (safe)
zpool trim tank

# Check TRIM status
zpool status -t tank
```

### Test Scrub

```bash
# Start scrub (safe, read-only verification)
zpool scrub tank

# Check status
zpool status tank | grep scan

# Stop scrub (if needed)
zpool scrub -s tank
```

## Pros/Cons of UI Approaches

### Approach 1: Dropdown Presets (RECOMMENDED)

**Pros:**
- ✅ User-friendly
- ✅ No crontab knowledge needed
- ✅ Clear "Next run" display
- ✅ Prevents invalid schedules

**Cons:**
- ❌ Less flexible than raw crontab
- ❌ Limited to preset options

### Approach 2: Raw Crontab Input

**Pros:**
- ✅ Maximum flexibility
- ✅ Power users can set complex schedules

**Cons:**
- ❌ Confusing for most users
- ❌ Easy to make syntax errors
- ❌ launchd doesn't use cron syntax (different format)
- ❌ Harder to show "Next run" date

### Approach 3: Hybrid (Good Compromise)

**Implementation:**
- Default: Dropdown presets
- Advanced: "Custom" option → Show detailed time picker
- Never show raw cron/launchd syntax

## Recommendations

### For Scrub:
- **Default:** Monthly, first Sunday, 2 AM
- **Rationale:**
  - Not too frequent (network impact)
  - Not too rare (catch issues early)
  - Weekend night (less likely to interrupt)

### For TRIM:
- **Default:** Weekly, Sunday, 3 AM
- **Rationale:**
  - More frequent than scrub (SSDs benefit from regular TRIM)
  - Still infrequent enough to not cause wear
  - After scrub completes

### For USB/Thunderbolt SSDs:
- **Default:** Disabled with warning
- **Recommendation:** Show "Test TRIM" button
- **Test Process:**
  1. User clicks "Test TRIM"
  2. App runs: `zpool trim pool-name`
  3. Monitors for errors
  4. Reports success/failure
  5. User decides to enable permanently

## Warnings to Show

### TRIM on USB SSD:
```
⚠️ TRIM on USB SSDs may not work reliably
The USB controller may not pass TRIM commands to the drive.

Options:
• Test TRIM first (recommended)
• Enable anyway (not recommended)
• Leave disabled (safest)
```

### Scrub During Active Use:
```
ℹ️ Scrub can impact performance
Consider running during low-usage times (nights/weekends).

Current schedule: [Show schedule]
[Change Schedule]
```

---

**Next Steps:**
1. ✅ Review this design
2. ⏳ Implement DiskTypeDetector
3. ⏳ Implement MaintenanceTab UI
4. ⏳ Create LaunchDaemon templates
5. ⏳ Add --run-scrub and --run-trim handlers
6. ⏳ Test on real hardware

**Estimated Implementation Time:** 4-6 hours

**Should I proceed with implementation?**
