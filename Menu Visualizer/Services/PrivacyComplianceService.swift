//
//  PrivacyComplianceService.swift
//  Menu Visualizer
//
//  Enhanced privacy-first compliance service with iOS security framework integration
//

import Foundation
import SwiftUI
import OSLog
import CryptoKit
import LocalAuthentication
import Network

/// Enhanced service managing comprehensive privacy compliance and data protection
@MainActor
final class PrivacyComplianceService: ObservableObject {
    @Published var privacySettings: PrivacySettings
    @Published var dataRetentionStatus: DataRetentionStatus
    @Published var apiCallsCount: Int = 0
    @Published var lastDataClearTime: Date?
    @Published var privacyViolations: [PrivacyViolation] = []
    @Published var complianceScore: Double = 1.0
    @Published var isPrivacyManifestValid: Bool = true
    
    private let logger = Logger(subsystem: "com.menuly.privacy", category: "Compliance")
    private let userDefaults = UserDefaults.standard
    private let dataProtectionManager: DataProtectionManager
    private let consentManager: ConsentManager
    private let networkMonitor = NWPathMonitor()
    private let auditQueue = DispatchQueue(label: "privacy.audit", qos: .utility)
    
    // MARK: - Data Retention Status
    
    struct DataRetentionStatus {
        var hasTemporaryImages: Bool
        var hasOCRResults: Bool
        var hasMenuData: Bool
        var hasCachedAPIResponses: Bool
        var estimatedMemoryUsage: UInt64
        var encryptedDataCount: Int
        var keychainItemsCount: Int
        var protectedFilesCount: Int
        var lastSecurityAudit: Date?
        
        var hasAnyData: Bool {
            hasTemporaryImages || hasOCRResults || hasMenuData || hasCachedAPIResponses
        }
        
        var securityLevel: SecurityLevel {
            if encryptedDataCount > 0 && keychainItemsCount > 0 {
                return .high
            } else if encryptedDataCount > 0 || keychainItemsCount > 0 {
                return .medium
            } else {
                return .low
            }
        }
    }
    
    // MARK: - Constants
    
    private enum Keys {
        static let privacySettings = "menuly_privacy_settings"
        static let apiCallsCount = "menuly_api_calls_count"
        static let lastDataClear = "menuly_last_data_clear"
        static let firstLaunch = "menuly_first_launch"
    }
    
    // MARK: - Initialization
    
    init(dataProtectionManager: DataProtectionManager, 
         consentManager: ConsentManager) {
        self.dataProtectionManager = dataProtectionManager
        self.consentManager = consentManager
        
        // Initialize properties first
        let needsToSaveSettings: Bool
        
        // Load privacy settings
        if let data = userDefaults.data(forKey: Keys.privacySettings),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            self.privacySettings = settings
            needsToSaveSettings = false
        } else {
            self.privacySettings = .default
            needsToSaveSettings = true
        }
        
        // Load other persistent data
        self.apiCallsCount = userDefaults.integer(forKey: Keys.apiCallsCount)
        self.lastDataClearTime = userDefaults.object(forKey: Keys.lastDataClear) as? Date
        
        // Initialize enhanced data retention status
        self.dataRetentionStatus = DataRetentionStatus(
            hasTemporaryImages: false,
            hasOCRResults: false,
            hasMenuData: false,
            hasCachedAPIResponses: false,
            estimatedMemoryUsage: 0,
            encryptedDataCount: 0,
            keychainItemsCount: 0,
            protectedFilesCount: 0,
            lastSecurityAudit: nil
        )
        
        // Save settings if needed (after all properties are initialized)
        if needsToSaveSettings {
            savePrivacySettings()
        }
        
        // Check if first launch
        if !userDefaults.bool(forKey: Keys.firstLaunch) {
            handleFirstLaunch()
        }
        
        // Set up enhanced privacy framework
        Task {
            await setupEnhancedPrivacyFramework()
        }
        
        logger.info("Enhanced privacy compliance service initialized")
    }
    
    // MARK: - First Launch Handling
    
    private func handleFirstLaunch() {
        logger.info("First launch detected - setting up privacy defaults")
        
        userDefaults.set(true, forKey: Keys.firstLaunch)
        
        // Ensure privacy-first defaults are set
        privacySettings = .default
        savePrivacySettings()
        
        // Clear any potential leftover data
        clearAllDataImmediately()
    }
    
    // MARK: - Privacy Settings Management
    
    func updatePrivacySettings(_ newSettings: PrivacySettings) {
        let oldSettings = privacySettings
        privacySettings = newSettings
        savePrivacySettings()
        
        logger.info("Privacy settings updated: \(newSettings.dataRetentionPolicy.rawValue)")
        
        // Handle policy changes
        if oldSettings.dataRetentionPolicy != newSettings.dataRetentionPolicy {
            handleRetentionPolicyChange(from: oldSettings.dataRetentionPolicy, to: newSettings.dataRetentionPolicy)
        }
    }
    
    private func savePrivacySettings() {
        if let data = try? JSONEncoder().encode(privacySettings) {
            userDefaults.set(data, forKey: Keys.privacySettings)
        }
    }
    
    private func handleRetentionPolicyChange(from oldPolicy: PrivacySettings.DataRetentionPolicy, to newPolicy: PrivacySettings.DataRetentionPolicy) {
        switch (oldPolicy, newPolicy) {
        case (_, .never):
            // Changed to never store - clear all data immediately
            clearAllDataImmediately()
        case (.never, .sessionOnly):
            // Changed from never to session - update cleanup strategy
            setupAutomaticCleanup()
        default:
            break
        }
    }
    
    // MARK: - Data Tracking
    
    func trackImageCapture() {
        updateDataRetentionStatus { status in
            status.hasTemporaryImages = true
        }
        logger.debug("Image capture tracked")
    }
    
    func trackOCRProcessing() {
        updateDataRetentionStatus { status in
            status.hasOCRResults = true
        }
        logger.debug("OCR processing tracked")
    }
    
    func trackMenuExtraction() {
        updateDataRetentionStatus { status in
            status.hasMenuData = true
        }
        logger.debug("Menu extraction tracked")
    }
    
    func trackAPICall() {
        apiCallsCount += 1
        userDefaults.set(apiCallsCount, forKey: Keys.apiCallsCount)
        
        updateDataRetentionStatus { status in
            status.hasCachedAPIResponses = true
        }
        
        logger.debug("API call tracked (total: \(self.apiCallsCount))")
    }
    
    func updateMemoryUsage(_ usage: UInt64) {
        updateDataRetentionStatus { status in
            status.estimatedMemoryUsage = usage
        }
    }
    
    private func updateDataRetentionStatus(_ update: (inout DataRetentionStatus) -> Void) {
        update(&dataRetentionStatus)
    }
    
    // MARK: - Data Clearing
    
    func clearAllDataImmediately() {
        logger.info("Clearing all data immediately")
        
        // Clear in-memory data
        clearMemoryData()
        
        // Clear any temporary files
        clearTemporaryFiles()
        
        // Clear URL session cache
        URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
        
        // Update status
        dataRetentionStatus = DataRetentionStatus(
            hasTemporaryImages: false,
            hasOCRResults: false,
            hasMenuData: false,
            hasCachedAPIResponses: false,
            estimatedMemoryUsage: 0,
            encryptedDataCount: 0,
            keychainItemsCount: 0,
            protectedFilesCount: 0,
            lastSecurityAudit: nil
        )
        
        lastDataClearTime = Date()
        userDefaults.set(lastDataClearTime, forKey: Keys.lastDataClear)
        
        logger.info("Data clearing completed")
    }
    
    private func clearMemoryData() {
        // Post notification for services to clear their data
        NotificationCenter.default.post(name: .clearPrivateData, object: nil)
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                if url.pathExtension == "jpg" || url.pathExtension == "png" {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            logger.error("Failed to clear temporary files: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    func handleAppDidEnterBackground() {
        logger.debug("App entered background - evaluating data retention")
        
        switch privacySettings.dataRetentionPolicy {
        case .never:
            clearAllDataImmediately()
        case .sessionOnly:
            // Data will be cleared when app terminates
            break
        }
    }
    
    func handleAppWillTerminate() {
        logger.info("App will terminate - clearing session data")
        clearAllDataImmediately()
    }
    
    func handleAppDidBecomeActive() {
        logger.debug("App became active - checking data retention compliance")
        
        // Verify no data persists beyond policy
        if privacySettings.dataRetentionPolicy == .never && dataRetentionStatus.hasAnyData {
            logger.warning("Data found despite 'never' retention policy - clearing immediately")
            clearAllDataImmediately()
        }
    }
    
    // MARK: - Automatic Cleanup
    
    private func setupAutomaticCleanup() {
        // Set up cleanup based on privacy settings
        switch privacySettings.dataRetentionPolicy {
        case .never:
            // Clear data after each operation
            break
        case .sessionOnly:
            // Data cleared on app termination (handled in scene delegate)
            break
        }
    }
    
    // MARK: - API Security
    
    func shouldAllowAPICall() -> Bool {
        // Check if we have network permission and API calls are reasonable
        return apiCallsCount < 100 // Basic rate limiting
    }
    
    func getSecureAPIHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        
        // Add privacy-respecting headers
        headers["User-Agent"] = "Menuly/1.0 Privacy-First"
        headers["DNT"] = "1" // Do Not Track
        headers["X-Privacy-Policy"] = "no-data-collection"
        
        return headers
    }
    
    // MARK: - Enhanced Privacy Framework Setup
    
    private func setupEnhancedPrivacyFramework() async {
        await setupNetworkMonitoring()
        await setupSecurityAuditing()
        await validatePrivacyManifest()
        await performInitialComplianceCheck()
        
        logger.info("Enhanced privacy framework setup completed")
    }
    
    private func setupNetworkMonitoring() async {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        let queue = DispatchQueue(label: "network.monitor")
        networkMonitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        // Monitor network for privacy implications
        if path.status == .satisfied {
            if path.isExpensive {
                logger.info("Network is expensive - may affect data processing decisions")
            }
            
            if path.usesInterfaceType(.cellular) {
                logger.debug("Using cellular network - privacy policies apply")
            }
        }
    }
    
    private func setupSecurityAuditing() async {
        // Schedule periodic security audits
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.performSecurityAudit()
            }
        }
    }
    
    private func validatePrivacyManifest() async {
        // Validate privacy manifest compliance
        let manifest = consentManager.generatePrivacyManifest()
        
        // Check if manifest is valid according to iOS 17+ requirements
        isPrivacyManifestValid = validateManifestCompliance(manifest)
        
        if !isPrivacyManifestValid {
            logger.error("Privacy manifest validation failed")
            recordPrivacyViolation(.invalidPrivacyManifest, details: "Privacy manifest does not meet iOS requirements")
        }
    }
    
    private func validateManifestCompliance(_ manifest: PrivacyManifest) -> Bool {
        // Validate key privacy manifest requirements
        let hasValidPrivacyPolicy = !manifest.privacyPolicyURL.isEmpty
        let correctTrackingDeclaration = !manifest.trackingEnabled // Menuly doesn't track
        let appropriateDataDeclaration = !manifest.dataLinkedToUser // Menuly doesn't link data to users
        
        return hasValidPrivacyPolicy && correctTrackingDeclaration && appropriateDataDeclaration
    }
    
    private func performInitialComplianceCheck() async {
        await calculateComplianceScore()
        await auditDataRetention()
        logger.info("Initial compliance check completed - Score: \(self.complianceScore)")
    }
    
    // MARK: - Privacy Violation Management
    
    private func recordPrivacyViolation(_ type: PrivacyViolationType, details: String) {
        let violation = PrivacyViolation(
            type: type,
            details: details,
            timestamp: Date(),
            resolved: false
        )
        
        privacyViolations.append(violation)
        
        // Update compliance score
        Task {
            await calculateComplianceScore()
        }
        
        logger.error("Privacy violation recorded: \(type.rawValue) - \(details)")
        
        // Notify other services
        NotificationCenter.default.post(name: .privacyViolationDetected, object: violation)
    }
    
    func resolvePrivacyViolation(_ violationId: UUID) {
        if let index = privacyViolations.firstIndex(where: { $0.id == violationId }) {
            privacyViolations[index].resolved = true
            privacyViolations[index].resolvedAt = Date()
            
            Task {
                await calculateComplianceScore()
            }
            
            logger.info("Privacy violation resolved: \(violationId)")
        }
    }
    
    // MARK: - Enhanced Data Protection
    
    func validateDataProcessingConsent() async -> Bool {
        return consentManager.canProcessData()
    }
    
    func validateAPICallConsent() async -> Bool {
        return consentManager.canMakeAPICalls()
    }
    
    func encryptSensitiveData(_ data: Data, key: String) async throws {
        try await dataProtectionManager.securelyStore(data: data, for: key)
        
        updateDataRetentionStatus { status in
            status.encryptedDataCount += 1
            status.keychainItemsCount += 1
        }
    }
    
    func decryptSensitiveData(for key: String) async throws -> Data {
        return try await dataProtectionManager.securelyRetrieve(for: key)
    }
    
    func securelyDeleteSensitiveData(for key: String) async throws {
        try await dataProtectionManager.securelyDelete(for: key)
        
        updateDataRetentionStatus { status in
            status.encryptedDataCount = max(0, status.encryptedDataCount - 1)
            status.keychainItemsCount = max(0, status.keychainItemsCount - 1)
        }
    }
    
    // MARK: - Security Auditing
    
    private func performSecurityAudit() async {
        auditQueue.async { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                let auditReport = await self.dataProtectionManager.performSecurityAudit()
                
                self.dataRetentionStatus.lastSecurityAudit = Date()
                
                // Check for security issues
                if auditReport.overallSecurityLevel == "Low" {
                    self.recordPrivacyViolation(.insufficientSecurity, 
                                              details: "Security audit indicates low security level")
                }
                
                self.logger.info("Security audit completed - Level: \(auditReport.overallSecurityLevel)")
            }
        }
    }
    
    func performManualSecurityAudit() async -> SecurityAuditReport {
        return await dataProtectionManager.performSecurityAudit()
    }
    
    // MARK: - Compliance Score Calculation
    
    func calculateComplianceScore() async {
        var score: Double = 1.0
        
        // Deduct for privacy violations
        let unresolvedViolations = privacyViolations.filter { !$0.resolved }
        score -= Double(unresolvedViolations.count) * 0.1
        
        // Deduct for insufficient security
        if dataRetentionStatus.securityLevel == .low {
            score -= 0.2
        } else if dataRetentionStatus.securityLevel == .medium {
            score -= 0.1
        }
        
        // Deduct for invalid privacy manifest
        if !isPrivacyManifestValid {
            score -= 0.3
        }
        
        // Ensure score doesn't go below 0
        complianceScore = max(0.0, score)
    }
    
    // MARK: - Data Retention Auditing
    
    private func auditDataRetention() async {
        // Check if data retention complies with privacy settings
        if privacySettings.dataRetentionPolicy == .never && dataRetentionStatus.hasAnyData {
            recordPrivacyViolation(.dataRetentionViolation, 
                                 details: "Data found despite 'never' retention policy")
        }
        
        // Check for old data that should be cleaned up
        if let lastClear = lastDataClearTime,
           Date().timeIntervalSince(lastClear) > 86400 { // 24 hours
            logger.warning("Data has not been cleared in over 24 hours")
        }
    }
    
    // MARK: - Privacy Manifest Generation
    
    func generatePrivacyManifest() -> PrivacyManifest {
        return consentManager.generatePrivacyManifest()
    }
    
    func validatePrivacyManifestForAppStore() async -> Bool {
        let manifest = generatePrivacyManifest()
        return validateManifestCompliance(manifest)
    }
    
    // MARK: - Enhanced Compliance Reporting
    
    func getEnhancedPrivacyReport() -> EnhancedPrivacyReport {
        return EnhancedPrivacyReport(
            dataRetentionPolicy: privacySettings.dataRetentionPolicy.rawValue,
            currentDataStatus: dataRetentionStatus,
            apiCallsToday: apiCallsCount,
            lastDataClear: lastDataClearTime,
            complianceLevel: calculateComplianceLevelText(),
            complianceScore: complianceScore,
            privacyViolations: privacyViolations,
            securityLevel: dataRetentionStatus.securityLevel,
            privacyManifestValid: isPrivacyManifestValid,
            consentStatus: consentManager.consentStatus,
            lastSecurityAudit: dataRetentionStatus.lastSecurityAudit,
            recommendations: generatePrivacyRecommendations()
        )
    }
    
    func getPrivacyReport() -> PrivacyReport {
        return PrivacyReport(
            dataRetentionPolicy: privacySettings.dataRetentionPolicy.rawValue,
            currentDataStatus: dataRetentionStatus,
            apiCallsToday: apiCallsCount,
            lastDataClear: lastDataClearTime,
            complianceLevel: calculateComplianceLevelText()
        )
    }
    
    private func calculateComplianceLevelText() -> String {
        switch complianceScore {
        case 0.9...1.0:
            return "Excellent"
        case 0.7..<0.9:
            return "Good"
        case 0.5..<0.7:
            return "Fair"
        default:
            return "Needs Improvement"
        }
    }
    
    private func generatePrivacyRecommendations() -> [PrivacyRecommendation] {
        var recommendations: [PrivacyRecommendation] = []
        
        if !isPrivacyManifestValid {
            recommendations.append(PrivacyRecommendation(
                type: .criticalAction,
                title: "Update Privacy Manifest",
                description: "Privacy manifest needs updates to comply with App Store requirements",
                priority: .high
            ))
        }
        
        if complianceScore < 0.8 {
            recommendations.append(PrivacyRecommendation(
                type: .improvement,
                title: "Improve Compliance Score",
                description: "Address privacy violations to improve overall compliance",
                priority: .medium
            ))
        }
        
        if dataRetentionStatus.securityLevel == .low {
            recommendations.append(PrivacyRecommendation(
                type: .security,
                title: "Enhance Security",
                description: "Enable additional security features for better data protection",
                priority: .high
            ))
        }
        
        return recommendations
    }
    
    struct PrivacyReport {
        let dataRetentionPolicy: String
        let currentDataStatus: DataRetentionStatus
        let apiCallsToday: Int
        let lastDataClear: Date?
        let complianceLevel: String
    }
    
    struct EnhancedPrivacyReport {
        let dataRetentionPolicy: String
        let currentDataStatus: DataRetentionStatus
        let apiCallsToday: Int
        let lastDataClear: Date?
        let complianceLevel: String
        let complianceScore: Double
        let privacyViolations: [PrivacyViolation]
        let securityLevel: SecurityLevel
        let privacyManifestValid: Bool
        let consentStatus: ConsentStatus
        let lastSecurityAudit: Date?
        let recommendations: [PrivacyRecommendation]
    }
    
    // MARK: - Factory Method
    
    @MainActor
    static func create() -> PrivacyComplianceService {
        let dataProtectionManager = DataProtectionManager()
        let consentManager = ConsentManager()
        return PrivacyComplianceService(dataProtectionManager: dataProtectionManager, consentManager: consentManager)
    }
}

// MARK: - Supporting Types

enum SecurityLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum PrivacyViolationType: String, CaseIterable {
    case dataRetentionViolation = "Data Retention Violation"
    case unauthorizedDataAccess = "Unauthorized Data Access"
    case insufficientSecurity = "Insufficient Security"
    case invalidPrivacyManifest = "Invalid Privacy Manifest"
    case consentViolation = "Consent Violation"
    case networkPrivacyIssue = "Network Privacy Issue"
}

struct PrivacyViolation: Identifiable {
    let id = UUID()
    let type: PrivacyViolationType
    let details: String
    let timestamp: Date
    var resolved: Bool
    var resolvedAt: Date?
    
    var severity: ViolationSeverity {
        switch type {
        case .invalidPrivacyManifest, .consentViolation:
            return .critical
        case .dataRetentionViolation, .insufficientSecurity:
            return .high
        case .unauthorizedDataAccess, .networkPrivacyIssue:
            return .medium
        }
    }
}

enum ViolationSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

struct PrivacyRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: RecommendationPriority
}

enum RecommendationType: String, CaseIterable {
    case security = "Security"
    case compliance = "Compliance"
    case improvement = "Improvement"
    case criticalAction = "Critical Action"
}

enum RecommendationPriority: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let clearPrivateData = Notification.Name("clearPrivateData")
    static let privacyViolationDetected = Notification.Name("privacyViolationDetected")
}