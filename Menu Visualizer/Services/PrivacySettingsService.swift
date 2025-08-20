//
//  PrivacySettingsService.swift
//  Menu Visualizer
//
//  Enhanced privacy settings service with iOS system integration
//

import Foundation
import SwiftUI
import OSLog
import UserNotifications
import LocalAuthentication
import AVFoundation

/// Enhanced privacy settings service with iOS system integration
@MainActor
final class PrivacySettingsService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentSettings: PrivacySettings
    @Published var isSystemIntegrationEnabled: Bool = false
    @Published var systemSettingsStatus: SystemSettingsStatus = .unknown
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.menuly.privacy.settings", category: "PrivacySettingsService")
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "menuly_privacy_settings_v2"
    
    // System integration
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Initialization
    
    init() {
        // Load settings with enhanced defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            self.currentSettings = settings
        } else {
            self.currentSettings = Self.createDefaultSettings()
            saveSettings()
        }
        
        // Check system integration capabilities
        Task {
            await checkSystemIntegration()
        }
        
        logger.info("Privacy Settings Service initialized")
    }
    
    // MARK: - Default Settings Creation
    
    private static func createDefaultSettings() -> PrivacySettings {
        // Create privacy-first defaults based on device capabilities
        return PrivacySettings(
            dataRetentionPolicy: .sessionOnly,
            analyticsEnabled: false,
            crashReportingEnabled: false,
            enableBiometricProtection: false,
            enableScreenshotProtection: false,
            enableNetworkProtection: false,
            autoDeleteTemporaryFiles: true,
            requireConsentForAPI: true
        )
    }
    
    private static func deviceSupportsBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - System Integration
    
    private func checkSystemIntegration() async {
        await validateSystemSettings()
        await setupSystemSettingsIntegration()
    }
    
    private func validateSystemSettings() async {
        // Check if privacy settings align with system settings
        var status = SystemSettingsStatus.aligned
        var issues: [SystemSettingsIssue] = []
        
        // Check notification permissions
        let notificationSettings = await notificationCenter.notificationSettings()
        if notificationSettings.authorizationStatus == .denied {
            issues.append(SystemSettingsIssue(
                type: .notificationPermission,
                description: "Notifications disabled - privacy alerts unavailable"
            ))
        }
        
        // Check camera permission (if we need it for menu scanning)
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .denied {
            issues.append(SystemSettingsIssue(
                type: .cameraPermission,
                description: "Camera access denied - menu scanning unavailable"
            ))
        }
        
        // Update status based on issues
        if !issues.isEmpty {
            status = issues.contains { $0.type.isCritical } ? .misaligned : .partiallyAligned
        }
        
        systemSettingsStatus = status
        
        if status != .aligned {
            logger.warning("System settings validation found \(issues.count) issues")
        }
    }
    
    private func setupSystemSettingsIntegration() async {
        // Configure system-level privacy features
        await requestNotificationPermissionsIfNeeded()
        
        // Set up system settings monitoring
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.validateSystemSettings()
            }
        }
        
        isSystemIntegrationEnabled = true
        logger.info("System integration setup completed")
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: PrivacySettings) async {
        let oldSettings = currentSettings
        currentSettings = newSettings
        
        // Validate settings compatibility
        let validationResult = await validateSettingsCompatibility(newSettings)
        if !validationResult.isValid {
            logger.warning("Settings validation warnings: \(validationResult.warnings.joined(separator: ", "))")
        }
        
        // Apply system-level changes if needed
        await applySystemLevelChanges(from: oldSettings, to: newSettings)
        
        // Save settings
        saveSettings()
        
        // Notify other services
        NotificationCenter.default.post(name: .privacySettingsUpdated, object: newSettings)
        
        logger.info("Privacy settings updated: \(String(describing: newSettings))")
    }
    
    private func validateSettingsCompatibility(_ settings: PrivacySettings) async -> SettingsValidationResult {
        var warnings: [String] = []
        
        // Basic settings validation
        // Future: Add more specific validation logic
        
        // Check data retention policy implications
        if settings.dataRetentionPolicy == .never && settings.crashReportingEnabled {
            warnings.append("Error reporting may conflict with 'never store' data policy")
        }
        
        // Simplified validation for current settings structure
        
        return SettingsValidationResult(
            isValid: warnings.isEmpty,
            warnings: warnings
        )
    }
    
    private func applySystemLevelChanges(from oldSettings: PrivacySettings, to newSettings: PrivacySettings) async {
        // Handle biometric protection changes
        // Handle biometric protection changes when available in future versions
        
        // Handle screenshot protection changes when available in future versions
        
        // Handle data retention policy changes
        if oldSettings.dataRetentionPolicy != newSettings.dataRetentionPolicy {
            await handleDataRetentionPolicyChange(from: oldSettings.dataRetentionPolicy, to: newSettings.dataRetentionPolicy)
        }
    }
    
    // MARK: - System-Level Privacy Controls
    
    private func handleBiometricProtectionChange(enabled: Bool) async {
        if enabled && Self.deviceSupportsBiometrics() {
            // Configure biometric protection
            logger.info("Biometric protection enabled")
            
            // Request permission if needed
            let context = LAContext()
            do {
                let _ = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Enable biometric protection for Menuly privacy features"
                )
                logger.info("Biometric authentication successful")
            } catch {
                logger.error("Biometric authentication failed: \(error.localizedDescription)")
            }
        } else {
            logger.info("Biometric protection disabled")
        }
    }
    
    private func handleScreenshotProtectionChange(enabled: Bool) async {
        // Configure screenshot protection
        NotificationCenter.default.post(
            name: .screenshotProtectionChanged,
            object: ["enabled": enabled]
        )
        
        logger.info("Screenshot protection \(enabled ? "enabled" : "disabled")")
    }
    
    private func handleDataRetentionPolicyChange(from oldPolicy: PrivacySettings.DataRetentionPolicy, to newPolicy: PrivacySettings.DataRetentionPolicy) async {
        // Handle data retention policy changes
        if newPolicy == .never && oldPolicy != .never {
            // Switching to never store - clear all data immediately
            NotificationCenter.default.post(name: .clearAllDataImmediately, object: nil)
            logger.info("Data retention policy changed to 'never' - clearing all data")
        }
    }
    
    // MARK: - Permission Management
    
    private func requestNotificationPermissionsIfNeeded() async {
        let settings = await notificationCenter.notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge])
                logger.info("Notification permission \(granted ? "granted" : "denied")")
            } catch {
                logger.error("Failed to request notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func requestCameraPermissionIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    // MARK: - Settings Persistence
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(currentSettings)
            userDefaults.set(data, forKey: settingsKey)
            logger.debug("Privacy settings saved")
        } catch {
            logger.error("Failed to save privacy settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings Export/Import
    
    func exportSettings() -> Data? {
        do {
            return try JSONEncoder().encode(currentSettings)
        } catch {
            logger.error("Failed to export settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    func importSettings(from data: Data) async -> Bool {
        do {
            let importedSettings = try JSONDecoder().decode(PrivacySettings.self, from: data)
            await updateSettings(importedSettings)
            logger.info("Settings imported successfully")
            return true
        } catch {
            logger.error("Failed to import settings: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Settings Recommendations
    
    func getPrivacyRecommendations() -> [PrivacySettingsRecommendation] {
        var recommendations: [PrivacySettingsRecommendation] = []
        
        // Recommend biometric protection if available but disabled
        if !currentSettings.dataRetentionPolicy.description.isEmpty {
            recommendations.append(PrivacySettingsRecommendation(
                type: .security,
                title: "Enable Biometric Protection",
                description: "Use Face ID or Touch ID to protect sensitive data",
                impact: .medium,
                action: "Enable biometric protection in privacy settings"
            ))
        }
        
        // Recommend stricter data retention if using session-only
        if currentSettings.dataRetentionPolicy == .sessionOnly {
            recommendations.append(PrivacySettingsRecommendation(
                type: .privacy,
                title: "Consider 'Never Store' Policy",
                description: "For maximum privacy, consider switching to 'Never Store' data policy",
                impact: .low,
                action: "Change data retention policy in privacy settings"
            ))
        }
        
        // Recommend enabling screenshot protection if disabled
        if !currentSettings.enableScreenshotProtection {
            recommendations.append(PrivacySettingsRecommendation(
                type: .security,
                title: "Enable Screenshot Protection",
                description: "Prevent sensitive content from appearing in screenshots",
                impact: .medium,
                action: "Enable screenshot protection in privacy settings"
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Settings Validation
    
    func validateCurrentSettings() -> SettingsHealthReport {
        var issues: [SettingsIssue] = []
        var score: Double = 100.0
        
        // Check for potential privacy issues
        if currentSettings.crashReportingEnabled && currentSettings.dataRetentionPolicy == .never {
            issues.append(SettingsIssue(
                severity: .warning,
                description: "Error reporting enabled with 'never store' policy may cause conflicts"
            ))
            score -= 10
        }
        
        // Check security features when available in future versions
        
        // Screenshot protection validation when available in future versions
        
        // Calculate overall health level
        let healthLevel: SettingsHealthLevel
        switch score {
        case 90...100:
            healthLevel = .excellent
        case 75..<90:
            healthLevel = .good
        case 50..<75:
            healthLevel = .fair
        default:
            healthLevel = .poor
        }
        
        return SettingsHealthReport(
            score: score,
            healthLevel: healthLevel,
            issues: issues,
            recommendations: getPrivacyRecommendations()
        )
    }
    
    // MARK: - Factory Reset
    
    func resetToDefaults() async {
        logger.info("Resetting privacy settings to defaults")
        
        let defaultSettings = PrivacySettingsService.createDefaultSettings()
        await self.updateSettings(defaultSettings)
        
        // Clear any cached data
        NotificationCenter.default.post(name: .clearAllDataImmediately, object: nil)
    }
}


// MARK: - Supporting Types

enum SystemSettingsStatus {
    case unknown
    case aligned
    case partiallyAligned
    case misaligned
}

struct SystemSettingsIssue {
    let type: SystemSettingsIssueType
    let description: String
}

enum SystemSettingsIssueType {
    case notificationPermission
    case cameraPermission
    case privacyPolicy
    
    var isCritical: Bool {
        switch self {
        case .cameraPermission:
            return true
        case .notificationPermission, .privacyPolicy:
            return false
        }
    }
}

struct SettingsValidationResult {
    let isValid: Bool
    let warnings: [String]
}

struct PrivacySettingsRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let impact: ImpactLevel
    let action: String
    
    enum RecommendationType {
        case security
        case privacy
        case performance
        case usability
    }
    
    enum ImpactLevel {
        case low
        case medium
        case high
    }
}

struct SettingsHealthReport {
    let score: Double
    let healthLevel: SettingsHealthLevel
    let issues: [SettingsIssue]
    let recommendations: [PrivacySettingsRecommendation]
}

enum SettingsHealthLevel: String {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var description: String {
        switch self {
        case .excellent:
            return "Your privacy settings provide excellent protection"
        case .good:
            return "Your privacy settings provide good protection with minor improvements possible"
        case .fair:
            return "Your privacy settings provide basic protection but could be improved"
        case .poor:
            return "Your privacy settings need significant improvements for better protection"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }
}

struct SettingsIssue {
    let severity: IssueSeverity
    let description: String
    
    enum IssueSeverity {
        case info
        case warning
        case error
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let privacySettingsUpdated = Notification.Name("privacySettingsUpdated")
    static let screenshotProtectionChanged = Notification.Name("screenshotProtectionChanged")
    static let clearAllDataImmediately = Notification.Name("clearAllDataImmediately")
}

// MARK: - Extensions

// LAContext extension removed - evaluatePolicy async version already available in iOS 16+
