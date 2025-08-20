//
//  ConsentManager.swift
//  Menu Visualizer
//
//  iOS-compliant consent management following Apple guidelines and App Store requirements
//

import Foundation
import SwiftUI
import OSLog
import AppTrackingTransparency
import AdSupport

/// Comprehensive consent manager for iOS privacy compliance
@MainActor
final class ConsentManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var hasShownInitialConsent: Bool = false
    @Published var consentStatus: ConsentStatus = .unknown
    @Published var trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published var isConsentRequired: Bool = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.menuly.consent", category: "ConsentManager")
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Consent Record
    @Published var currentConsent: ConsentRecord = ConsentRecord.defaultConsent
    
    // MARK: - Constants
    private enum Keys {
        static let hasShownInitialConsent = "menuly_has_shown_initial_consent"
        static let consentRecord = "menuly_consent_record"
        static let consentVersion = "menuly_consent_version"
        static let lastConsentDate = "menuly_last_consent_date"
    }
    
    private let currentConsentVersion = "1.0.0"
    
    // MARK: - Initialization
    init() {
        loadConsentState()
        checkConsentRequirements()
        setupTrackingAuthorizationObserver()
    }
    
    // MARK: - Consent State Management
    
    private func loadConsentState() {
        hasShownInitialConsent = userDefaults.bool(forKey: Keys.hasShownInitialConsent)
        
        if let data = userDefaults.data(forKey: Keys.consentRecord),
           let consent = try? JSONDecoder().decode(ConsentRecord.self, from: data) {
            currentConsent = consent
            consentStatus = consent.overallStatus
        } else {
            currentConsent = ConsentRecord.defaultConsent
            consentStatus = .unknown
        }
        
        logger.info("Consent state loaded - Status: \(self.consentStatus.rawValue)")
    }
    
    private func saveConsentState() {
        userDefaults.set(hasShownInitialConsent, forKey: Keys.hasShownInitialConsent)
        
        if let data = try? JSONEncoder().encode(currentConsent) {
            userDefaults.set(data, forKey: Keys.consentRecord)
        }
        
        userDefaults.set(currentConsentVersion, forKey: Keys.consentVersion)
        userDefaults.set(Date(), forKey: Keys.lastConsentDate)
        
        logger.debug("Consent state saved")
    }
    
    private func checkConsentRequirements() {
        // Check if consent is required based on various factors
        isConsentRequired = shouldRequestConsent()
        
        if isConsentRequired && !hasShownInitialConsent {
            logger.info("Initial consent collection required")
        }
    }
    
    private func shouldRequestConsent() -> Bool {
        // In our privacy-first app, we still need to inform users about our practices
        // even though we don't collect personal data
        return !hasShownInitialConsent || isConsentVersionOutdated()
    }
    
    private func isConsentVersionOutdated() -> Bool {
        let savedVersion = userDefaults.string(forKey: Keys.consentVersion) ?? "0.0.0"
        return savedVersion != currentConsentVersion
    }
    
    // MARK: - App Tracking Transparency
    
    private func setupTrackingAuthorizationObserver() {
        // Note: Menuly doesn't track users, but we still need to handle ATT properly
        trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
        
        // Update status when it changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateTrackingAuthorizationStatus()
            }
        }
    }
    
    private func updateTrackingAuthorizationStatus() {
        let newStatus = ATTrackingManager.trackingAuthorizationStatus
        if newStatus != trackingAuthorizationStatus {
            trackingAuthorizationStatus = newStatus
            logger.info("Tracking authorization status updated: \(newStatus.rawValue)")
        }
    }
    
    func requestTrackingPermission() async {
        // Note: Menuly doesn't actually track users, but we handle this for completeness
        logger.info("Requesting tracking permission (not used for actual tracking)")
        
        let status = await ATTrackingManager.requestTrackingAuthorization()
        
        await MainActor.run {
            trackingAuthorizationStatus = status
            
            // Update consent record
            currentConsent.trackingConsent = ConsentState(
                granted: status == .authorized,
                timestamp: Date(),
                mechanism: .explicit
            )
            
            updateOverallConsentStatus()
            saveConsentState()
        }
        
        logger.info("Tracking permission result: \(status.rawValue)")
    }
    
    // MARK: - Consent Collection
    
    func recordInitialConsent(_ consent: ConsentRecord) {
        logger.info("Recording initial consent")
        
        currentConsent = consent
        hasShownInitialConsent = true
        updateOverallConsentStatus()
        saveConsentState()
        
        // Notify other services about consent changes
        NotificationCenter.default.post(name: .consentUpdated, object: consent)
        
        logger.info("Initial consent recorded - Status: \(self.consentStatus.rawValue)")
    }
    
    func updateConsent(for category: ConsentCategory, granted: Bool, mechanism: ConsentMechanism = .explicit) {
        logger.info("Updating consent for \(category.rawValue): \(granted)")
        
        let newConsentState = ConsentState(
            granted: granted,
            timestamp: Date(),
            mechanism: mechanism
        )
        
        switch category {
        case .dataProcessing:
            currentConsent.dataProcessingConsent = newConsentState
        case .apiCommunication:
            currentConsent.apiCommunicationConsent = newConsentState
        case .errorReporting:
            currentConsent.errorReportingConsent = newConsentState
        case .analytics:
            currentConsent.analyticsConsent = newConsentState
        case .marketing:
            currentConsent.marketingConsent = newConsentState
        case .tracking:
            currentConsent.trackingConsent = newConsentState
        }
        
        updateOverallConsentStatus()
        saveConsentState()
        
        // Notify other services
        NotificationCenter.default.post(name: .consentUpdated, object: currentConsent)
    }
    
    private func updateOverallConsentStatus() {
        // Determine overall consent status based on essential consents
        let essentialConsents = [
            currentConsent.dataProcessingConsent.granted,
            currentConsent.apiCommunicationConsent.granted
        ]
        
        if essentialConsents.allSatisfy({ $0 }) {
            consentStatus = .granted
        } else if essentialConsents.allSatisfy({ !$0 }) {
            consentStatus = .denied
        } else {
            consentStatus = .partial
        }
    }
    
    // MARK: - Consent Withdrawal
    
    func withdrawAllConsent() {
        logger.warning("Withdrawing all consent")
        
        let withdrawalTimestamp = Date()
        
        currentConsent = ConsentRecord(
            dataProcessingConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            apiCommunicationConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            errorReportingConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            analyticsConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            marketingConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            trackingConsent: ConsentState(granted: false, timestamp: withdrawalTimestamp, mechanism: .explicit),
            consentVersion: currentConsentVersion,
            locale: Locale.current.identifier,
            userAgent: getUserAgent()
        )
        
        consentStatus = .denied
        saveConsentState()
        
        // Notify services to stop data processing
        NotificationCenter.default.post(name: .consentWithdrawn, object: nil)
        
        logger.warning("All consent withdrawn")
    }
    
    func withdrawConsent(for category: ConsentCategory) {
        updateConsent(for: category, granted: false, mechanism: .explicit)
        logger.warning("Consent withdrawn for \(category.rawValue)")
    }
    
    // MARK: - Consent Validation
    
    func isConsentGranted(for category: ConsentCategory) -> Bool {
        switch category {
        case .dataProcessing:
            return currentConsent.dataProcessingConsent.granted
        case .apiCommunication:
            return currentConsent.apiCommunicationConsent.granted
        case .errorReporting:
            return currentConsent.errorReportingConsent.granted
        case .analytics:
            return currentConsent.analyticsConsent.granted
        case .marketing:
            return currentConsent.marketingConsent.granted
        case .tracking:
            return currentConsent.trackingConsent.granted
        }
    }
    
    func isEssentialConsentGranted() -> Bool {
        return currentConsent.dataProcessingConsent.granted && 
               currentConsent.apiCommunicationConsent.granted
    }
    
    func canProcessData() -> Bool {
        return isConsentGranted(for: .dataProcessing)
    }
    
    func canMakeAPICalls() -> Bool {
        return isConsentGranted(for: .apiCommunication)
    }
    
    // MARK: - Privacy Manifest Integration
    
    func generatePrivacyManifest() -> PrivacyManifest {
        return PrivacyManifest(
            trackingDomains: [], // Menuly doesn't track
            collectedDataTypes: getCollectedDataTypes(),
            trackingEnabled: false,
            dataLinkedToUser: false,
            dataUsedForTracking: false,
            privacyPolicyURL: "https://menuly.app/privacy",
            consentMechanism: "in-app-consent-flow"
        )
    }
    
    private func getCollectedDataTypes() -> [CollectedDataType] {
        var dataTypes: [CollectedDataType] = []
        
        // Only add data types we actually collect based on consent
        if isConsentGranted(for: .dataProcessing) {
            dataTypes.append(CollectedDataType(
                type: "User Content",
                linkedToUser: false,
                usedForTracking: false,
                purposes: ["App Functionality"],
                description: "Menu photos processed locally for dish visualization"
            ))
        }
        
        if isConsentGranted(for: .errorReporting) {
            dataTypes.append(CollectedDataType(
                type: "Diagnostics",
                linkedToUser: false,
                usedForTracking: false,
                purposes: ["App Functionality"],
                description: "Anonymous error reports for app improvement"
            ))
        }
        
        return dataTypes
    }
    
    // MARK: - Compliance Reporting
    
    func generateConsentReport() -> ConsentReport {
        return ConsentReport(
            consentVersion: currentConsentVersion,
            overallStatus: consentStatus,
            individualConsents: [
                ConsentCategoryReport(category: .dataProcessing, state: currentConsent.dataProcessingConsent),
                ConsentCategoryReport(category: .apiCommunication, state: currentConsent.apiCommunicationConsent),
                ConsentCategoryReport(category: .errorReporting, state: currentConsent.errorReportingConsent),
                ConsentCategoryReport(category: .analytics, state: currentConsent.analyticsConsent),
                ConsentCategoryReport(category: .marketing, state: currentConsent.marketingConsent),
                ConsentCategoryReport(category: .tracking, state: currentConsent.trackingConsent)
            ],
            trackingAuthorizationStatus: trackingAuthorizationStatus,
            isCompliant: isCompliantWithAppleGuidelines(),
            lastUpdated: userDefaults.object(forKey: Keys.lastConsentDate) as? Date ?? Date(),
            locale: Locale.current.identifier
        )
    }
    
    private func isCompliantWithAppleGuidelines() -> Bool {
        // Check compliance with Apple's privacy guidelines
        let hasRequiredConsents = hasShownInitialConsent
        let hasValidVersion = !isConsentVersionOutdated()
        let properATTHandling = trackingAuthorizationStatus != .notDetermined || !requiresTrackingPermission()
        
        return hasRequiredConsents && hasValidVersion && properATTHandling
    }
    
    private func requiresTrackingPermission() -> Bool {
        // Menuly doesn't track users, so we don't actually require tracking permission
        // But we handle it properly for completeness
        return false
    }
    
    // MARK: - Utility Methods
    
    private func getUserAgent() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let systemVersion = UIDevice.current.systemVersion
        return "Menuly/\(appVersion) iOS/\(systemVersion)"
    }
    
    // MARK: - Reset Functions
    
    func resetConsentForTesting() {
        // Only available in debug builds for testing
        #if DEBUG
        userDefaults.removeObject(forKey: Keys.hasShownInitialConsent)
        userDefaults.removeObject(forKey: Keys.consentRecord)
        userDefaults.removeObject(forKey: Keys.consentVersion)
        userDefaults.removeObject(forKey: Keys.lastConsentDate)
        
        loadConsentState()
        logger.debug("Consent state reset for testing")
        #endif
    }
}

// MARK: - Supporting Types

enum ConsentStatus: String, CaseIterable {
    case unknown = "Unknown"
    case granted = "Granted"
    case denied = "Denied"
    case partial = "Partial"
}


enum ConsentMechanism: String, Codable {
    case explicit = "Explicit"
    case implicit = "Implicit"
    case legitimate = "Legitimate Interest"
    case none = "None"
}

struct ConsentState: Codable {
    let granted: Bool
    let timestamp: Date
    let mechanism: ConsentMechanism
}

struct ConsentRecord: Codable {
    var dataProcessingConsent: ConsentState
    var apiCommunicationConsent: ConsentState
    var errorReportingConsent: ConsentState
    var analyticsConsent: ConsentState
    var marketingConsent: ConsentState
    var trackingConsent: ConsentState
    
    let consentVersion: String
    let locale: String
    let userAgent: String
    
    var overallStatus: ConsentStatus {
        let essentialConsents = [dataProcessingConsent.granted, apiCommunicationConsent.granted]
        
        if essentialConsents.allSatisfy({ $0 }) {
            return .granted
        } else if essentialConsents.allSatisfy({ !$0 }) {
            return .denied
        } else {
            return .partial
        }
    }
    
    static var defaultConsent: ConsentRecord {
        let defaultTimestamp = Date()
        return ConsentRecord(
            dataProcessingConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            apiCommunicationConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            errorReportingConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            analyticsConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            marketingConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            trackingConsent: ConsentState(granted: false, timestamp: defaultTimestamp, mechanism: .none),
            consentVersion: "1.0.0",
            locale: Locale.current.identifier,
            userAgent: "Menuly/1.0"
        )
    }
}

struct PrivacyManifest: Codable {
    let trackingDomains: [String]
    let collectedDataTypes: [CollectedDataType]
    let trackingEnabled: Bool
    let dataLinkedToUser: Bool
    let dataUsedForTracking: Bool
    let privacyPolicyURL: String
    let consentMechanism: String
}

struct CollectedDataType: Codable {
    let type: String
    let linkedToUser: Bool
    let usedForTracking: Bool
    let purposes: [String]
    let description: String
}

struct ConsentReport {
    let consentVersion: String
    let overallStatus: ConsentStatus
    let individualConsents: [ConsentCategoryReport]
    let trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus
    let isCompliant: Bool
    let lastUpdated: Date
    let locale: String
}

struct ConsentCategoryReport {
    let category: ConsentCategory
    let state: ConsentState
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let consentUpdated = Notification.Name("consentUpdated")
    static let consentWithdrawn = Notification.Name("consentWithdrawn")
}