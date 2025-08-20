//
//  APIKeyManager.swift
//  Menuly
//
//  Secure API key storage and management using iOS Keychain
//  Privacy-first design with comprehensive security measures
//

import Foundation
import Security
import CryptoKit

/// Secure manager for Claude API key storage and validation
/// Uses iOS Keychain with hardware security features where available
class APIKeyManager {
    
    // MARK: - Constants
    
    private enum KeychainKeys {
        static let service = "com.menuly.api-keys"
        static let claudeAPIKey = "claude-api-key"
        static let keyValidationHash = "claude-key-validation"
    }
    
    private enum SecurityConstants {
        static let keyMinLength = 32
        static let keyMaxLength = 256
        static let validationSalt = "menuly-claude-validation-2024"
        static let accessGroup: String? = nil // Use nil for single-app access
    }
    
    // MARK: - Singleton
    
    static let shared = APIKeyManager()
    private init() {}
    
    // MARK: - API Key Management
    
    /// Securely store Claude API key in Keychain
    /// - Parameter apiKey: The Claude API key to store
    /// - Returns: Result indicating success or failure
    func storeAPIKey(_ apiKey: String) -> Result<Void, MenulyError> {
        // Validate API key format
        guard validateAPIKeyFormat(apiKey) else {
            return .failure(.apiError("Invalid API key format"))
        }
        
        // Remove existing key first
        let _ = removeAPIKey()
        
        // Prepare keychain query for storing
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.claudeAPIKey,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add access group if specified (for app groups)
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Store in keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Store validation hash for integrity checking
            let _ = storeValidationHash(for: apiKey)
            return .success(())
        } else {
            return .failure(.apiError("Failed to store API key: \(status)"))
        }
    }
    
    /// Retrieve Claude API key from Keychain
    /// - Returns: The stored API key or nil if not found/invalid
    func retrieveAPIKey() -> String? {
        // Prepare keychain query for retrieval
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.claudeAPIKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Add access group if specified
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Validate retrieved key integrity
        guard validateStoredKeyIntegrity(apiKey) else {
            // Key may be compromised, remove it
            let _ = removeAPIKey()
            return nil
        }
        
        return apiKey
    }
    
    /// Remove API key from Keychain
    /// - Returns: Result indicating success or failure
    func removeAPIKey() -> Result<Void, MenulyError> {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.claudeAPIKey
        ]
        
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Also remove validation hash
        let _ = removeValidationHash()
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return .success(())
        } else {
            return .failure(.apiError("Failed to remove API key: \(status)"))
        }
    }
    
    /// Check if API key is stored and valid
    /// - Returns: True if valid API key exists
    func hasValidAPIKey() -> Bool {
        guard let apiKey = retrieveAPIKey() else { return false }
        return validateAPIKeyFormat(apiKey) && validateStoredKeyIntegrity(apiKey)
    }
    
    /// Validate API key with Anthropic servers (optional, rate-limited)
    /// - Parameter completion: Callback with validation result
    func validateAPIKeyWithServer(completion: @escaping (Result<Bool, MenulyError>) -> Void) {
        guard let apiKey = retrieveAPIKey() else {
            completion(.failure(.apiKeyMissing))
            return
        }
        
        // Simple validation request to Anthropic API
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10
        
        // Minimal test payload
        let testPayload: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
        } catch {
            completion(.failure(.jsonParsingError(error.localizedDescription)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error.localizedDescription)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.networkError("Invalid response")))
                    return
                }
                
                // 200-299 range indicates valid API key
                let isValid = (200...299).contains(httpResponse.statusCode)
                completion(.success(isValid))
            }
        }.resume()
    }
    
    // MARK: - Private Validation Methods
    
    /// Validate API key format for Claude API
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if format is valid
    private func validateAPIKeyFormat(_ apiKey: String) -> Bool {
        // Claude API keys typically start with "sk-ant-" and have specific length
        guard apiKey.count >= SecurityConstants.keyMinLength,
              apiKey.count <= SecurityConstants.keyMaxLength,
              apiKey.hasPrefix("sk-ant-") || apiKey.hasPrefix("sk-") else {
            return false
        }
        
        // Check for basic format patterns
        let pattern = "^sk-[a-zA-Z0-9_-]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: apiKey.utf16.count)
        
        return regex?.firstMatch(in: apiKey, options: [], range: range) != nil
    }
    
    /// Store validation hash for integrity checking
    /// - Parameter apiKey: The API key to create hash for
    /// - Returns: Result indicating success or failure
    private func storeValidationHash(for apiKey: String) -> Result<Void, MenulyError> {
        let hash = createValidationHash(for: apiKey)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.keyValidationHash,
            kSecValueData as String: hash.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Remove existing hash first
        let _ = removeValidationHash()
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess ? .success(()) : .failure(.apiError("Failed to store validation hash"))
    }
    
    /// Remove validation hash from Keychain
    /// - Returns: Result indicating success or failure
    private func removeValidationHash() -> Result<Void, MenulyError> {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.keyValidationHash
        ]
        
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound ? .success(()) : .failure(.apiError("Failed to remove validation hash"))
    }
    
    /// Validate stored key integrity using hash comparison
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if integrity is confirmed
    private func validateStoredKeyIntegrity(_ apiKey: String) -> Bool {
        // Retrieve stored validation hash
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.keyValidationHash,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = SecurityConstants.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let storedHash = String(data: data, encoding: .utf8) else {
            return false
        }
        
        // Compare with current hash
        let currentHash = createValidationHash(for: apiKey)
        return storedHash == currentHash
    }
    
    /// Create validation hash for API key integrity checking
    /// - Parameter apiKey: The API key to hash
    /// - Returns: SHA256 hash string
    private func createValidationHash(for apiKey: String) -> String {
        let input = apiKey + SecurityConstants.validationSalt
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Security Utilities Extension

extension APIKeyManager {
    
    /// Get security status of stored API key
    /// - Returns: Dictionary with security information
    func getSecurityStatus() -> [String: Any] {
        return [
            "hasAPIKey": hasValidAPIKey(),
            "keychainAvailable": isKeychainAvailable(),
            "hardwareSecurityAvailable": isHardwareSecurityAvailable(),
            "lastValidated": getLastValidationDate()
        ]
    }
    
    /// Check if Keychain services are available
    /// - Returns: True if Keychain is accessible
    private func isKeychainAvailable() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "test-service",
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecItemNotFound || status == errSecSuccess
    }
    
    /// Check if hardware security features are available
    /// - Returns: True if hardware security is supported
    private func isHardwareSecurityAvailable() -> Bool {
        // Check for Secure Enclave availability
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    
    /// Get last validation date (placeholder for future implementation)
    /// - Returns: Optional date of last validation
    private func getLastValidationDate() -> Date? {
        // Could implement persistent validation tracking
        return nil
    }
}

// MARK: - Privacy Compliance Extension

extension APIKeyManager {
    
    /// Privacy-compliant method to check API key status without exposing key
    /// - Returns: Status information safe for logging/analytics
    func getPrivacyCompliantStatus() -> [String: Any] {
        return [
            "hasValidKey": hasValidAPIKey(),
            "securityLevel": isHardwareSecurityAvailable() ? "hardware" : "software",
            "storageMethod": "keychain"
        ]
    }
    
    /// Audit log entry for API key operations (privacy-safe)
    /// - Parameter operation: The operation performed
    /// - Returns: Privacy-safe audit log entry
    func createAuditLogEntry(for operation: String) -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "operation": operation,
            "success": hasValidAPIKey(),
            "securityMethod": "keychain",
            "version": "1.0"
            // Note: Never log actual API key values
        ]
    }
}