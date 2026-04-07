import Foundation
import Security

struct AppleKeychainService: KeychainService {
    private let service = "com.appi.keychain"

    nonisolated func save(_ data: Data, for key: String) throws {
        try? delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PersistenceError.saveFailed(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
    }

    nonisolated func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw PersistenceError.fetchFailed(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }

        return result as? Data
    }

    nonisolated func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.saveFailed(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
    }
}
