import Foundation

enum DiskProtocol: String {
    case nvme = "NVMe"
    case sata = "SATA"
    case usb = "USB"
    case thunderbolt = "Thunderbolt"
    case unknown = "Unknown"
}

enum TRIMSupport {
    case supported      // All SSDs, native support
    case notSupported   // HDDs or mixed
    case maybeSupported // USB/Thunderbolt, needs testing
}

struct DiskInfo {
    let path: String
    let deviceName: String
    let isSSD: Bool
    let `protocol`: DiskProtocol
    let model: String
}

struct PoolDiskInfo {
    let poolName: String
    let disks: [DiskInfo]
    let allSSDs: Bool
    let trimSupport: TRIMSupport

    var diskSummary: String {
        if disks.isEmpty {
            return "Unknown"
        }

        let ssdCount = disks.filter { $0.isSSD }.count
        let hddCount = disks.count - ssdCount

        if ssdCount > 0 && hddCount == 0 {
            // All SSDs
            let protocols = Set(disks.map { $0.protocol.rawValue }).sorted()
            return "\(ssdCount)x \(protocols.joined(separator: "/")) SSD"
        } else if hddCount > 0 && ssdCount == 0 {
            // All HDDs
            return "\(hddCount)x HDD"
        } else {
            // Mixed
            return "\(ssdCount)x SSD + \(hddCount)x HDD"
        }
    }
}

class DiskTypeDetector {
    static let shared = DiskTypeDetector()

    private init() {}

    // MARK: - Public API

    func getPoolDiskInfo(_ poolName: String) -> PoolDiskInfo {
        let disks = getDisksForPool(poolName)
        let allSSDs = !disks.isEmpty && disks.allSatisfy { $0.isSSD }
        let trimSupport = determineTRIMSupport(disks: disks)

        return PoolDiskInfo(
            poolName: poolName,
            disks: disks,
            allSSDs: allSSDs,
            trimSupport: trimSupport
        )
    }

    // MARK: - Private Methods

    private func getDisksForPool(_ poolName: String) -> [DiskInfo] {
        // Get pool status output
        let output = runCommand("/usr/local/zfs/bin/zpool", args: ["status", poolName])

        var disks: [DiskInfo] = []

        // Parse disk lines (looking for disk paths)
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for disk entries (usually start with /dev/disk or diskX)
            if trimmed.hasPrefix("/dev/disk") || trimmed.hasPrefix("disk") {
                let parts = trimmed.split(separator: " ")
                if let diskPath = parts.first {
                    let diskPathStr = String(diskPath)
                    if let diskInfo = getDiskInfo(diskPathStr) {
                        disks.append(diskInfo)
                    }
                }
            }
        }

        return disks
    }

    private func getDiskInfo(_ diskPath: String) -> DiskInfo? {
        // Normalize path (remove /dev/ if present)
        var deviceName = diskPath
        if deviceName.hasPrefix("/dev/") {
            deviceName = String(deviceName.dropFirst(5))
        }

        // Get disk info using diskutil
        let output = runCommand("/usr/sbin/diskutil", args: ["info", deviceName])

        var isSSD = false
        var protocolType = DiskProtocol.unknown
        var model = "Unknown"

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if SSD
            if trimmed.contains("Solid State:") {
                isSSD = trimmed.contains("Yes")
            }

            // Check protocol
            if trimmed.contains("Protocol:") {
                if trimmed.contains("NVMe") {
                    protocolType = .nvme
                    isSSD = true // NVMe is always SSD
                } else if trimmed.contains("SATA") {
                    protocolType = .sata
                } else if trimmed.contains("USB") {
                    protocolType = .usb
                } else if trimmed.contains("Thunderbolt") {
                    protocolType = .thunderbolt
                }
            }

            // Get model name
            if trimmed.contains("Device / Media Name:") || trimmed.contains("Media Name:") {
                let parts = trimmed.split(separator: ":")
                if parts.count > 1 {
                    model = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)

                    // Check for SSD/NVME in model name as fallback
                    if model.uppercased().contains("SSD") || model.uppercased().contains("NVME") {
                        isSSD = true
                    }
                }
            }
        }

        return DiskInfo(
            path: diskPath,
            deviceName: deviceName,
            isSSD: isSSD,
            protocol: protocolType,
            model: model
        )
    }

    private func determineTRIMSupport(disks: [DiskInfo]) -> TRIMSupport {
        if disks.isEmpty {
            return .notSupported
        }

        // Check if all are SSDs
        guard disks.allSatisfy({ $0.isSSD }) else {
            return .notSupported
        }

        // Check protocols
        let protocols = Set(disks.map { $0.protocol })

        // If any USB or Thunderbolt, mark as "maybe"
        if protocols.contains(.usb) || protocols.contains(.thunderbolt) {
            return .maybeSupported
        }

        // NVMe and SATA SSDs are fully supported
        if protocols.contains(.nvme) || protocols.contains(.sata) {
            return .supported
        }

        return .notSupported
    }

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
            print("Error running command \(path): \(error)")
            return ""
        }
    }
}
