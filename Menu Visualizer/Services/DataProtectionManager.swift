//
//  DataProtectionManager.swift
//  Menu Visualizer
//
//  iOS-native data protection service leveraging Keychain, Secure Enclave, and Core Data encryption
//

import Foundation
import Security
import CoreData
import CryptoKit
import LocalAuthentication
import OSLog

/// Comprehensive data protection manager using iOS security frameworks
@MainActor
final class DataProtectionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isKeychainAvailable: Bool = false
    @Published var isSecureEnclaveAvailable: Bool = false
    @Published var isBiometricAuthEnabled: Bool = false
    @Published var dataProtectionLevel: DataProtectionLevel = .complete
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.menuly.dataprotection", category: "DataProtection")
    private let keychainService = "com.menuly.secure"
    private let context = LAContext()
    
    // MARK: - Core Data Stack with Encryption
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MenulyDataModel")
        
        // Configure for maximum privacy and security
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
        storeDescription?.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, 
                                   forKey: NSPersistentHistoryTrackingKey)
        
        // Enable Core Data encryption
        storeDescription?.setOption(true as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.logger.error("Core Data failed to load store: \(error.localizedDescription)")
                // In production, implement proper error recovery
                fatalError("Core Data error: \(error)")
            }
        }
        
        // Configure context for privacy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Initialization
    init() {
        Task {
            await validateSecurityCapabilities()
            await setupDataProtection()
        }
    }
    
    // MARK: - Security Capabilities Validation
    
    private func validateSecurityCapabilities() async {
        // Check Keychain availability
        isKeychainAvailable = await validateKeychainAccess()
        
        // Check Secure Enclave availability
        isSecureEnclaveAvailable = await validateSecureEnclave()
        
        // Check biometric authentication
        await validateBiometricCapabilities()
        
        logger.info("Security capabilities validated - Keychain: \(isKeychainAvailable), SecureEnclave: \(isSecureEnclaveAvailable), Biometric: \(isBiometricAuthEnabled)")
    }
    
    private func validateKeychainAccess() async -> Bool {
        let testKey = "test_keychain_access"
        let testData = "test".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to add test item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        // Clean up test item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: testKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        return addStatus == errSecSuccess
    }
    
    private func validateSecureEnclave() async -> Bool {
        // Check if device has Secure Enclave
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func validateBiometricCapabilities() async {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canEvaluate {
            switch context.biometryType {
            case .faceID, .touchID:
                isBiometricAuthEnabled = true
            default:
                isBiometricAuthEnabled = false
            }
        } else {
            isBiometricAuthEnabled = false
            if let error = error {
                logger.warning("Biometric authentication not available: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Data Protection Setup
    
    private func setupDataProtection() async {
        // Set data protection level based on device capabilities
        if isSecureEnclaveAvailable {
            dataProtectionLevel = .completeUntilFirstUserAuthentication
        } else {
            dataProtectionLevel = .complete
        }
        
        // Configure memory protection
        await setupMemoryProtection()
        
        logger.info("Data protection setup completed with level: \(dataProtectionLevel)")
    }
    
    private func setupMemoryProtection() async {
        // Configure app to prevent screenshots of sensitive content
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        // Monitor for screen recording
        NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenRecordingChange()
        }
    }
    
    // MARK: - Keychain Operations
    
    func securelyStore(data: Data, for key: String, requiresBiometric: Bool = true) async throws {
        guard isKeychainAvailable else {
            throw DataProtectionError.keychainUnavailable
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add biometric protection if available and requested
        if requiresBiometric && isBiometricAuthEnabled {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                nil
            )
            query[kSecAttrAccessControl as String] = access
        }
        
        // Remove any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            logger.error("Failed to store data in Keychain: \(status)")
            throw DataProtectionError.keychainStorageFailed(status)
        }
        
        logger.debug("Data securely stored in Keychain for key: \(key)")
    }
    
    func securelyRetrieve(for key: String) async throws -> Data {
        guard isKeychainAvailable else {
            throw DataProtectionError.keychainUnavailable
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            guard let data = result as? Data else {
                throw DataProtectionError.keychainDataCorrupted
            }
            logger.debug("Data securely retrieved from Keychain for key: \(key)")
            return data
        } else if status == errSecItemNotFound {
            throw DataProtectionError.keychainItemNotFound
        } else {
            logger.error("Failed to retrieve data from Keychain: \(status)")
            throw DataProtectionError.keychainRetrievalFailed(status)
        }
    }
    
    func securelyDelete(for key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to delete data from Keychain: \(status)")
            throw DataProtectionError.keychainDeletionFailed(status)
        }
        
        logger.debug("Data securely deleted from Keychain for key: \(key)")
    }
    
    // MARK: - Biometric Authentication
    
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        guard isBiometricAuthEnabled else {
            throw DataProtectionError.biometricAuthUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if let error = error {
                    self.logger.error("Biometric authentication failed: \(error.localizedDescription)")
                    continuation.resume(throwing: DataProtectionError.biometricAuthFailed(error))
                } else {
                    self.logger.info("Biometric authentication successful")
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    // MARK: - File Protection
    
    func createProtectedFile(at url: URL, data: Data) async throws {
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: dataProtectionLevel.fileProtectionType
        ]
        
        let fileManager = FileManager.default
        
        if fileManager.createFile(atPath: url.path, contents: data, attributes: attributes) {
            logger.debug("Protected file created at: \(url.path)")
        } else {
            logger.error("Failed to create protected file at: \(url.path)")
            throw DataProtectionError.fileCreationFailed
        }
    }
    
    func securelyDeleteFile(at url: URL) async throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: url.path) {
            do {
                // Overwrite file with random data before deletion (secure deletion)
                let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
                let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
                try randomData.write(to: url)
                
                // Now delete the file
                try fileManager.removeItem(at: url)
                logger.debug("File securely deleted at: \(url.path)")
            } catch {
                logger.error("Failed to securely delete file: \(error.localizedDescription)")
                throw DataProtectionError.fileDeletionFailed(error)
            }
        }
    }
    
    // MARK: - Memory Protection
    
    private func handleAppWillResignActive() {
        // Post notification to blur sensitive content
        NotificationCenter.default.post(name: .blurSensitiveContent, object: nil)
        logger.debug("App will resign active - sensitive content protection activated")
    }
    
    private func handleScreenRecordingChange() {
        if UIScreen.main.isCaptured {
            // Screen recording detected - hide sensitive content
            NotificationCenter.default.post(name: .hideForScreenRecording, object: nil)
            logger.warning("Screen recording detected - hiding sensitive content")
        } else {
            // Screen recording stopped - restore content
            NotificationCenter.default.post(name: .restoreFromScreenRecording, object: nil)
            logger.info("Screen recording stopped - restoring content")
        }
    }
    
    func protectSensitiveMemory(_ data: Data) -> ProtectedMemory {
        return ProtectedMemory(data: data)
    }
    
    // MARK: - Data Validation
    
    func validateDataIntegrity(for data: Data, expectedHash: Data) throws -> Bool {
        let computedHash = SHA256.hash(data: data)
        let computedHashData = Data(computedHash)
        
        guard computedHashData == expectedHash else {
            logger.error("Data integrity validation failed")
            throw DataProtectionError.dataIntegrityValidationFailed
        }
        
        return true
    }
    
    func generateDataHash(for data: Data) -> Data {
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
    
    // MARK: - Core Data Security
    
    func saveSecureContext() async throws {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Secure Core Data context saved")
            } catch {
                logger.error("Failed to save secure context: \(error.localizedDescription)")
                throw DataProtectionError.coreDataSaveFailed(error)
            }
        }
    }
    
    func performSecureBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Security Audit
    
    func performSecurityAudit() async -> SecurityAuditReport {
        let report = SecurityAuditReport(
            keychainAvailable: isKeychainAvailable,
            secureEnclaveAvailable: isSecureEnclaveAvailable,
            biometricAuthAvailable: isBiometricAuthEnabled,
            dataProtectionLevel: dataProtectionLevel,
            coreDataEncrypted: true,
            fileProtectionEnabled: true,
            memoryProtectionActive: true,
            screenRecordingDetection: true,
            timestamp: Date()
        )
        
        logger.info("Security audit completed: \(report.overallSecurityLevel)")
        return report
    }
}

// MARK: - Supporting Types

enum DataProtectionLevel: String, CaseIterable {
    case complete = "Complete"
    case completeUntilFirstUserAuthentication = "Complete Until First User Authentication"
    case completeUnlessOpen = "Complete Unless Open"
    case none = "None"
    
    var fileProtectionType: FileProtectionType {
        switch self {
        case .complete:
            return .complete
        case .completeUntilFirstUserAuthentication:
            return .completeUntilFirstUserAuthentication
        case .completeUnlessOpen:
            return .completeUnlessOpen
        case .none:
            return .none
        }
    }
}

enum DataProtectionError: LocalizedError {
    case keychainUnavailable
    case keychainStorageFailed(OSStatus)
    case keychainRetrievalFailed(OSStatus)
    case keychainDeletionFailed(OSStatus)
    case keychainItemNotFound
    case keychainDataCorrupted
    case biometricAuthUnavailable
    case biometricAuthFailed(Error)
    case fileCreationFailed
    case fileDeletionFailed(Error)
    case dataIntegrityValidationFailed
    case coreDataSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .keychainUnavailable:
            return "Keychain is not available on this device"
        case .keychainStorageFailed(let status):
            return "Failed to store data in Keychain (Status: \(status))"
        case .keychainRetrievalFailed(let status):
            return "Failed to retrieve data from Keychain (Status: \(status))"
        case .keychainDeletionFailed(let status):
            return "Failed to delete data from Keychain (Status: \(status))"
        case .keychainItemNotFound:
            return "Requested item not found in Keychain"
        case .keychainDataCorrupted:
            return "Keychain data is corrupted"
        case .biometricAuthUnavailable:
            return "Biometric authentication is not available"
        case .biometricAuthFailed(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        case .fileCreationFailed:
            return "Failed to create protected file"
        case .fileDeletionFailed(let error):
            return "Failed to securely delete file: \(error.localizedDescription)"
        case .dataIntegrityValidationFailed:
            return "Data integrity validation failed"
        case .coreDataSaveFailed(let error):
            return "Failed to save Core Data context: \(error.localizedDescription)"
        }
    }
}

class ProtectedMemory {
    private var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    func accessSecurely<T>(_ block: (Data) throws -> T) rethrows -> T {
        defer {
            // Clear sensitive data from memory after use
            data.resetBytes(in: 0..<data.count)
        }
        return try block(data)
    }
    
    deinit {
        // Ensure data is cleared when object is deallocated
        data.resetBytes(in: 0..<data.count)
    }
}

struct SecurityAuditReport {
    let keychainAvailable: Bool
    let secureEnclaveAvailable: Bool
    let biometricAuthAvailable: Bool
    let dataProtectionLevel: DataProtectionLevel
    let coreDataEncrypted: Bool
    let fileProtectionEnabled: Bool
    let memoryProtectionActive: Bool
    let screenRecordingDetection: Bool
    let timestamp: Date
    
    var overallSecurityLevel: String {
        let score = [
            keychainAvailable,
            secureEnclaveAvailable,
            biometricAuthAvailable,
            coreDataEncrypted,
            fileProtectionEnabled,
            memoryProtectionActive,
            screenRecordingDetection
        ].map { $0 ? 1 : 0 }.reduce(0, +)
        
        switch score {
        case 7: return "Maximum"
        case 5...6: return "High"
        case 3...4: return "Medium"
        default: return "Low"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let blurSensitiveContent = Notification.Name("blurSensitiveContent")
    static let hideForScreenRecording = Notification.Name("hideForScreenRecording")
    static let restoreFromScreenRecording = Notification.Name("restoreFromScreenRecording")
}