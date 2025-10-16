import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem
    private var zfsManager: ZFSManager
    private var preferencesWindow: NSWindow?
    private var refreshTimer: Timer?

    init(zfsManager: ZFSManager) {
        self.zfsManager = zfsManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupMenuBar()

        // Observe pool changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBar),
            name: NSNotification.Name("ZFSPoolsDidChange"),
            object: nil
        )

        // Start periodic refresh timer (every 30 seconds)
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func startRefreshTimer() {
        // Refresh pool status every 30 seconds
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
                let poolMenu = NSMenuItem(title: pool.name, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                // Health status
                let healthItem = NSMenuItem(title: "Health: \(pool.health)", action: nil, keyEquivalent: "")
                healthItem.isEnabled = false
                submenu.addItem(healthItem)

                // Capacity
                let capacityItem = NSMenuItem(title: "Used: \(pool.used) / \(pool.capacity)", action: nil, keyEquivalent: "")
                capacityItem.isEnabled = false
                submenu.addItem(capacityItem)

                poolMenu.submenu = submenu
                menu.addItem(poolMenu)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Refresh pools
        let refreshItem = NSMenuItem(
            title: "Refresh Pools",
            action: #selector(refreshPools),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

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

    @objc private func refreshPools() {
        zfsManager.refreshPools()
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
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}
