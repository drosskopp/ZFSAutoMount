#!/bin/bash

# Comprehensive status check for ZFSAutoMount
# Shows helper, scrub/TRIM schedules, and recent activity

echo "=================================================="
echo "ZFSAutoMount Complete Status Check"
echo "=================================================="
echo ""

# 1. Helper Status
echo "1. Privileged Helper"
echo "===================="
if [ -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper ]; then
    echo "✅ Helper installed"
    sudo ls -lh /Library/PrivilegedHelperTools/org.openzfs.automount.helper
    echo ""
    echo "Helper loaded in launchd:"
    sudo launchctl list | grep openzfs || echo "  ⚠️  Not loaded"
else
    echo "❌ Helper NOT installed"
fi
echo ""

# 2. Boot Automation Daemon
echo "2. Boot Automation"
echo "=================="
if [ -f /Library/LaunchDaemons/org.openzfs.automount.daemon.plist ]; then
    echo "✅ Boot daemon installed"
    ls -lh /Library/LaunchDaemons/org.openzfs.automount.daemon.plist
    echo ""
    echo "Daemon loaded:"
    sudo launchctl list | grep automount.daemon || echo "  ⚠️  Not loaded"
else
    echo "❌ Boot daemon NOT installed"
fi
echo ""

# 3. Scrub Scheduler
echo "3. Scrub Scheduler"
echo "=================="
if [ -f /Library/LaunchDaemons/org.openzfs.automount.scrub.plist ]; then
    echo "✅ Scrub scheduler installed"
    ls -lh /Library/LaunchDaemons/org.openzfs.automount.scrub.plist
    echo ""
    echo "Schedule:"
    grep -A 10 "StartCalendarInterval" /Library/LaunchDaemons/org.openzfs.automount.scrub.plist | grep -E "(Day|Month|Weekday|Hour|Minute)" | sed 's/^/  /'
    echo ""
    echo "Loaded in launchd:"
    sudo launchctl list | grep scrub || echo "  ⚠️  Not loaded"
else
    echo "❌ Scrub scheduler NOT installed"
    echo "   Enable in: Preferences → Maintenance → Enable automatic scrubbing"
fi
echo ""

# 4. TRIM Scheduler
echo "4. TRIM Scheduler"
echo "================="
if [ -f /Library/LaunchDaemons/org.openzfs.automount.trim.plist ]; then
    echo "✅ TRIM scheduler installed"
    ls -lh /Library/LaunchDaemons/org.openzfs.automount.trim.plist
    echo ""
    echo "Schedule:"
    grep -A 10 "StartCalendarInterval" /Library/LaunchDaemons/org.openzfs.automount.trim.plist | grep -E "(Day|Month|Weekday|Hour|Minute)" | sed 's/^/  /'
    echo ""
    echo "Loaded in launchd:"
    sudo launchctl list | grep trim || echo "  ⚠️  Not loaded"
else
    echo "❌ TRIM scheduler NOT installed"
    echo "   Enable in: Preferences → Maintenance → Enable automatic TRIM"
fi
echo ""

# 5. Recent Scrub Activity
echo "5. Recent Scrub Activity"
echo "========================"
if [ -f /var/log/zfs-scrub.log ]; then
    echo "Last 10 lines from scrub log:"
    tail -10 /var/log/zfs-scrub.log | sed 's/^/  /'
else
    echo "No scrub log found"
    echo "  (Log will be created on first scheduled scrub)"
fi
echo ""

# 6. Recent TRIM Activity
echo "6. Recent TRIM Activity"
echo "======================="
if [ -f /var/log/zfs-trim.log ]; then
    echo "Last 10 lines from TRIM log:"
    tail -10 /var/log/zfs-trim.log | sed 's/^/  /'
else
    echo "No TRIM log found"
    echo "  (Log will be created on first scheduled TRIM)"
fi
echo ""

# 7. Helper Logs
echo "7. Helper Logs (Last 10 Lines)"
echo "==============================="
if [ -f /var/log/org.openzfs.automount.helper.log ]; then
    sudo tail -10 /var/log/org.openzfs.automount.helper.log | sed 's/^/  /'
else
    echo "No helper log found"
fi
echo ""

# 8. Current Pool Status
echo "8. Current Pool Status"
echo "======================"
echo "Checking all pools for recent scrub activity..."
echo ""

# Use the ZFS binaries
ZPOOL=""
for path in /usr/local/zfs/bin/zpool /opt/homebrew/bin/zpool /usr/local/bin/zpool; do
    if [ -x "$path" ]; then
        ZPOOL="$path"
        break
    fi
done

if [ -n "$ZPOOL" ]; then
    POOLS=$(sudo $ZPOOL list -H -o name)

    for pool in $POOLS; do
        echo "📦 $pool"
        echo "   Scrub status:"
        sudo $ZPOOL status "$pool" | grep -E "(scan:|scrub:)" | sed 's/^/     /'

        # Check for TRIM status
        TRIM_STATUS=$(sudo $ZPOOL status -t "$pool" 2>/dev/null | grep -i trim || echo "")
        if [ -n "$TRIM_STATUS" ]; then
            echo "   TRIM status:"
            echo "$TRIM_STATUS" | sed 's/^/     /'
        fi
        echo ""
    done
else
    echo "⚠️  zpool command not found"
fi

echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""

# Quick summary
HELPER_OK=false
SCRUB_ENABLED=false
TRIM_ENABLED=false

[ -f /Library/PrivilegedHelperTools/org.openzfs.automount.helper ] && HELPER_OK=true
[ -f /Library/LaunchDaemons/org.openzfs.automount.scrub.plist ] && SCRUB_ENABLED=true
[ -f /Library/LaunchDaemons/org.openzfs.automount.trim.plist ] && TRIM_ENABLED=true

if $HELPER_OK; then
    echo "✅ Privileged helper is running"
else
    echo "❌ Privileged helper NOT installed"
fi

if $SCRUB_ENABLED; then
    echo "✅ Automatic scrubbing is enabled"
else
    echo "⚠️  Automatic scrubbing is NOT enabled"
fi

if $TRIM_ENABLED; then
    echo "✅ Automatic TRIM is enabled"
else
    echo "⚠️  Automatic TRIM is NOT enabled"
fi

echo ""
echo "To enable scheduling:"
echo "  Open ZFSAutoMount → Preferences → Maintenance"
echo ""
