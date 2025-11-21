import Foundation
import Security

/// Service for securely storing and retrieving sensitive data in the macOS Keychain
final class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    private let service = "com.slideshowbuddy.Electric-Slideshow"
    
    // MARK: - Save
    
    func save<T: Codable>(_ item: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    // MARK: - Retrieve
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
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
            throw KeychainError.retrieveFailed(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        let decoder = JSONDecoder()
        let item = try decoder.decode(type, from: data)
        return item
    }
    
    // MARK: - Delete
    
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain. Status: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain. Status: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain. Status: \(status)"
        case .invalidData:
            return "Invalid data retrieved from Keychain"
        }
    }
}
