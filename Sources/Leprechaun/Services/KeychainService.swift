import Foundation
import Security
import AppKit

/// Stores and retrieves SMB credentials in the macOS Keychain.
enum KeychainService {

    /// A credential pair for an SMB share.
    struct SMBContext: Equatable {
        let server: String      // e.g. "nas.local" or "192.168.1.100"
        let share: String       // e.g. "backups"
        let username: String
        let password: String

        /// The keychain service name for this context.
        var serviceKey: String {
            "smb://\(username)@\(server)/\(share)"
        }
    }

    // MARK: - Save

    static func saveCredentials(_ context: SMBContext) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: context.server,
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecAttrAccount as String: context.username,
            kSecAttrLabel as String: context.serviceKey,
            kSecAttrDescription as String: "Leprechaun SMB credentials",
            kSecValueData as String: context.password.data(using: .utf8) ?? Data(),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Try to add; if already exists, update
        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: context.password.data(using: .utf8) ?? Data(),
            ]
            let match: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecAttrServer as String: context.server,
                kSecAttrAccount as String: context.username,
            ]
            status = SecItemUpdate(match as CFDictionary, update as CFDictionary)
        }

        return status == errSecSuccess || status == errSecDuplicateItem
    }

    // MARK: - Retrieve

    static func loadCredentials(server: String, username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: username,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    static func deleteCredentials(server: String, username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: username,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }

    // MARK: - Helper

    /// Prompts the user to mount an SMB share in Finder.
    /// This lets Finder handle credential entry and Keychain storage.
    static func promptMountInFinder(server: String, share: String) {
        let url = URL(string: "smb://\(server)/\(share)") ?? URL(string: "smb://\(server)")!
        NSWorkspace.shared.open(url)
    }
}
