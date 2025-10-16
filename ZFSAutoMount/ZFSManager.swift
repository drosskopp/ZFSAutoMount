import Foundation
import AppKit

struct ZFSPool: Codable {
    let name: String
    let health: String
    let capacity: String
    let used: String
    var lastScrub: String?
    var scrubStatus: String?
    var trimStatus: String?
    var trimEligible: Bool?
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

    func getDatasets() -> [ZFSDataset] {
        return datasets
    }

    func getDatasets(forPool poolName: String) -> [ZFSDataset] {
        return datasets.filter { $0.name.hasPrefix("\(poolName)/") || $0.name == poolName }
    }

    func refreshPools() {
        NSLog("ZFSAutoMount: refreshPools() called")
        pools = listPools()
        NSLog("ZFSAutoMount: Found \(pools.count) pools")
        datasets = listDatasets()
        NSLog("ZFSAutoMount: Found \(datasets.count) datasets")

        // Log each dataset's mount status
        for dataset in datasets {
            if dataset.encrypted {
                NSLog("ZFSAutoMount:   - \(dataset.name): mounted=\(dataset.mounted), encrypted=\(dataset.encrypted)")
            }
        }

        // Always post notification on main thread
        DispatchQueue.main.async {
            NSLog("ZFSAutoMount: Posting ZFSPoolsDidChange notification")
            NotificationCenter.default.post(name: NSNotification.Name("ZFSPoolsDidChange"), object: nil)
        }
    }

    private func listPools() -> [ZFSPool] {
        let output = runCommand(zpoolPath, args: ["list", "-H", "-o", "name,health,size,allocated"])

        var result: [ZFSPool] = []
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "\t").map(String.init)
            if parts.count >= 4 {
                var pool = ZFSPool(
                    name: parts[0],
                    health: parts[1],
                    capacity: parts[2],
                    used: parts[3],
                    lastScrub: nil,
                    scrubStatus: nil,
                    trimStatus: nil,
                    trimEligible: nil
                )

                // Get scrub status
                let statusOutput = runCommand(zpoolPath, args: ["status", pool.name])
                let scrubInfo = parseScrubStatus(statusOutput)
                pool.lastScrub = scrubInfo.lastScrub
                pool.scrubStatus = scrubInfo.status

                // Get TRIM eligibility
                let diskInfo = DiskTypeDetector.shared.getPoolDiskInfo(pool.name)
                pool.trimEligible = diskInfo.trimSupport == .supported
                pool.trimStatus = getTRIMStatusLabel(diskInfo.trimSupport)

                result.append(pool)
            }
        }
        return result
    }

    private func parseScrubStatus(_ statusOutput: String) -> (lastScrub: String?, status: String?) {
        // Look for scrub info in status output
        for line in statusOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("scan:") || trimmed.contains("scrub:") {
                // Parse scrub line
                if trimmed.contains("none requested") {
                    return (lastScrub: "Never", status: "Never run")
                } else if trimmed.contains("scrub in progress") {
                    return (lastScrub: "Now", status: "In progress")
                } else if trimmed.contains("scrub repaired") {
                    // Extract date
                    let pattern = "on ([A-Za-z]{3} [A-Za-z]{3}\\s+\\d+ \\d+:\\d+:\\d+ \\d{4})"
                    if let range = trimmed.range(of: pattern, options: .regularExpression) {
                        let dateStr = String(trimmed[range]).replacingOccurrences(of: "on ", with: "")
                        return (lastScrub: formatScrubDate(dateStr), status: "Clean")
                    }
                    return (lastScrub: "Recently", status: "Clean")
                } else if trimmed.contains("with") && trimmed.contains("errors") {
                    return (lastScrub: "Recently", status: "Errors found")
                }
            }
        }

        return (lastScrub: nil, status: nil)
    }

    private func formatScrubDate(_ dateStr: String) -> String {
        // Convert "Mon Oct 16 14:30:00 2025" to "Oct 16, 2025"
        let components = dateStr.components(separatedBy: " ")
        if components.count >= 5 {
            return "\(components[1]) \(components[2]), \(components[4])"
        }
        return dateStr
    }

    private func getTRIMStatusLabel(_ support: TRIMSupport) -> String {
        switch support {
        case .supported: return "Eligible"
        case .notSupported: return "Not eligible"
        case .maybeSupported: return "Maybe (test first)"
        }
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
        NSLog("ZFSAutoMount: Starting mountAllDatasets()")

        // First, refresh to get current pool and dataset state
        refreshPools()

        // Then, load keys for encrypted datasets
        loadKeysForEncryptedDatasets { keysLoaded, keyError in
            if !keysLoaded {
                NSLog("ZFSAutoMount: Failed to load keys: \(keyError ?? "unknown")")
                completion(false, keyError)
                return
            }

            NSLog("ZFSAutoMount: Keys loaded successfully, executing mount_all")

            // Then mount all
            self.helperManager.executeCommand(command: "mount_all") { success, output, error in
                NSLog("ZFSAutoMount: mount_all returned: success=\(success), output=\(output ?? ""), error=\(error ?? "")")

                // Always refresh to get actual state, regardless of command success
                self.refreshPools()

                // Verify actual mount state
                let encryptedDatasets = self.datasets.filter { $0.encrypted }
                NSLog("ZFSAutoMount: Verifying mount state for \(encryptedDatasets.count) encrypted datasets")

                var notMounted: [String] = []
                for dataset in encryptedDatasets {
                    NSLog("ZFSAutoMount: Checking \(dataset.name): mounted=\(dataset.mounted)")
                    if !dataset.mounted {
                        notMounted.append(dataset.name)
                    }
                }

                if !notMounted.isEmpty {
                    let errorMsg = "Failed to mount datasets: \(notMounted.joined(separator: ", "))"
                    NSLog("ZFSAutoMount: \(errorMsg)")
                    completion(false, errorMsg)
                } else {
                    NSLog("ZFSAutoMount: All encrypted datasets verified as mounted")
                    completion(true, nil)
                }
            }
        }
    }

    // MARK: - Encryption Key Management

    private func loadKeysForEncryptedDatasets(completion: @escaping (Bool, String?) -> Void) {
        let encryptedDatasets = datasets.filter { $0.encrypted && !$0.mounted }

        NSLog("ZFSAutoMount: Found \(encryptedDatasets.count) encrypted unmounted datasets")
        for ds in encryptedDatasets {
            NSLog("ZFSAutoMount:   - \(ds.name) (keyFormat: \(ds.keyFormat ?? "none"))")
        }

        if encryptedDatasets.isEmpty {
            NSLog("ZFSAutoMount: No encrypted unmounted datasets, skipping key loading")
            completion(true, nil)
            return
        }

        var errors: [String] = []
        let group = DispatchGroup()

        for dataset in encryptedDatasets {
            group.enter()
            NSLog("ZFSAutoMount: Loading key for \(dataset.name)")
            loadKeyForDataset(dataset) { success, error in
                if !success, let error = error {
                    NSLog("ZFSAutoMount: Failed to load key for \(dataset.name): \(error)")
                    errors.append("\(dataset.name): \(error)")
                } else {
                    NSLog("ZFSAutoMount: Successfully loaded key for \(dataset.name)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if errors.isEmpty {
                NSLog("ZFSAutoMount: All keys loaded successfully")
                completion(true, nil)
            } else {
                let errorMsg = "Failed to load keys:\n" + errors.joined(separator: "\n")
                NSLog("ZFSAutoMount: \(errorMsg)")
                completion(false, errorMsg)
            }
        }
    }

    private func loadKeyForDataset(_ dataset: ZFSDataset, completion: @escaping (Bool, String?) -> Void) {
        NSLog("ZFSAutoMount: loadKeyForDataset(\(dataset.name)) - checking config file first")

        // First, check config file for keylocation
        if let config = configParser.getConfig(for: dataset.name),
           let keyLocation = config.options["keylocation"],
           keyLocation.hasPrefix("file://") {
            let keyPath = String(keyLocation.dropFirst(7)) // Remove "file://"
            NSLog("ZFSAutoMount: Found keylocation in config: \(keyPath)")

            // Read keyfile - handle both binary (raw) and text (passphrase) formats
            if let keyData = try? Data(contentsOf: URL(fileURLWithPath: keyPath)) {
                let keyContent: String
                if dataset.keyFormat == "raw" {
                    // For raw keys, convert binary to hex string
                    keyContent = keyData.map { String(format: "%02x", $0) }.joined()
                    NSLog("ZFSAutoMount: Read raw key from file (\(keyData.count) bytes -> \(keyContent.count) hex chars)")
                } else {
                    // For passphrase keys, read as UTF-8 text
                    if let text = String(data: keyData, encoding: .utf8) {
                        keyContent = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        NSLog("ZFSAutoMount: Read passphrase key from file")
                    } else {
                        NSLog("ZFSAutoMount: Failed to decode passphrase as UTF-8")
                        return
                    }
                }

                NSLog("ZFSAutoMount: Successfully read key from file, sending to helper")
                helperManager.loadKey(for: dataset.name, key: keyContent, keyFormat: dataset.keyFormat ?? "raw") { success, error in
                    completion(success, error)
                }
                return
            } else {
                NSLog("ZFSAutoMount: Failed to read key from file: \(keyPath)")
            }
        }

        // NEW APPROACH: Let the privileged helper check keychain itself (it runs as root)
        // Pass empty key - helper will check system keychain, then user keychain
        NSLog("ZFSAutoMount: No config file key, asking helper to check keychain")
        helperManager.loadKey(for: dataset.name, key: "", keyFormat: dataset.keyFormat ?? "raw") { success, error in
            if success {
                // Key found in keychain by helper
                NSLog("ZFSAutoMount: Helper found key in keychain for \(dataset.name)")
                completion(true, nil)
            } else {
                NSLog("ZFSAutoMount: Helper couldn't find key in keychain: \(error ?? "unknown")")
                // No key in keychain - try user keychain from main app as fallback
                if let key = self.keychainHelper.getKey(for: dataset.name) {
                    NSLog("ZFSAutoMount: Found key in user keychain from app, sending to helper")
                    // Found in user keychain (requires user session), send to helper
                    self.helperManager.loadKey(for: dataset.name, key: key, keyFormat: dataset.keyFormat ?? "raw") { success2, error2 in
                        if success2 {
                            NSLog("ZFSAutoMount: Successfully loaded key from user keychain")
                            completion(true, nil)
                        } else {
                            NSLog("ZFSAutoMount: Failed to load key from user keychain, prompting user")
                            // Still failed - prompt user
                            DispatchQueue.main.async {
                                self.promptForKey(dataset: dataset, completion: completion)
                            }
                        }
                    }
                } else {
                    NSLog("ZFSAutoMount: No key in user keychain either, prompting user")
                    // Not in any keychain - prompt user
                    DispatchQueue.main.async {
                        self.promptForKey(dataset: dataset, completion: completion)
                    }
                }
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
