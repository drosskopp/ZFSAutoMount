import Foundation
import AppKit

struct ZFSPool: Codable {
    let name: String
    let health: String
    let capacity: String
    let used: String
}

struct ZFSDataset: Codable {
    let name: String
    let mountpoint: String
    let mounted: Bool
    let encrypted: Bool
    let keyFormat: String?
    let keyLocation: String?
}

class ZFSManager {
    static let shared = ZFSManager()

    private var pools: [ZFSPool] = []
    private var datasets: [ZFSDataset] = []
    private let helperManager = PrivilegedHelperManager.shared
    private let keychainHelper = KeychainHelper.shared
    private let configParser = ConfigParser.shared

    // Paths to ZFS binaries
    private var zpoolPath: String = ""
    private var zfsPath: String = ""

    private init() {
        // Find ZFS binaries (check multiple common locations)
        zpoolPath = findZFSBinary(name: "zpool")
        zfsPath = findZFSBinary(name: "zfs")

        // Ensure default config exists
        configParser.writeDefaultConfig()
    }

    // MARK: - OpenZFS Detection

    private func findZFSBinary(name: String) -> String {
        let possiblePaths = [
            "/usr/local/zfs/bin/\(name)",      // OpenZFS on OS X default
            "/usr/local/bin/\(name)",           // Homebrew default
            "/opt/homebrew/bin/\(name)",        // Homebrew Apple Silicon
            "/usr/bin/\(name)"                  // System installation
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "/usr/local/zfs/bin/\(name)" // Default fallback
    }

    func isOpenZFSInstalled() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: zpoolPath) && fm.fileExists(atPath: zfsPath)
    }

    // MARK: - Pool Management

    func getPools() -> [ZFSPool] {
        return pools
    }

    func refreshPools() {
        pools = listPools()
        datasets = listDatasets()
        NotificationCenter.default.post(name: NSNotification.Name("ZFSPoolsDidChange"), object: nil)
    }

    private func listPools() -> [ZFSPool] {
        let output = runCommand(zpoolPath, args: ["list", "-H", "-o", "name,health,size,allocated"])

        var result: [ZFSPool] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "\t").map(String.init)
            if parts.count >= 4 {
                result.append(ZFSPool(
                    name: parts[0],
                    health: parts[1],
                    capacity: parts[2],
                    used: parts[3]
                ))
            }
        }
        return result
    }

    private func listDatasets() -> [ZFSDataset] {
        let output = runCommand(zfsPath, args: [
            "list", "-H", "-o", "name,mountpoint,mounted,encryption,keyformat,keylocation"
        ])

        var result: [ZFSDataset] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "\t").map(String.init)
            if parts.count >= 6 {
                result.append(ZFSDataset(
                    name: parts[0],
                    mountpoint: parts[1],
                    mounted: parts[2] == "yes",
                    encrypted: parts[3] != "off",
                    keyFormat: parts[4] != "-" ? parts[4] : nil,
                    keyLocation: parts[5] != "-" ? parts[5] : nil
                ))
            }
        }
        return result
    }

    // MARK: - Import Pools

    func importAllPools(completion: @escaping (Bool, String?) -> Void) {
        helperManager.executeCommand(command: "import_pools") { success, output, error in
            completion(success, error)
        }
    }

    // MARK: - Mount Management

    func mountAllDatasets(completion: @escaping (Bool, String?) -> Void) {
        // First, load keys for encrypted datasets
        loadKeysForEncryptedDatasets { keysLoaded, keyError in
            if !keysLoaded {
                completion(false, keyError)
                return
            }

            // Then mount all
            self.helperManager.executeCommand(command: "mount_all") { success, output, error in
                if success {
                    self.refreshPools()
                }
                completion(success, error)
            }
        }
    }

    // MARK: - Encryption Key Management

    private func loadKeysForEncryptedDatasets(completion: @escaping (Bool, String?) -> Void) {
        let encryptedDatasets = datasets.filter { $0.encrypted && !$0.mounted }

        if encryptedDatasets.isEmpty {
            completion(true, nil)
            return
        }

        var errors: [String] = []
        let group = DispatchGroup()

        for dataset in encryptedDatasets {
            group.enter()
            loadKeyForDataset(dataset) { success, error in
                if !success, let error = error {
                    errors.append("\(dataset.name): \(error)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(true, nil)
            } else {
                completion(false, "Failed to load keys:\n" + errors.joined(separator: "\n"))
            }
        }
    }

    private func loadKeyForDataset(_ dataset: ZFSDataset, completion: @escaping (Bool, String?) -> Void) {
        // First, check config file for keylocation
        if let config = configParser.getConfig(for: dataset.name),
           let keyLocation = config.options["keylocation"],
           keyLocation.hasPrefix("file://") {
            let keyPath = String(keyLocation.dropFirst(7)) // Remove "file://"
            if let keyContent = try? String(contentsOfFile: keyPath, encoding: .utf8) {
                helperManager.loadKey(for: dataset.name, key: keyContent, keyFormat: dataset.keyFormat ?? "raw") { success, error in
                    completion(success, error)
                }
                return
            }
        }

        // Try to get key from keychain
        if let key = keychainHelper.getKey(for: dataset.name) {
            helperManager.loadKey(for: dataset.name, key: key, keyFormat: dataset.keyFormat ?? "passphrase") { success, error in
                completion(success, error)
            }
        } else {
            // Prompt user for key
            DispatchQueue.main.async {
                self.promptForKey(dataset: dataset, completion: completion)
            }
        }
    }

    private func promptForKey(dataset: ZFSDataset, completion: @escaping (Bool, String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Encryption Key Required"
        alert.informativeText = "Enter the encryption key for dataset: \(dataset.name)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = "Enter passphrase or key"

        let checkbox = NSButton(checkboxWithTitle: "Save to Keychain", target: nil as AnyObject?, action: nil)
        checkbox.state = NSControl.StateValue.on

        let stackView = NSStackView(views: [inputTextField, checkbox])
        stackView.orientation = NSUserInterfaceLayoutOrientation.vertical
        stackView.spacing = 8
        alert.accessoryView = stackView

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let key = inputTextField.stringValue
            let saveToKeychain = checkbox.state == NSControl.StateValue.on

            if saveToKeychain {
                keychainHelper.saveKey(key, for: dataset.name)
            }

            helperManager.loadKey(for: dataset.name, key: key, keyFormat: dataset.keyFormat ?? "passphrase") { success, error in
                completion(success, error)
            }
        } else {
            completion(false, "User cancelled")
        }
    }

    // MARK: - Helper Methods

    private func runCommand(_ path: String, args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
