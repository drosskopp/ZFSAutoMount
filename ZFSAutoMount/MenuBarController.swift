import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem
    private var zfsManager: ZFSManager
    private var preferencesWindow: NSWindow?
    private var refreshTimer: Timer?
    private var diskMonitor: DiskMonitor

    init(zfsManager: ZFSManager) {
        self.zfsManager = zfsManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.diskMonitor = DiskMonitor.shared

        setupMenuBar()

        // Observe pool changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBar),
            name: NSNotification.Name("ZFSPoolsDidChange"),
            object: nil
        )

        // Start real-time disk monitoring
        startDiskMonitoring()

        // Start periodic refresh timer (every 30 seconds as backup)
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        diskMonitor.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }

    private func startDiskMonitoring() {
        // Set up callback for real-time disk events
        diskMonitor.onDiskChanged = { [weak self] in
            print("MenuBarController: 🔄 Disk event detected, refreshing pools")
            self?.zfsManager.refreshPools()
        }

        // Start monitoring
        print("MenuBarController: Initializing disk monitoring...")
        diskMonitor.startMonitoring()
    }

    private func startRefreshTimer() {
        // Refresh pool status every 30 seconds as backup
        // (in case disk events are missed)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.zfsManager.refreshPools()
        }
    }

    private func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: "ZFS Pools")
            button.image?.isTemplate = true
        }

        updateMenuBar()
    }

    @objc private func updateMenuBar() {
        let menu = NSMenu()

        let pools = zfsManager.getPools()

        if pools.isEmpty {
            let item = NSMenuItem(title: "No ZFS Pools Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Add pool status items
            for pool in pools {
                let poolMenu = NSMenuItem(title: "📦 \(pool.name)", action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                // Health status with icon
                let healthIcon = pool.health == "ONLINE" ? "✅" : "⚠️"
                let healthItem = NSMenuItem(title: "\(healthIcon) Health: \(pool.health)", action: nil, keyEquivalent: "")
                healthItem.isEnabled = false
                submenu.addItem(healthItem)

                // Capacity
                let capacityItem = NSMenuItem(title: "💾 Used: \(pool.used) / \(pool.capacity)", action: nil, keyEquivalent: "")
                capacityItem.isEnabled = false
                submenu.addItem(capacityItem)

                // Scrub status
                if let lastScrub = pool.lastScrub, let scrubStatus = pool.scrubStatus {
                    let scrubItem = NSMenuItem(title: "🔍 Last Scrub: \(lastScrub) - \(scrubStatus)", action: nil, keyEquivalent: "")
                    scrubItem.isEnabled = false
                    submenu.addItem(scrubItem)
                }

                // TRIM status (only for SSD pools)
                if let trimEligible = pool.trimEligible, trimEligible {
                    if let trimStatus = pool.trimStatus {
                        let trimItem = NSMenuItem(title: "✂️ TRIM: \(trimStatus)", action: nil, keyEquivalent: "")
                        trimItem.isEnabled = false
                        submenu.addItem(trimItem)
                    }
                }

                // Get datasets for this pool
                let datasets = zfsManager.getDatasets(forPool: pool.name)

                if !datasets.isEmpty {
                    submenu.addItem(NSMenuItem.separator())

                    // Datasets header
                    let datasetsHeader = NSMenuItem(title: "Datasets:", action: nil, keyEquivalent: "")
                    datasetsHeader.isEnabled = false
                    submenu.addItem(datasetsHeader)

                    // List each dataset with status
                    for dataset in datasets {
                        let shortName = dataset.name.replacingOccurrences(of: "\(pool.name)/", with: "  ")
                        let mountIcon = dataset.mounted ? "✅" : "⭕️"
                        let encryptIcon = dataset.encrypted ? "🔒" : ""

                        let statusText: String
                        if dataset.mounted {
                            statusText = "Mounted"
                        } else {
                            statusText = "Not Mounted"
                        }

                        let datasetItem = NSMenuItem(
                            title: "\(mountIcon) \(shortName) \(encryptIcon)",
                            action: nil,
                            keyEquivalent: ""
                        )
                        datasetItem.isEnabled = false
                        submenu.addItem(datasetItem)

                        // Add indented status line
                        let statusItem = NSMenuItem(
                            title: "    → \(statusText)",
                            action: nil,
                            keyEquivalent: ""
                        )
                        statusItem.isEnabled = false
                        submenu.addItem(statusItem)
                    }
                }

                poolMenu.submenu = submenu
                menu.addItem(poolMenu)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Mount all
        let mountItem = NSMenuItem(
            title: "Mount All Datasets",
            action: #selector(mountAllDatasets),
            keyEquivalent: "m"
        )
        mountItem.target = self
        menu.addItem(mountItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit ZFSAutoMount",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func mountAllDatasets() {
        zfsManager.mountAllDatasets { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showNotification(title: "Success", message: "All datasets mounted successfully")
                } else {
                    self.showAlert(title: "Mount Failed", message: error ?? "Unknown error")
                }
            }
        }
    }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)

        // Try to use the Settings scene first
        if NSApp.responds(to: Selector(("showSettingsWindow:"))) {
            NSApp.perform(Selector(("showSettingsWindow:")), with: nil)
            return
        }

        // Fallback: Create window manually if Settings scene doesn't work
        if preferencesWindow == nil {
            let contentView = PreferencesView()
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "ZFSAutoMount Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()

            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showNotification(title: String, message: String) {
        // Check if notifications are enabled
        let showNotifications = UserDefaults.standard.bool(forKey: "showNotifications")
        guard showNotifications else {
            print("Notifications disabled, skipping: \(title)")
            return
        }

        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
