// PURPOSE:
//   Secure storage for the API key and server URL.
//   Uses iOS Keychain — encrypted, not backed up to iCloud,
//   only accessible when device is unlocked.
//
// USAGE:
//   try KeychainManager.save("my-key", for: .apiKey)
//   let key = KeychainManager.load(.apiKey)
//   KeychainManager.delete(.apiKey)

import Foundation
import Security

enum KeychainKey: String {
    case apiKey  = "com.devsignal.apiKey"
    case baseURL = "com.devsignal.baseURL"
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed
    case deleteFailed(OSStatus)
}

final class KeychainManager {

    // ── Save ──────────────────────────────────────────────────────────────

    static func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete any existing value first to avoid duplicate item error
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add the new value
        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key.rawValue,
            kSecValueData as String:        data,
            // Only accessible when device is unlocked
            // NOT backed up to iCloud — appropriate for API credentials
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // ── Load ──────────────────────────────────────────────────────────────

    static func load(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // ── Delete ────────────────────────────────────────────────────────────

    static func delete(_ key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // ── Clear all DevSignal credentials ───────────────────────────────────

    static func clearAll() {
        try? delete(.apiKey)
        try? delete(.baseURL)
    }
}
