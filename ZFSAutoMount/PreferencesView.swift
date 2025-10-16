import SwiftUI

struct PreferencesView: View {
    @State private var autoImportOnBoot = true
    @State private var autoMountOnBoot = true
    @State private var showNotifications = true
    @State private var savedKeys: [String] = []

    private let keychainHelper = KeychainHelper.shared

    var body: some View {
        TabView {
            GeneralTab(
                autoImportOnBoot: $autoImportOnBoot,
                autoMountOnBoot: $autoMountOnBoot,
                showNotifications: $showNotifications
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            EncryptionTab(savedKeys: $savedKeys)
                .tabItem {
                    Label("Encryption", systemImage: "lock.fill")
                }

            MaintenanceTab()
                .tabItem {
                    Label("Maintenance", systemImage: "wrench.and.screwdriver")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadPreferences()
            savedKeys = keychainHelper.listAllKeys()
        }
    }

    private func loadPreferences() {
        // Check if LaunchDaemon is actually installed
        let daemonInstalled = FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/org.openzfs.automount.daemon.plist")

        // If LaunchDaemon exists but preferences say it's off, sync with reality
        if daemonInstalled {
            // LaunchDaemon is installed, so at least one toggle should be on
            // Default to having both on if daemon exists
            if UserDefaults.standard.object(forKey: "autoImportOnBoot") == nil {
                UserDefaults.standard.set(true, forKey: "autoImportOnBoot")
            }
            if UserDefaults.standard.object(forKey: "autoMountOnBoot") == nil {
                UserDefaults.standard.set(true, forKey: "autoMountOnBoot")
            }
        } else {
            // LaunchDaemon is NOT installed, toggles should be off
            if UserDefaults.standard.object(forKey: "autoImportOnBoot") == nil {
                UserDefaults.standard.set(false, forKey: "autoImportOnBoot")
            }
            if UserDefaults.standard.object(forKey: "autoMountOnBoot") == nil {
                UserDefaults.standard.set(false, forKey: "autoMountOnBoot")
            }

            // If preferences say ON but daemon doesn't exist, fix the mismatch
            if UserDefaults.standard.bool(forKey: "autoImportOnBoot") ||
               UserDefaults.standard.bool(forKey: "autoMountOnBoot") {
                print("⚠️ Preferences say ON but LaunchDaemon not installed - syncing to OFF")
                UserDefaults.standard.set(false, forKey: "autoImportOnBoot")
                UserDefaults.standard.set(false, forKey: "autoMountOnBoot")
            }
        }

        // Set default for notifications if never set
        if UserDefaults.standard.object(forKey: "showNotifications") == nil {
            UserDefaults.standard.set(true, forKey: "showNotifications")
        }

        // Load the actual values
        autoImportOnBoot = UserDefaults.standard.bool(forKey: "autoImportOnBoot")
        autoMountOnBoot = UserDefaults.standard.bool(forKey: "autoMountOnBoot")
        showNotifications = UserDefaults.standard.bool(forKey: "showNotifications")

        print("📋 Loaded preferences: daemon=\(daemonInstalled), import=\(autoImportOnBoot), mount=\(autoMountOnBoot), notify=\(showNotifications)")
    }
}

struct GeneralTab: View {
    @Binding var autoImportOnBoot: Bool
    @Binding var autoMountOnBoot: Bool
    @Binding var showNotifications: Bool

    var body: some View {
        Form {
            Section(header: Text("Boot Behavior")) {
                Toggle("Auto-import pools on boot", isOn: $autoImportOnBoot)
                    .onChange(of: autoImportOnBoot) { oldValue, newValue in
                        updateLaunchDaemon(oldValue: oldValue, newValue: newValue)
                    }

                Toggle("Auto-mount datasets on boot", isOn: $autoMountOnBoot)
                    .onChange(of: autoMountOnBoot) { oldValue, newValue in
                        updateLaunchDaemon(oldValue: oldValue, newValue: newValue)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Note: Pools must be imported before datasets can be mounted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("If mount is enabled, pools will be imported automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Requires privileged helper to be installed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Notifications")) {
                Toggle("Show notifications", isOn: $showNotifications)
                    .onChange(of: showNotifications) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "showNotifications")
                    }
            }

            Section(header: Text("Helper Tool")) {
                HStack {
                    Text("Privileged Helper Status:")
                    Spacer()
                    if PrivilegedHelperManager.shared.isHelperInstalled() {
                        Text("Installed")
                            .foregroundColor(.green)
                    } else {
                        Text("Not Installed")
                            .foregroundColor(.red)
                    }
                }

                Button("Install/Update Helper") {
                    installHelper()
                }
            }
        }
        .padding()
    }

    private func installHelper() {
        PrivilegedHelperManager.shared.installHelper { success, error in
            let alert = NSAlert()
            if success {
                alert.messageText = "Success"
                alert.informativeText = "Privileged helper installed successfully"
                alert.alertStyle = .informational
            } else {
                alert.messageText = "Installation Failed"
                alert.informativeText = error ?? "Unknown error"
                alert.alertStyle = .critical
            }
            alert.runModal()
        }
    }

    private func updateLaunchDaemon(oldValue: Bool, newValue: Bool) {
        // Check if either toggle is on
        let shouldInstall = autoImportOnBoot || autoMountOnBoot

        if shouldInstall {
            installLaunchDaemon { success in
                if success {
                    // Save the new values
                    UserDefaults.standard.set(self.autoImportOnBoot, forKey: "autoImportOnBoot")
                    UserDefaults.standard.set(self.autoMountOnBoot, forKey: "autoMountOnBoot")
                } else {
                    // Revert the toggle - user cancelled or error occurred
                    DispatchQueue.main.async {
                        // Revert the specific toggle that changed
                        if self.autoImportOnBoot != UserDefaults.standard.bool(forKey: "autoImportOnBoot") {
                            self.autoImportOnBoot = UserDefaults.standard.bool(forKey: "autoImportOnBoot")
                        }
                        if self.autoMountOnBoot != UserDefaults.standard.bool(forKey: "autoMountOnBoot") {
                            self.autoMountOnBoot = UserDefaults.standard.bool(forKey: "autoMountOnBoot")
                        }
                    }
                }
            }
        } else {
            removeLaunchDaemon { success in
                if success {
                    // Save the new values
                    UserDefaults.standard.set(self.autoImportOnBoot, forKey: "autoImportOnBoot")
                    UserDefaults.standard.set(self.autoMountOnBoot, forKey: "autoMountOnBoot")
                } else {
                    // Revert the toggle
                    DispatchQueue.main.async {
                        if self.autoImportOnBoot != UserDefaults.standard.bool(forKey: "autoImportOnBoot") {
                            self.autoImportOnBoot = UserDefaults.standard.bool(forKey: "autoImportOnBoot")
                        }
                        if self.autoMountOnBoot != UserDefaults.standard.bool(forKey: "autoMountOnBoot") {
                            self.autoMountOnBoot = UserDefaults.standard.bool(forKey: "autoMountOnBoot")
                        }
                    }
                }
            }
        }
    }

    private func installLaunchDaemon(completion: @escaping (Bool) -> Void) {
        print("Installing LaunchDaemon for boot automation...")

        // Get the app bundle path
        guard let appPath = Bundle.main.bundlePath as String? else {
            print("Error: Could not find app bundle path")
            completion(false)
            return
        }

        // Create LaunchDaemon plist content
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>org.openzfs.automount.daemon</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)/Contents/MacOS/ZFSAutoMount</string>
                <string>--boot-mount</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/var/log/zfs-automount.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/zfs-automount-error.log</string>
        </dict>
        </plist>
        """

        // Write to temporary location
        let tempPath = "/tmp/org.openzfs.automount.daemon.plist"
        do {
            try plist.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing plist: \(error)")
            completion(false)
            return
        }

        // Use AppleScript to get admin privileges and install
        let script = """
        do shell script "cp '\(tempPath)' '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist' && chown root:wheel '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist' && chmod 644 '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist' && launchctl unload '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist' 2>/dev/null; launchctl load '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist'" with administrator privileges
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0

                // Error code -128 means user cancelled
                if errorCode == -128 {
                    print("User cancelled password prompt")
                    completion(false)
                    return
                }

                print("Error installing LaunchDaemon: \(error)")
                showAlert(title: "Installation Failed", message: "Could not install LaunchDaemon: \(error["NSAppleScriptErrorMessage"] ?? "unknown error")")
                completion(false)
            } else {
                print("✅ LaunchDaemon installed successfully")
                showAlert(title: "Success", message: "Boot automation enabled. Pools will auto-import at boot.")
                completion(true)
            }
        } else {
            completion(false)
        }
    }

    private func removeLaunchDaemon(completion: @escaping (Bool) -> Void) {
        print("Removing LaunchDaemon (boot automation disabled)...")

        let script = """
        do shell script "launchctl unload '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist' 2>/dev/null; rm -f '/Library/LaunchDaemons/org.openzfs.automount.daemon.plist'" with administrator privileges
        """

        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0

                // Error code -128 means user cancelled
                if errorCode == -128 {
                    print("User cancelled password prompt")
                    completion(false)
                    return
                }

                print("Error removing LaunchDaemon: \(error)")
                completion(false)
            } else {
                print("✅ LaunchDaemon removed successfully")
                showAlert(title: "Boot Automation Disabled", message: "Pools will no longer auto-import at boot.")
                completion(true)
            }
        } else {
            completion(false)
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}

struct EncryptionTab: View {
    @Binding var savedKeys: [String]
    @State private var encryptionInfo: [EncryptionKeyInfo] = []
    @State private var showingEditSheet = false
    @State private var editingKey: EncryptionKeyInfo?

    private let keychainHelper = KeychainHelper.shared
    private let configParser = ConfigParser.shared
    private let zfsManager = ZFSManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Encryption Keys")
                    .font(.headline)
                Spacer()
                Button(action: refreshKeys) {
                    Image(systemName: "arrow.clockwise")
                }
            }

            if encryptionInfo.isEmpty {
                VStack(spacing: 8) {
                    Text("No encryption keys configured")
                        .foregroundColor(.secondary)
                    Text("Encrypted datasets will prompt for password when mounting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(encryptionInfo, id: \.dataset) { info in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: info.source == .keychain ? "key.fill" : "doc.fill")
                                    .foregroundColor(info.source == .keychain ? .blue : .green)
                                Text(info.dataset)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()

                                // Source badge
                                Text(info.sourceLabel)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(info.source == .keychain ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            // Details
                            HStack {
                                if let details = info.details {
                                    Text(details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()

                                // Action buttons
                                HStack(spacing: 8) {
                                    Button("Edit") {
                                        editingKey = info
                                        showingEditSheet = true
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Delete") {
                                        deleteKey(info: info)
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Info text
            VStack(alignment: .leading, spacing: 4) {
                Text("Key Sources:")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("🔵 Keychain - Stored in macOS Keychain (user or system)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("🟢 Keyfile - File in /etc/zfs/keys/ (referenced in config)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            refreshKeys()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let key = editingKey {
                EditKeySheet(keyInfo: key, onSave: { newValue in
                    saveEditedKey(info: key, newValue: newValue)
                    showingEditSheet = false
                }, onCancel: {
                    showingEditSheet = false
                })
            }
        }
    }

    private func refreshKeys() {
        var info: [EncryptionKeyInfo] = []

        // Get all encrypted datasets from ZFS
        let datasets = zfsManager.getDatasets().filter { $0.encrypted }

        for dataset in datasets {
            var keyInfo = EncryptionKeyInfo(dataset: dataset.name, source: .none, details: nil)

            // Check config file first
            if let config = configParser.getConfig(for: dataset.name),
               let keyLocation = config.options["keylocation"],
               keyLocation.hasPrefix("file://") {
                let keyPath = String(keyLocation.dropFirst(7)) // Remove "file://"
                keyInfo.source = .keyfile
                keyInfo.details = "Path: \(keyPath)"
            }
            // Check keychain
            else if keychainHelper.getKey(for: dataset.name) != nil {
                keyInfo.source = .keychain
                keyInfo.details = "Stored in macOS Keychain"
            }
            // No key configured
            else {
                keyInfo.source = .none
                keyInfo.details = "No key configured - will prompt on mount"
            }

            info.append(keyInfo)
        }

        encryptionInfo = info
    }

    private func deleteKey(info: EncryptionKeyInfo) {
        let alert = NSAlert()
        alert.messageText = "Delete Key"

        if info.source == .keychain {
            alert.informativeText = "Delete encryption key for \(info.dataset) from Keychain?"
        } else if info.source == .keyfile {
            alert.informativeText = "Remove keyfile reference for \(info.dataset) from config?\n\nNote: This won't delete the actual keyfile."
        } else {
            return // Nothing to delete
        }

        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if info.source == .keychain {
                keychainHelper.deleteKey(for: info.dataset)
            } else if info.source == .keyfile {
                configParser.removeDataset(info.dataset)
            }
            refreshKeys()
            savedKeys = keychainHelper.listAllKeys()
        }
    }

    private func saveEditedKey(info: EncryptionKeyInfo, newValue: String) {
        if info.source == .keychain || newValue.starts(with: "keychain:") {
            // Save to keychain
            let keyValue = newValue.hasPrefix("keychain:") ? String(newValue.dropFirst(9)) : newValue
            keychainHelper.saveKey(keyValue, for: info.dataset)
        } else if newValue.starts(with: "file:") {
            // Save to config file as keyfile reference
            let filePath = String(newValue.dropFirst(5))
            configParser.updateConfig(for: info.dataset, options: ["keylocation": "file://\(filePath)"])
        }
        refreshKeys()
        savedKeys = keychainHelper.listAllKeys()
    }
}

struct EncryptionKeyInfo {
    let dataset: String
    var source: KeySource
    var details: String?

    var sourceLabel: String {
        switch source {
        case .keychain: return "Keychain"
        case .keyfile: return "Keyfile"
        case .none: return "None"
        }
    }
}

enum KeySource {
    case keychain
    case keyfile
    case none
}

struct EditKeySheet: View {
    let keyInfo: EncryptionKeyInfo
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var keyType: String = "keychain"
    @State private var keychainValue: String = ""
    @State private var keyfilePath: String = "/etc/zfs/keys/"
    @State private var showPassword: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Key for \(keyInfo.dataset)")
                .font(.headline)

            Picker("Key Type", selection: $keyType) {
                Text("Keychain (Password/Hex)").tag("keychain")
                Text("Keyfile Path").tag("keyfile")
            }
            .pickerStyle(.segmented)

            if keyType == "keychain" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if showPassword {
                            TextField("Enter password or hex key", text: $keychainValue)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter password or hex key", text: $keychainValue)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                    }
                    Text("Enter passphrase or 64-character hex key (for raw keyfile)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Keyfile path", text: $keyfilePath)
                        .textFieldStyle(.roundedBorder)
                    Text("Full path to keyfile (e.g., /etc/zfs/keys/tank.key)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("⚠️ File must exist and be readable by root")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    if keyType == "keychain" {
                        onSave("keychain:\(keychainValue)")
                    } else {
                        onSave("file:\(keyfilePath)")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(keyType == "keychain" ? keychainValue.isEmpty : keyfilePath.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 300)
        .onAppear {
            // Pre-populate if editing existing key
            if keyInfo.source == .keychain {
                keyType = "keychain"
                keychainValue = KeychainHelper.shared.getKey(for: keyInfo.dataset) ?? ""
            } else if keyInfo.source == .keyfile,
                      let details = keyInfo.details,
                      let path = details.split(separator: " ").last {
                keyType = "keyfile"
                keyfilePath = String(path)
            }
        }
    }
}

// MARK: - Maintenance Tab

struct MaintenanceTab: View {
    @State private var scrubEnabled = false
    @State private var trimEnabled = false
    @State private var scrubFrequency = "monthly"
    @State private var trimFrequency = "weekly"
    @State private var scrubDayOfWeek = 0 // Sunday
    @State private var trimDayOfWeek = 0 // Sunday
    @State private var scrubHour = 2
    @State private var trimHour = 3
    @State private var pools: [ZFSPool] = []

    private let zfsManager = ZFSManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Scrub Schedule Section
                GroupBox(label: Label("Scrub Schedule", systemImage: "magnifyingglass")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable automatic scrubbing", isOn: $scrubEnabled)
                            .onChange(of: scrubEnabled) { _, newValue in
                                updateScrubSchedule()
                            }

                        if scrubEnabled {
                            Picker("Frequency:", selection: $scrubFrequency) {
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                                Text("Quarterly").tag("quarterly")
                            }
                            .onChange(of: scrubFrequency) { _, _ in
                                updateScrubSchedule()
                            }

                            Picker("Run on:", selection: $scrubDayOfWeek) {
                                Text("Sunday").tag(0)
                                Text("Monday").tag(1)
                                Text("Tuesday").tag(2)
                                Text("Wednesday").tag(3)
                                Text("Thursday").tag(4)
                                Text("Friday").tag(5)
                                Text("Saturday").tag(6)
                            }
                            .onChange(of: scrubDayOfWeek) { _, _ in
                                updateScrubSchedule()
                            }

                            Picker("Time:", selection: $scrubHour) {
                                ForEach(0..<24) { hour in
                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                }
                            }
                            .onChange(of: scrubHour) { _, _ in
                                updateScrubSchedule()
                            }

                            Text("Next scrub: \(nextScrubDate())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // TRIM Schedule Section
                GroupBox(label: Label("TRIM Schedule", systemImage: "scissors")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable automatic TRIM", isOn: $trimEnabled)
                            .onChange(of: trimEnabled) { _, newValue in
                                updateTRIMSchedule()
                            }

                        if trimEnabled {
                            Picker("Frequency:", selection: $trimFrequency) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                            .onChange(of: trimFrequency) { _, _ in
                                updateTRIMSchedule()
                            }

                            if trimFrequency != "daily" {
                                Picker("Run on:", selection: $trimDayOfWeek) {
                                    Text("Sunday").tag(0)
                                    Text("Monday").tag(1)
                                    Text("Tuesday").tag(2)
                                    Text("Wednesday").tag(3)
                                    Text("Thursday").tag(4)
                                    Text("Friday").tag(5)
                                    Text("Saturday").tag(6)
                                }
                                .onChange(of: trimDayOfWeek) { _, _ in
                                    updateTRIMSchedule()
                                }
                            }

                            Picker("Time:", selection: $trimHour) {
                                ForEach(0..<24) { hour in
                                    Text(String(format: "%02d:00", hour)).tag(hour)
                                }
                            }
                            .onChange(of: trimHour) { _, _ in
                                updateTRIMSchedule()
                            }

                            Text("Next TRIM: \(nextTRIMDate())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                // Pool Status Section
                GroupBox(label: Label("Pool Status", systemImage: "externaldrive.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if pools.isEmpty {
                            Text("No pools found")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(pools, id: \.name) { pool in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("📦 \(pool.name)")
                                        .font(.headline)

                                    // Scrub status
                                    HStack {
                                        Text("🔍 Scrub:")
                                        if let lastScrub = pool.lastScrub, let status = pool.scrubStatus {
                                            Text("Last: \(lastScrub) - \(status)")
                                                .font(.caption)
                                        } else {
                                            Text("Never run")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("Run Now") {
                                            runScrubNow(pool: pool.name)
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    // TRIM status (only for SSD pools)
                                    if let trimEligible = pool.trimEligible, trimEligible {
                                        HStack {
                                            Text("✂️ TRIM:")
                                            if let trimStatus = pool.trimStatus {
                                                Text(trimStatus)
                                                    .font(.caption)
                                            }
                                            Spacer()
                                            Button("Run Now") {
                                                runTRIMNow(pool: pool.name)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    Divider()
                                }
                            }
                        }

                        Button("Refresh") {
                            refreshPools()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .onAppear {
            loadPreferences()
            refreshPools()
        }
    }

    private func loadPreferences() {
        scrubEnabled = UserDefaults.standard.bool(forKey: "scrubEnabled")
        trimEnabled = UserDefaults.standard.bool(forKey: "trimEnabled")
        scrubFrequency = UserDefaults.standard.string(forKey: "scrubFrequency") ?? "monthly"
        trimFrequency = UserDefaults.standard.string(forKey: "trimFrequency") ?? "weekly"
        scrubDayOfWeek = UserDefaults.standard.integer(forKey: "scrubDayOfWeek")
        trimDayOfWeek = UserDefaults.standard.integer(forKey: "trimDayOfWeek")
        scrubHour = UserDefaults.standard.integer(forKey: "scrubHour") == 0 ? 2 : UserDefaults.standard.integer(forKey: "scrubHour")
        trimHour = UserDefaults.standard.integer(forKey: "trimHour") == 0 ? 3 : UserDefaults.standard.integer(forKey: "trimHour")
    }

    private func refreshPools() {
        pools = zfsManager.getPools()
    }

    private func updateScrubSchedule() {
        UserDefaults.standard.set(scrubEnabled, forKey: "scrubEnabled")
        UserDefaults.standard.set(scrubFrequency, forKey: "scrubFrequency")
        UserDefaults.standard.set(scrubDayOfWeek, forKey: "scrubDayOfWeek")
        UserDefaults.standard.set(scrubHour, forKey: "scrubHour")

        if scrubEnabled {
            installScrubDaemon { success in
                if success {
                    print("✅ Scrub daemon installed successfully")
                } else {
                    print("❌ Failed to install scrub daemon")
                    DispatchQueue.main.async {
                        self.scrubEnabled = false
                    }
                }
            }
        } else {
            removeScrubDaemon { success in
                if success {
                    print("✅ Scrub daemon removed successfully")
                } else {
                    print("⚠️ Failed to remove scrub daemon")
                }
            }
        }
    }

    private func updateTRIMSchedule() {
        UserDefaults.standard.set(trimEnabled, forKey: "trimEnabled")
        UserDefaults.standard.set(trimFrequency, forKey: "trimFrequency")
        UserDefaults.standard.set(trimDayOfWeek, forKey: "trimDayOfWeek")
        UserDefaults.standard.set(trimHour, forKey: "trimHour")

        if trimEnabled {
            installTRIMDaemon { success in
                if success {
                    print("✅ TRIM daemon installed successfully")
                } else {
                    print("❌ Failed to install TRIM daemon")
                    DispatchQueue.main.async {
                        self.trimEnabled = false
                    }
                }
            }
        } else {
            removeTRIMDaemon { success in
                if success {
                    print("✅ TRIM daemon removed successfully")
                } else {
                    print("⚠️ Failed to remove TRIM daemon")
                }
            }
        }
    }

    private func nextScrubDate() -> String {
        // TODO: Calculate next run date based on schedule
        return "Not scheduled"
    }

    private func nextTRIMDate() -> String {
        // TODO: Calculate next run date based on schedule
        return "Not scheduled"
    }

    private func runScrubNow(pool: String) {
        print("🔍 Running scrub on pool: \(pool)")
        let helper = PrivilegedHelperManager.shared
        helper.executeCommand(command: "scrub_pool:\(pool)") { success, output, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Scrub started on \(pool)")
                    self.showAlert(title: "Scrub Started", message: "Scrub operation started on pool '\(pool)'.\n\nYou can check progress with:\nzpool status \(pool)")
                } else {
                    print("❌ Failed to start scrub: \(error ?? "unknown")")
                    self.showAlert(title: "Scrub Failed", message: "Failed to start scrub on '\(pool)':\n\n\(error ?? "unknown")")
                }
                self.refreshPools()
            }
        }
    }

    private func runTRIMNow(pool: String) {
        print("✂️ Running TRIM on pool: \(pool)")
        let helper = PrivilegedHelperManager.shared
        helper.executeCommand(command: "trim_pool:\(pool)") { success, output, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ TRIM started on \(pool)")
                    self.showAlert(title: "TRIM Started", message: "TRIM operation started on pool '\(pool)'.\n\nYou can check progress with:\nzpool status -t \(pool)")
                } else {
                    print("❌ Failed to start TRIM: \(error ?? "unknown")")
                    self.showAlert(title: "TRIM Failed", message: "Failed to start TRIM on '\(pool)':\n\n\(error ?? "unknown")")
                }
                self.refreshPools()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - LaunchDaemon Management

    private func installScrubDaemon(completion: @escaping (Bool) -> Void) {
        let plistContent = createScrubPlist()
        let plistPath = "/Library/LaunchDaemons/org.openzfs.automount.scrub.plist"

        installDaemon(plistContent: plistContent, plistPath: plistPath, completion: completion)
    }

    private func removeScrubDaemon(completion: @escaping (Bool) -> Void) {
        let plistPath = "/Library/LaunchDaemons/org.openzfs.automount.scrub.plist"
        removeDaemon(plistPath: plistPath, completion: completion)
    }

    private func installTRIMDaemon(completion: @escaping (Bool) -> Void) {
        let plistContent = createTRIMPlist()
        let plistPath = "/Library/LaunchDaemons/org.openzfs.automount.trim.plist"

        installDaemon(plistContent: plistContent, plistPath: plistPath, completion: completion)
    }

    private func removeTRIMDaemon(completion: @escaping (Bool) -> Void) {
        let plistPath = "/Library/LaunchDaemons/org.openzfs.automount.trim.plist"
        removeDaemon(plistPath: plistPath, completion: completion)
    }

    private func installDaemon(plistContent: String, plistPath: String, completion: @escaping (Bool) -> Void) {
        // Write plist to temporary location
        let tempPath = NSTemporaryDirectory() + "temp-daemon.plist"
        do {
            try plistContent.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to write temp plist: \(error)")
            completion(false)
            return
        }

        // Use AppleScript to copy with admin privileges
        let script = """
        do shell script "cp '\(tempPath)' '\(plistPath)' && chmod 644 '\(plistPath)' && chown root:wheel '\(plistPath)' && launchctl load '\(plistPath)'" with administrator privileges
        """

        executeAppleScript(script: script) { success in
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempPath)
            completion(success)
        }
    }

    private func removeDaemon(plistPath: String, completion: @escaping (Bool) -> Void) {
        let script = """
        do shell script "launchctl unload '\(plistPath)' 2>/dev/null; rm -f '\(plistPath)'" with administrator privileges
        """

        executeAppleScript(script: script, completion: completion)
    }

    private func executeAppleScript(script: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if let error = error {
                    let errorCode = error["NSAppleScriptErrorNumber"] as? Int
                    if errorCode == -128 {
                        print("⚠️ User cancelled administrator authentication")
                    } else {
                        print("❌ AppleScript error: \(error)")
                    }
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    private func createScrubPlist() -> String {
        let appPath = Bundle.main.bundlePath + "/Contents/MacOS/ZFSAutoMount"
        let interval = createCalendarInterval(frequency: scrubFrequency, dayOfWeek: scrubDayOfWeek, hour: scrubHour)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>org.openzfs.automount.scrub</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)</string>
                <string>--run-scrub</string>
            </array>
            <key>StartCalendarInterval</key>
            \(interval)
            <key>StandardOutPath</key>
            <string>/var/log/zfs-scrub.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/zfs-scrub-error.log</string>
        </dict>
        </plist>
        """
    }

    private func createTRIMPlist() -> String {
        let appPath = Bundle.main.bundlePath + "/Contents/MacOS/ZFSAutoMount"
        let interval = createCalendarInterval(frequency: trimFrequency, dayOfWeek: trimDayOfWeek, hour: trimHour)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>org.openzfs.automount.trim</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)</string>
                <string>--run-trim</string>
            </array>
            <key>StartCalendarInterval</key>
            \(interval)
            <key>StandardOutPath</key>
            <string>/var/log/zfs-trim.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/zfs-trim-error.log</string>
        </dict>
        </plist>
        """
    }

    private func createCalendarInterval(frequency: String, dayOfWeek: Int, hour: Int) -> String {
        switch frequency {
        case "daily":
            return """
            <dict>
                <key>Hour</key>
                <integer>\(hour)</integer>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
            """
        case "weekly":
            return """
            <dict>
                <key>Weekday</key>
                <integer>\(dayOfWeek)</integer>
                <key>Hour</key>
                <integer>\(hour)</integer>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
            """
        case "monthly":
            return """
            <dict>
                <key>Day</key>
                <integer>1</integer>
                <key>Hour</key>
                <integer>\(hour)</integer>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
            """
        case "quarterly":
            // Create array of intervals for Jan, Apr, Jul, Oct
            return """
            <array>
                <dict>
                    <key>Month</key>
                    <integer>1</integer>
                    <key>Day</key>
                    <integer>1</integer>
                    <key>Hour</key>
                    <integer>\(hour)</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                </dict>
                <dict>
                    <key>Month</key>
                    <integer>4</integer>
                    <key>Day</key>
                    <integer>1</integer>
                    <key>Hour</key>
                    <integer>\(hour)</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                </dict>
                <dict>
                    <key>Month</key>
                    <integer>7</integer>
                    <key>Day</key>
                    <integer>1</integer>
                    <key>Hour</key>
                    <integer>\(hour)</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                </dict>
                <dict>
                    <key>Month</key>
                    <integer>10</integer>
                    <key>Day</key>
                    <integer>1</integer>
                    <key>Hour</key>
                    <integer>\(hour)</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                </dict>
            </array>
            """
        default:
            return "<dict></dict>"
        }
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("ZFSAutoMount")
                .font(.title)
                .bold()

            Text("Version 0.1.0")
                .foregroundColor(.secondary)

            Text("Automatic mounting and encryption key management for OpenZFS on macOS")
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            Link("OpenZFS on macOS", destination: URL(string: "https://openzfsonosx.org")!)

            Text("© 2025")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PreferencesView()
}
