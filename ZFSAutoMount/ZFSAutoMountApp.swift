import SwiftUI

@main
struct ZFSAutoMountApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var zfsManager: ZFSManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for boot-mount CLI argument
        let args = CommandLine.arguments
        if args.contains("--boot-mount") {
            handleBootMount()
            NSApp.terminate(nil)
            return
        }

        // Hide dock icon - this is a menu bar app
        NSApp.setActivationPolicy(.accessory)

        // Initialize ZFS manager
        zfsManager = ZFSManager.shared

        // Check if OpenZFS is installed
        if !zfsManager!.isOpenZFSInstalled() {
            showOpenZFSNotInstalledAlert()
        }

        // Set up menu bar
        menuBarController = MenuBarController(zfsManager: zfsManager!)

        // Initial pool scan
        zfsManager?.refreshPools()
    }

    private func handleBootMount() {
        let manager = ZFSManager.shared

        logBoot("Starting boot-time import and mount")

        // Wait for disk subsystem to be ready
        waitForDiskSubsystem()

        // Import all pools
        manager.importAllPools { success, error in
            if success {
                self.logBoot("Pools imported successfully")
            } else {
                self.logBoot("Error importing pools: \(error ?? "unknown")")
            }

            // Mount all datasets
            manager.mountAllDatasets { success, error in
                if success {
                    self.logBoot("All datasets mounted successfully")
                    self.updateBootCookie()
                } else {
                    self.logBoot("Error mounting datasets: \(error ?? "unknown")")
                }

                exit(success ? 0 : 1)
            }
        }

        // Wait for async operations
        RunLoop.main.run()
    }

    private func waitForDiskSubsystem() {
        logBoot("Waiting for disk subsystem to be ready")

        // 1. Force device tree population via system_profiler
        logBoot("Running system_profiler to populate device tree")
        let profilerTask = Process()
        profilerTask.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        profilerTask.arguments = [
            "SPStorageDataType",
            "SPUSBDataType",
            "SPThunderboltDataType",
            "SPSerialATADataType",
            "SPPCIDataType"
        ]
        profilerTask.standardOutput = FileHandle.nullDevice
        profilerTask.standardError = FileHandle.nullDevice

        do {
            try profilerTask.run()
            profilerTask.waitUntilExit()
        } catch {
            logBoot("Warning: system_profiler failed: \(error.localizedDescription)")
        }

        // 2. Sync filesystems
        let syncTask = Process()
        syncTask.executableURL = URL(fileURLWithPath: "/bin/sync")
        try? syncTask.run()
        syncTask.waitUntilExit()

        // 3. Wait for InvariantDisks daemon (up to 60 seconds)
        let invariantFile = "/var/run/disk/invariant.idle"
        let timeout: TimeInterval = 60
        let startTime = Date()

        logBoot("Waiting for \(invariantFile) (timeout: \(Int(timeout))s)")

        while !FileManager.default.fileExists(atPath: invariantFile) {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= timeout {
                logBoot("Warning: \(invariantFile) not found after \(Int(timeout))s")
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        if FileManager.default.fileExists(atPath: invariantFile) {
            logBoot("Found \(invariantFile) after \(String(format: "%.2f", elapsed))s")
        }

        // 4. Additional safety buffer (5s instead of 10s - we're faster than shell scripts)
        logBoot("Waiting additional 5 seconds for stability")
        Thread.sleep(forTimeInterval: 5.0)

        logBoot("Disk subsystem ready - proceeding with pool import")
    }

    private func logBoot(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] ZFS AutoMount: \(message)")
    }

    private func updateBootCookie() {
        let cookiePath = "/var/run/org.openzfs.automount.didRun"
        let now = Date()
        let attrs = [FileAttributeKey.modificationDate: now]

        if FileManager.default.fileExists(atPath: cookiePath) {
            try? FileManager.default.setAttributes(attrs, ofItemAtPath: cookiePath)
            logBoot("Updated boot cookie: \(cookiePath)")
        } else {
            if FileManager.default.createFile(atPath: cookiePath, contents: nil, attributes: attrs) {
                logBoot("Created boot cookie: \(cookiePath)")
            }
        }
    }

    private func showOpenZFSNotInstalledAlert() {
        let alert = NSAlert()
        alert.messageText = "OpenZFS Not Found"
        alert.informativeText = """
        OpenZFS is not installed on your system.

        To install OpenZFS via Homebrew, run:

        brew install openzfs

        Then restart this application.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
