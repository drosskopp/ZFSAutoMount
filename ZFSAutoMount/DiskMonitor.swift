import Foundation
import AppKit

/// Monitors file system events in /Volumes to detect ZFS mount/unmount operations
/// Uses NSWorkspace notifications for real-time mount detection
class DiskMonitor {
    static let shared = DiskMonitor()

    private var isMonitoring = false
    private var observers: [NSObjectProtocol] = []

    // Callback for when disks change
    var onDiskChanged: (() -> Void)?

    private init() {}

    /// Start monitoring disk mount/unmount events
    func startMonitoring() {
        guard !isMonitoring else {
            print("DiskMonitor: Already monitoring")
            return
        }

        let workspace = NSWorkspace.shared
        print("DiskMonitor: Starting volume event monitoring...")

        // Monitor volume mount events
        let mountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let volumePath = notification.userInfo?["NSDevicePath"] as? String {
                print("DiskMonitor: Volume MOUNTED - \(volumePath)")
                self?.handleDiskEvent()
            } else {
                print("DiskMonitor: Volume MOUNTED (path unknown)")
                self?.handleDiskEvent()
            }
        }
        observers.append(mountObserver)

        // Monitor volume unmount events
        let unmountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let volumePath = notification.userInfo?["NSDevicePath"] as? String {
                print("DiskMonitor: Volume UNMOUNTED - \(volumePath)")
                self?.handleDiskEvent()
            } else {
                print("DiskMonitor: Volume UNMOUNTED (path unknown)")
                self?.handleDiskEvent()
            }
        }
        observers.append(unmountObserver)

        // Monitor volume rename events (rare but possible)
        let renameObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didRenameVolumeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("DiskMonitor: Volume RENAMED")
            self?.handleDiskEvent()
        }
        observers.append(renameObserver)

        isMonitoring = true
        print("DiskMonitor: ✅ Started monitoring volume events via NSWorkspace")
    }

    /// Stop monitoring disk events
    func stopMonitoring() {
        guard isMonitoring else { return }

        let workspace = NSWorkspace.shared
        for observer in observers {
            workspace.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()

        isMonitoring = false
        print("DiskMonitor: Stopped monitoring volume events")
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Private Helpers

    private func handleDiskEvent() {
        // Trigger callback after a short delay to give ZFS time to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onDiskChanged?()
        }
    }
}
