import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "org.openzfs.automount"

    private init() {}

    // MARK: - Save Key

    func saveKey(_ key: String, for dataset: String) {
        guard let keyData = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: dataset,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Failed to save key to keychain: \(status)")
        }
    }

    // MARK: - Get Key

    func getKey(for dataset: String) -> String? {
        // Try user keychain first (when logged in)
        if let key = getKeyFromKeychain(dataset: dataset, useSystemKeychain: false) {
            return key
        }

        // Fallback to system keychain (for boot-time access)
        if let key = getKeyFromKeychain(dataset: dataset, useSystemKeychain: true) {
            return key
        }

        return nil
    }

    private func getKeyFromKeychain(dataset: String, useSystemKeychain: Bool) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: dataset,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add system keychain path if needed
        if useSystemKeychain {
            let systemKeychain = "/Library/Keychains/System.keychain"
            if let keychainRef = openSystemKeychain(systemKeychain) {
                query[kSecMatchSearchList as String] = [keychainRef] as CFArray
            }
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data,
              let key = String(data: keyData, encoding: .utf8) else {
            return nil
        }

        return key
    }

    // Helper to open system keychain
    private func openSystemKeychain(_ path: String) -> SecKeychain? {
        var keychain: SecKeychain?
        let status = Security.SecKeychainOpen(path, &keychain)
        return status == errSecSuccess ? keychain : nil
    }

    // MARK: - Delete Key

    func deleteKey(for dataset: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: dataset
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - List All Keys

    func listAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
