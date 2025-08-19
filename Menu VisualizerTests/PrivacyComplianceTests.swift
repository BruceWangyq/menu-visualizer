//
//  PrivacyComplianceTests.swift
//  Menu VisualizerTests
//
//  Comprehensive privacy compliance testing suite for iOS security features
//

import XCTest
import CryptoKit
import LocalAuthentication
@testable import Menu_Visualizer

final class PrivacyComplianceTests: XCTestCase {
    
    var privacyCompliance: PrivacyComplianceService!
    var dataProtection: DataProtectionManager!
    var consentManager: ConsentManager!
    var apiPrivacyLayer: APIPrivacyLayer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize services for testing
        dataProtection = DataProtectionManager()
        consentManager = ConsentManager()
        privacyCompliance = PrivacyComplianceService(
            dataProtectionManager: dataProtection,
            consentManager: consentManager
        )
        apiPrivacyLayer = APIPrivacyLayer()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        privacyCompliance = nil
        dataProtection = nil
        consentManager = nil
        apiPrivacyLayer = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Data Protection Tests
    
    func testKeychainDataProtection() async throws {
        let testData = "sensitive test data".data(using: .utf8)!
        let testKey = "test_keychain_key"
        
        // Test secure storage
        try await dataProtection.securelyStore(data: testData, for: testKey, requiresBiometric: false)
        
        // Test secure retrieval
        let retrievedData = try await dataProtection.securelyRetrieve(for: testKey)
        XCTAssertEqual(testData, retrievedData, "Retrieved data should match stored data")
        
        // Test secure deletion
        try await dataProtection.securelyDelete(for: testKey)
        
        // Verify deletion
        do {
            _ = try await dataProtection.securelyRetrieve(for: testKey)
            XCTFail("Should not be able to retrieve deleted data")
        } catch DataProtectionError.keychainItemNotFound {
            // Expected behavior
        }
    }
    
    func testDataIntegrityValidation() throws {
        let testData = "test data for integrity validation".data(using: .utf8)!
        let expectedHash = dataProtection.generateDataHash(for: testData)
        
        // Test valid integrity check
        XCTAssertTrue(try dataProtection.validateDataIntegrity(for: testData, expectedHash: expectedHash))
        
        // Test invalid integrity check
        let tamperedData = "tampered data".data(using: .utf8)!
        XCTAssertThrowsError(try dataProtection.validateDataIntegrity(for: tamperedData, expectedHash: expectedHash))
    }
    
    func testProtectedMemory() {
        let sensitiveData = "very sensitive information".data(using: .utf8)!
        let protectedMemory = dataProtection.protectSensitiveMemory(sensitiveData)
        
        var accessedData: Data?
        protectedMemory.accessSecurely { data in
            accessedData = data
            return data
        }
        
        XCTAssertEqual(accessedData, sensitiveData, "Protected memory should provide access to data")
    }
    
    // MARK: - Consent Management Tests
    
    func testConsentCollection() {
        // Test initial consent state
        XCTAssertEqual(consentManager.consentStatus, .unknown)
        
        // Test consent granting
        consentManager.updateConsent(for: .dataProcessing, granted: true)
        XCTAssertTrue(consentManager.isConsentGranted(for: .dataProcessing))
        
        // Test consent withdrawal
        consentManager.updateConsent(for: .dataProcessing, granted: false)
        XCTAssertFalse(consentManager.isConsentGranted(for: .dataProcessing))
    }
    
    func testEssentialConsentValidation() {
        // Grant essential consents
        consentManager.updateConsent(for: .dataProcessing, granted: true)
        consentManager.updateConsent(for: .apiCommunication, granted: true)
        
        XCTAssertTrue(consentManager.isEssentialConsentGranted())
        XCTAssertTrue(consentManager.canProcessData())
        XCTAssertTrue(consentManager.canMakeAPICalls())
    }
    
    func testConsentWithdrawal() {
        // Grant all consents first
        for category in ConsentCategory.allCases {
            consentManager.updateConsent(for: category, granted: true)
        }
        
        // Withdraw all consent
        consentManager.withdrawAllConsent()
        
        // Verify all consents are withdrawn
        for category in ConsentCategory.allCases {
            XCTAssertFalse(consentManager.isConsentGranted(for: category))
        }
        
        XCTAssertEqual(consentManager.consentStatus, .denied)
    }
    
    func testPrivacyManifestGeneration() {
        let manifest = consentManager.generatePrivacyManifest()
        
        // Verify privacy-first defaults
        XCTAssertFalse(manifest.trackingEnabled, "Tracking should be disabled")
        XCTAssertFalse(manifest.dataLinkedToUser, "Data should not be linked to user")
        XCTAssertFalse(manifest.dataUsedForTracking, "Data should not be used for tracking")
        XCTAssertTrue(manifest.trackingDomains.isEmpty, "No tracking domains should be present")
        XCTAssertFalse(manifest.privacyPolicyURL.isEmpty, "Privacy policy URL should be present")
    }
    
    // MARK: - API Privacy Tests
    
    func testAPIRequestPrivacyValidation() async {
        // Test secure HTTPS request
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/test")!)
        request.httpMethod = "POST"
        
        // This should not throw for trusted host with HTTPS
        XCTAssertNoThrow(try validateRequestPrivacy(request))
        
        // Test insecure HTTP request
        let insecureRequest = URLRequest(url: URL(string: "http://api.anthropic.com/test")!)
        XCTAssertThrowsError(try validateRequestPrivacy(insecureRequest))
        
        // Test untrusted host
        let untrustedRequest = URLRequest(url: URL(string: "https://untrusted.com/test")!)
        XCTAssertThrowsError(try validateRequestPrivacy(untrustedRequest))
    }
    
    func testSensitiveDataDetection() {
        let emailContent = "Contact us at user@example.com for support"
        let phoneContent = "Call us at 123-456-7890"
        let cleanContent = "This is a safe menu description"
        
        XCTAssertTrue(containsSensitiveData(in: emailContent), "Should detect email addresses")
        XCTAssertTrue(containsSensitiveData(in: phoneContent), "Should detect phone numbers")
        XCTAssertFalse(containsSensitiveData(in: cleanContent), "Should not flag clean content")
    }
    
    func testPrivacyHeaders() {
        let headers = apiPrivacyLayer.getPrivacyHeaders()
        
        XCTAssertEqual(headers["DNT"], "1", "Do Not Track header should be set")
        XCTAssertEqual(headers["X-Privacy-Policy"], "no-data-collection", "Privacy policy header should be set")
        XCTAssertTrue(headers["User-Agent"]?.contains("Privacy-First") ?? false, "User agent should indicate privacy focus")
        XCTAssertEqual(headers["Cache-Control"], "no-cache, no-store, must-revalidate", "Cache control should prevent caching")
    }
    
    // MARK: - Privacy Compliance Tests
    
    func testDataRetentionCompliance() async {
        // Test session-only retention
        privacyCompliance.privacySettings.dataRetentionPolicy = .sessionOnly
        privacyCompliance.trackImageCapture()
        
        XCTAssertTrue(privacyCompliance.dataRetentionStatus.hasTemporaryImages)
        
        // Simulate app termination
        privacyCompliance.handleAppWillTerminate()
        
        XCTAssertFalse(privacyCompliance.dataRetentionStatus.hasAnyData)
    }
    
    func testPrivacyViolationDetection() async {
        let initialViolationCount = privacyCompliance.privacyViolations.count
        
        // Simulate a privacy violation
        privacyCompliance.privacySettings.dataRetentionPolicy = .never
        privacyCompliance.trackImageCapture() // This should trigger a violation
        
        await privacyCompliance.auditDataRetention()
        
        XCTAssertGreaterThan(privacyCompliance.privacyViolations.count, initialViolationCount, "Privacy violation should be detected")
        XCTAssertLessThan(privacyCompliance.complianceScore, 1.0, "Compliance score should decrease")
    }
    
    func testComplianceScoreCalculation() async {
        // Start with perfect compliance
        await privacyCompliance.calculateComplianceScore()
        let initialScore = privacyCompliance.complianceScore
        
        // Add a privacy violation
        privacyCompliance.recordPrivacyViolation(.dataRetentionViolation, details: "Test violation")
        
        await privacyCompliance.calculateComplianceScore()
        let newScore = privacyCompliance.complianceScore
        
        XCTAssertLessThan(newScore, initialScore, "Compliance score should decrease after violation")
    }
    
    func testSecurityAuditReport() async {
        let auditReport = await dataProtection.performSecurityAudit()
        
        XCTAssertNotNil(auditReport.timestamp, "Audit report should have timestamp")
        XCTAssertFalse(auditReport.overallSecurityLevel.isEmpty, "Audit report should have security level")
        
        // Security level should be one of expected values
        let validLevels = ["Low", "Medium", "High", "Maximum"]
        XCTAssertTrue(validLevels.contains(auditReport.overallSecurityLevel))
    }
    
    func testPrivacyManifestValidation() async {
        await privacyCompliance.validatePrivacyManifest()
        
        // Should be valid for privacy-first app
        XCTAssertTrue(privacyCompliance.isPrivacyManifestValid, "Privacy manifest should be valid")
    }
    
    // MARK: - Data Clearing Tests
    
    func testDataClearingEffectiveness() {
        // Add some test data
        privacyCompliance.trackImageCapture()
        privacyCompliance.trackOCRProcessing()
        privacyCompliance.trackAPICall()
        
        XCTAssertTrue(privacyCompliance.dataRetentionStatus.hasAnyData, "Should have data before clearing")
        
        // Clear all data
        privacyCompliance.clearAllDataImmediately()
        
        XCTAssertFalse(privacyCompliance.dataRetentionStatus.hasAnyData, "Should have no data after clearing")
        XCTAssertNotNil(privacyCompliance.lastDataClearTime, "Should record clear time")
    }
    
    func testAutomaticDataCleanup() {
        privacyCompliance.privacySettings.dataRetentionPolicy = .never
        
        // Track some data
        privacyCompliance.trackImageCapture()
        
        // Simulate app entering background
        privacyCompliance.handleAppDidEnterBackground()
        
        // Data should be cleared immediately with "never" policy
        XCTAssertFalse(privacyCompliance.dataRetentionStatus.hasAnyData)
    }
    
    // MARK: - Performance Tests
    
    func testPrivacyValidationPerformance() {
        measure {
            // Test privacy validation performance
            for _ in 0..<1000 {
                let testData = "test data".data(using: .utf8)!
                let hash = dataProtection.generateDataHash(for: testData)
                _ = try? dataProtection.validateDataIntegrity(for: testData, expectedHash: hash)
            }
        }
    }
    
    func testConsentManagementPerformance() {
        measure {
            // Test consent management performance
            for i in 0..<1000 {
                let category = ConsentCategory.allCases[i % ConsentCategory.allCases.count]
                consentManager.updateConsent(for: category, granted: i % 2 == 0)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateRequestPrivacy(_ request: URLRequest) throws {
        // Check URL is HTTPS
        guard let url = request.url,
              url.scheme == "https" else {
            throw APIPrivacyError.insecureProtocol
        }
        
        // Validate host is trusted
        let trustedHosts = ["api.anthropic.com"]
        guard let host = url.host,
              trustedHosts.contains(host) else {
            throw APIPrivacyError.untrustedHost
        }
    }
    
    private func containsSensitiveData(in content: String) -> Bool {
        let sensitivePatterns = [
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, // Email
            #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"# // Phone
        ]
        
        for pattern in sensitivePatterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
}