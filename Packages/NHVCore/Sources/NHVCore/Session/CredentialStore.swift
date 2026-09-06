import Foundation
import Security

@MainActor
public protocol CredentialStore {
    func load() throws -> APIKey?
    func save(_ key: APIKey) throws
    func delete() throws
}

public enum CredentialError: Error, Sendable, Equatable {
    case status(OSStatus)
    case invalidData
}

@MainActor
public struct KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account = "api-key"

    public init(service: String = "local.nhv.reader") { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func load() throws -> APIKey? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialError.status(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8),
              let key = try? APIKey(value) else { throw CredentialError.invalidData }
        return key
    }

    public func save(_ key: APIKey) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CredentialError.status(status) }
    }

    public func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.status(status) }
    }
}
