#!/bin/bash
# Cleanup conflicting ZFS auto-import services
# Run this ON the Mac mini

echo "🧹 ZFS Services Cleanup"
echo "This will disable conflicting auto-import services"
echo ""

# Show current state
echo "📋 Currently running ZFS services:"
sudo launchctl list | grep openzfs
echo ""

read -p "Continue with cleanup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🛑 Unloading conflicting services..."
echo ""

# OpenZFS bundled auto-import services (conflict with our app)
echo "Disabling OpenZFS bundled auto-import..."
sudo launchctl unload /Library/LaunchDaemons/org.openzfsonosx.zpool-import.plist 2>/dev/null && echo "  ✅ org.openzfsonosx.zpool-import" || echo "  ℹ️  org.openzfsonosx.zpool-import (not found)"
sudo launchctl unload /Library/LaunchDaemons/org.openzfsonosx.zpool-import-all.plist 2>/dev/null && echo "  ✅ org.openzfsonosx.zpool-import-all" || echo "  ℹ️  org.openzfsonosx.zpool-import-all (not found)"

# zfs-pool-importer from GitHub (if installed)
echo ""
echo "Disabling zfs-pool-importer (GitHub)..."
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.zfs-import-pools.plist 2>/dev/null && echo "  ✅ org.openzfs.zfs-import-pools" || echo "  ℹ️  org.openzfs.zfs-import-pools (not found)"
sudo launchctl unload /Library/LaunchDaemons/org.openzfs.zfs-maintenance.plist 2>/dev/null && echo "  ✅ org.openzfs.zfs-maintenance" || echo "  ℹ️  org.openzfs.zfs-maintenance (not found)"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 Remaining ZFS services (these are good):"
sudo launchctl list | grep openzfs
echo ""
echo "✔️  Core OpenZFS services (keep these running):"
echo "   - org.openzfsonosx.zed              (ZFS Event Daemon)"
echo "   - org.openzfsonosx.zconfigd         (ZFS Configuration)"
echo "   - org.openzfsonosx.InvariantDisks   (Disk Management)"
echo ""
echo "🎯 Our service (after installation):"
echo "   - org.openzfs.automount.helper      (Our privileged helper)"
echo ""
echo "Next steps:"
echo "  1. Install our helper: ./INSTALL_HELPER_ON_MINI.sh"
echo "  2. Launch the app: open /Applications/ZFSAutoMount.app"
echo "  3. Test mounting: Click 'Mount All Datasets'"
