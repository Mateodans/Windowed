import Foundation
import Security

public enum KeychainHelper {
    public enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case notFound
        case encodingError
    }
    
    public static func save(secret: Data, for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: secret
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }
    
    public static func retrieve(for account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }
        
        return data
    }
    
    public static func delete(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    public static func hasSecret(for account: String) -> Bool {
        (try? retrieve(for: account)) != nil
    }
}
