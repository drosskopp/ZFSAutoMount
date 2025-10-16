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

        print("ZFS AutoMount: Starting boot-time import and mount...")

        // Import all pools
        manager.importAllPools { success, error in
            if success {
                print("ZFS AutoMount: Pools imported successfully")
            } else {
                print("ZFS AutoMount: Error importing pools: \(error ?? "unknown")")
            }

            // Mount all datasets
            manager.mountAllDatasets { success, error in
                if success {
                    print("ZFS AutoMount: All datasets mounted successfully")
                } else {
                    print("ZFS AutoMount: Error mounting datasets: \(error ?? "unknown")")
                }

                exit(success ? 0 : 1)
            }
        }

        // Wait for async operations
        RunLoop.main.run()
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
