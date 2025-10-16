import Foundation

class Helper: NSObject, HelperProtocol, NSXPCListenerDelegate {
    private let listener: NSXPCListener

    override init() {
        self.listener = NSXPCListener(machServiceName: "org.openzfs.automount.helper")
        super.init()
        self.listener.delegate = self
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

        default:
            reply(nil, "Unknown command: \(command)")
        }
    }

    // MARK: - ZFS Commands

    private func importAllPools(reply: @escaping (String?, String?) -> Void) {
        let result = runCommand("/usr/local/zfs/bin/zpool", args: ["import", "-a"])
        if result.status == 0 {
            reply(result.output, nil)
        } else {
            reply(nil, result.error)
        }
    }

    private func mountAllDatasets(reply: @escaping (String?, String?) -> Void) {
        let result = runCommand("/usr/local/zfs/bin/zfs", args: ["mount", "-a"])
        if result.status == 0 {
            reply(result.output, nil)
        } else {
            reply(nil, result.error)
        }
    }

    private func loadKey(dataset: String, key: String, keyFormat: String, reply: @escaping (String?, String?) -> Void) {
        // Create temporary file for key
        let tempDir = NSTemporaryDirectory()
        let tempKeyFile = tempDir + "zfs_key_\(UUID().uuidString)"

        do {
            try key.write(toFile: tempKeyFile, atomically: true, encoding: .utf8)

            let result = runCommand("/usr/local/zfs/bin/zfs", args: [
                "load-key",
                "-L", "file://\(tempKeyFile)",
                dataset
            ])

            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempKeyFile)

            if result.status == 0 {
                reply(result.output, nil)
            } else {
                reply(nil, result.error)
            }
        } catch {
            reply(nil, "Failed to write temp key file: \(error.localizedDescription)")
        }
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
