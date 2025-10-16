import Foundation

struct ZFSMountConfig {
    let dataset: String
    let options: [String: String]
}

class ConfigParser {
    static let shared = ConfigParser()

    private let configPath = "/etc/zfs/automount.conf"

    private init() {}

    // MARK: - Parse Configuration

    func parseConfig() -> [ZFSMountConfig] {
        guard FileManager.default.fileExists(atPath: configPath) else {
            return []
        }

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }

        var configs: [ZFSMountConfig] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse line: dataset option=value option=value
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard !parts.isEmpty else { continue }

            let dataset = parts[0]
            var options: [String: String] = [:]

            // Parse options
            for optionPart in parts.dropFirst() {
                let keyValue = optionPart.components(separatedBy: "=")
                if keyValue.count == 2 {
                    options[keyValue[0]] = keyValue[1]
                }
            }

            configs.append(ZFSMountConfig(dataset: dataset, options: options))
        }

        return configs
    }

    // MARK: - Get Config for Dataset

    func getConfig(for dataset: String) -> ZFSMountConfig? {
        let configs = parseConfig()
        return configs.first { $0.dataset == dataset }
    }

    // MARK: - Write Default Config

    func writeDefaultConfig() {
        let defaultContent = """
        # ZFS AutoMount Configuration
        # Format: pool/dataset option=value [option=value ...]

        # Available options:
        #   keylocation   - Path to keyfile (e.g., file:///path/to/keyfile)
        #   readonly      - Mount readonly (on/off)
        #   canmount      - Control mounting (on/off/noauto)
        #   mountpoint    - Custom mount point

        # Examples:
        # tank/enc1 keylocation=file:///Volumes/external/keys/enc1.key
        # media/enc2 readonly=on
        # tank/backup canmount=noauto

        # Your ZFS datasets (examples based on your system):
        # media/enc2 keylocation=file:///path/to/media-enc2.key
        # tank/enc1 keylocation=file:///path/to/tank-enc1.key
        """

        // Only write if doesn't exist
        if !FileManager.default.fileExists(atPath: configPath) {
            try? defaultContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Add or Update Entry

    func updateConfig(dataset: String, options: [String: String]) {
        var configs = parseConfig()

        // Remove existing entry for this dataset
        configs.removeAll { $0.dataset == dataset }

        // Add new entry
        configs.append(ZFSMountConfig(dataset: dataset, options: options))

        // Write back
        writeConfig(configs)
    }

    // MARK: - Remove Entry

    func removeConfig(for dataset: String) {
        var configs = parseConfig()
        configs.removeAll { $0.dataset == dataset }
        writeConfig(configs)
    }

    // MARK: - Write Config

    private func writeConfig(_ configs: [ZFSMountConfig]) {
        var lines: [String] = [
            "# ZFS AutoMount Configuration",
            "# Format: pool/dataset option=value [option=value ...]",
            ""
        ]

        for config in configs {
            var line = config.dataset
            for (key, value) in config.options {
                line += " \(key)=\(value)"
            }
            lines.append(line)
        }

        let content = lines.joined(separator: "\n")
        try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}
