import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    private let service = Constants.Keychain.service

    private init() {}

    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedStatus(OSStatus)
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(key: key, value: value)
        } else if status != errSecSuccess {
            Log.keychain.error("Failed to save keychain item: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        } else {
            Log.keychain.info("Saved keychain item: \(key)")
        }
    }

    func load(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            Log.keychain.error("Failed to load keychain item: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            Log.keychain.error("Failed to delete keychain item: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        } else {
            Log.keychain.info("Deleted keychain item: \(key)")
        }
    }

    private func update(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            Log.keychain.error("Failed to update keychain item: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        Log.keychain.info("Updated keychain item: \(key)")
    }
}
