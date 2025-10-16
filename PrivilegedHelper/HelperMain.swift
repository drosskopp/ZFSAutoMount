import Foundation
import Security

class Helper: NSObject, HelperProtocol, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    private let zpoolPath: String
    private let zfsPath: String

    override init() {
        self.listener = NSXPCListener(machServiceName: "org.openzfs.automount.helper")

        // Find ZFS binaries at initialization
        self.zpoolPath = Helper.findZFSBinary(name: "zpool")
        self.zfsPath = Helper.findZFSBinary(name: "zfs")

        super.init()
        self.listener.delegate = self
    }

    private static func findZFSBinary(name: String) -> String {
        let possiblePaths = [
            "/usr/local/zfs/bin/\(name)",      // OpenZFS on OS X default
            "/opt/homebrew/bin/\(name)",        // Homebrew Apple Silicon
            "/usr/local/bin/\(name)",           // Homebrew Intel
            "/usr/bin/\(name)"                  // System installation
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Default fallback
        return "/usr/local/zfs/bin/\(name)"
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: - HelperProtocol

    func executeCommand(_ command: String, withReply reply: @escaping (String?, String?) -> Void) {
        let parts = command.components(separatedBy: ":")

        switch parts[0] {
        case "import_pools":
            importAllPools(reply: reply)

        case "mount_all":
            mountAllDatasets(reply: reply)

        case "load_key":
            if parts.count >= 4 {
                let dataset = parts[1]
                let keyFormat = parts[2]
                let key = parts[3]
                loadKey(dataset: dataset, key: key, keyFormat: keyFormat, reply: reply)
            } else {
                reply(nil, "Invalid load_key command format")
            }

        case "scrub_pool":
            if parts.count >= 2 {
                let poolName = parts[1]
                scrubPool(poolName: poolName, reply: reply)
            } else {
                reply(nil, "Invalid scrub_pool command format")
            }

        case "trim_pool":
            if parts.count >= 2 {
                let poolName = parts[1]
                trimPool(poolName: poolName, reply: reply)
            } else {
                reply(nil, "Invalid trim_pool command format")
            }

        default:
            reply(nil, "Unknown command: \(command)")
        }
    }

    // MARK: - ZFS Commands

    private func importAllPools(reply: @escaping (String?, String?) -> Void) {
        // Import all pools using stable device identifiers
        let result = runCommand(zpoolPath, args: ["import", "-a", "-d", "/var/run/disk/by-id"])
        if result.status == 0 {
            reply(result.output, nil)
        } else {
            reply(nil, result.error)
        }
    }

    private func mountAllDatasets(reply: @escaping (String?, String?) -> Void) {
        let result = runCommand(zfsPath, args: ["mount", "-a"])
        if result.status == 0 {
            reply(result.output, nil)
        } else {
            reply(nil, result.error)
        }
    }

    private func loadKey(dataset: String, key: String, keyFormat: String, reply: @escaping (String?, String?) -> Void) {
        NSLog("ZFSAutoMount Helper: Loading key for dataset: \(dataset), keyFormat: \(keyFormat)")

        // If no key provided, try to get from keychain (helper runs as root, can access system keychain)
        var actualKey = key
        if key.isEmpty {
            NSLog("ZFSAutoMount Helper: No key provided, checking keychain...")
            if let keychainKey = getKeyFromKeychain(for: dataset) {
                actualKey = keychainKey
                NSLog("ZFSAutoMount Helper: Found key in keychain")
            } else {
                reply(nil, "No key provided and none found in keychain")
                return
            }
        }

        // Create temporary file for key
        let tempDir = NSTemporaryDirectory()
        let tempKeyFile = tempDir + "zfs_key_\(UUID().uuidString)"

        do {
            // Handle different key formats
            let keyData: Data
            if keyFormat == "raw" {
                // For raw keys, the key string should be hex-encoded
                // Convert hex string to binary data
                keyData = hexStringToData(actualKey) ?? Data()
                if keyData.isEmpty {
                    reply(nil, "Invalid hex key format for raw key")
                    return
                }
                NSLog("ZFSAutoMount Helper: Converted hex key to \(keyData.count) bytes")
            } else {
                // For passphrase keys, write as UTF-8
                keyData = actualKey.data(using: .utf8) ?? Data()
                NSLog("ZFSAutoMount Helper: Using passphrase key (\(keyData.count) bytes)")
            }

            // Write binary data to temp file
            try keyData.write(to: URL(fileURLWithPath: tempKeyFile), options: .atomic)

            NSLog("ZFSAutoMount Helper: Running zfs load-key for \(dataset)")
            let result = runCommand(zfsPath, args: [
                "load-key",
                "-L", "file://\(tempKeyFile)",
                dataset
            ])

            // Clean up temp file securely
            try? FileManager.default.removeItem(atPath: tempKeyFile)

            if result.status == 0 {
                NSLog("ZFSAutoMount Helper: Key loaded successfully for \(dataset)")
                reply(result.output, nil)
            } else {
                NSLog("ZFSAutoMount Helper: Failed to load key for \(dataset): \(result.error)")
                reply(nil, result.error)
            }
        } catch {
            NSLog("ZFSAutoMount Helper: Exception: \(error.localizedDescription)")
            reply(nil, "Failed to write temp key file: \(error.localizedDescription)")
        }
    }

    private func scrubPool(poolName: String, reply: @escaping (String?, String?) -> Void) {
        NSLog("ZFSAutoMount Helper: Starting scrub on pool: \(poolName)")
        let result = runCommand(zpoolPath, args: ["scrub", poolName])
        if result.status == 0 {
            NSLog("ZFSAutoMount Helper: Scrub started successfully on \(poolName)")
            reply(result.output, nil)
        } else {
            NSLog("ZFSAutoMount Helper: Failed to start scrub on \(poolName): \(result.error)")
            reply(nil, result.error)
        }
    }

    private func trimPool(poolName: String, reply: @escaping (String?, String?) -> Void) {
        NSLog("ZFSAutoMount Helper: Starting TRIM on pool: \(poolName)")
        let result = runCommand(zpoolPath, args: ["trim", poolName])
        if result.status == 0 {
            NSLog("ZFSAutoMount Helper: TRIM started successfully on \(poolName)")
            reply(result.output, nil)
        } else {
            NSLog("ZFSAutoMount Helper: Failed to start TRIM on \(poolName): \(result.error)")
            reply(nil, result.error)
        }
    }

    // MARK: - Keychain Access (runs as root, can access system keychain)

    private func getKeyFromKeychain(for dataset: String) -> String? {
        let service = "org.openzfs.automount"

        // Try system keychain first (for boot-time access)
        if let key = readKeyFromKeychain(service: service, account: dataset, systemKeychain: true) {
            NSLog("ZFSAutoMount Helper: Retrieved key for \(dataset) from system keychain")
            return key
        }

        // Fallback to user keychain (for post-login manual mounting)
        if let key = readKeyFromKeychain(service: service, account: dataset, systemKeychain: false) {
            NSLog("ZFSAutoMount Helper: Retrieved key for \(dataset) from user keychain")
            return key
        }

        NSLog("ZFSAutoMount Helper: No key found for \(dataset) in any keychain")
        return nil
    }

    private func readKeyFromKeychain(service: String, account: String, systemKeychain: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Specify system keychain if needed
        if systemKeychain {
            let systemKeychainPath = "/Library/Keychains/System.keychain"
            var keychain: SecKeychain?
            let status = SecKeychainOpen(systemKeychainPath, &keychain)

            if status == errSecSuccess, let keychainRef = keychain {
                query[kSecMatchSearchList as String] = [keychainRef] as CFArray
            } else {
                NSLog("ZFSAutoMount Helper: Failed to open system keychain: \(status)")
                return nil
            }
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data,
              let key = String(data: keyData, encoding: .utf8) else {
            if status != errSecItemNotFound {
                NSLog("ZFSAutoMount Helper: Keychain read failed: \(status)")
            }
            return nil
        }

        return key
    }

    // Convert hex string to binary data
    private func hexStringToData(_ hex: String) -> Data? {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)

        // Log for debugging
        NSLog("ZFSAutoMount Helper: Converting hex string (length: \(hex.count), clean: \(cleanHex.count))")
        NSLog("ZFSAutoMount Helper: First 32 chars: \(String(cleanHex.prefix(32)))")

        guard cleanHex.count % 2 == 0 else {
            NSLog("ZFSAutoMount Helper: ERROR - Hex string length is odd: \(cleanHex.count)")
            return nil
        }

        // Check if all characters are valid hex
        let hexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard cleanHex.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else {
            NSLog("ZFSAutoMount Helper: ERROR - Invalid hex characters found")
            return nil
        }

        var data = Data()
        var index = cleanHex.startIndex

        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = cleanHex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                NSLog("ZFSAutoMount Helper: ERROR - Failed to parse byte: \(byteString)")
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        NSLog("ZFSAutoMount Helper: Successfully converted hex to \(data.count) bytes")
        return data
    }

    // MARK: - Helper Methods

    private func runCommand(_ path: String, args: [String]) -> (status: Int32, output: String, error: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return (task.terminationStatus, output, error)
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
}

// MARK: - Main Entry Point

@main
struct HelperMain {
    static func main() {
        autoreleasepool {
            let helper = Helper()
            helper.run()
        }
    }
}
