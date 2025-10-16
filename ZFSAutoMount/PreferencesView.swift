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
        autoImportOnBoot = UserDefaults.standard.bool(forKey: "autoImportOnBoot")
        autoMountOnBoot = UserDefaults.standard.bool(forKey: "autoMountOnBoot")
        showNotifications = UserDefaults.standard.bool(forKey: "showNotifications")
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
                    .onChange(of: autoImportOnBoot) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoImportOnBoot")
                    }

                Toggle("Auto-mount datasets on boot", isOn: $autoMountOnBoot)
                    .onChange(of: autoMountOnBoot) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "autoMountOnBoot")
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
}

struct EncryptionTab: View {
    @Binding var savedKeys: [String]
    private let keychainHelper = KeychainHelper.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved Encryption Keys")
                .font(.headline)

            if savedKeys.isEmpty {
                Text("No encryption keys saved in keychain")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(savedKeys, id: \.self) { dataset in
                        HStack {
                            Image(systemName: "key.fill")
                            Text(dataset)
                            Spacer()
                            Button("Delete") {
                                deleteKey(for: dataset)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }

            Text("Keys are stored securely in macOS Keychain")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func deleteKey(for dataset: String) {
        let alert = NSAlert()
        alert.messageText = "Delete Key"
        alert.informativeText = "Are you sure you want to delete the encryption key for \(dataset)?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            keychainHelper.deleteKey(for: dataset)
            savedKeys = keychainHelper.listAllKeys()
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
