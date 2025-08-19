//
//  ClaudeAPITests.swift
//  Menu VisualizerTests
//
//  Comprehensive testing suite for Claude API integration
//  Tests authentication, request/response handling, error scenarios, and performance
//

import XCTest
import Network
@testable import Menu_Visualizer

final class ClaudeAPITests: XCTestCase {
    
    var claudeAPIClient: ClaudeAPIClient!
    var mockNetworkSession: MockURLSession!
    var apiPrivacyLayer: APIPrivacyLayer!
    var testUtilities: TestUtilities!
    
    // Test configuration
    private let apiThresholds = APIThresholds(
        maxResponseTime: 10.0,       // 10 seconds maximum response time
        minSuccessRate: 0.99,        // 99% success rate for valid requests
        maxRetryAttempts: 3,         // Maximum retry attempts
        timeoutInterval: 30.0        // Request timeout
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockNetworkSession = MockURLSession()
        claudeAPIClient = ClaudeAPIClient(session: mockNetworkSession)
        apiPrivacyLayer = APIPrivacyLayer()
        testUtilities = TestUtilities()
        
        // Configure test environment
        claudeAPIClient.setTestMode(enabled: true)
    }
    
    override func tearDownWithError() throws {
        claudeAPIClient = nil
        mockNetworkSession = nil
        apiPrivacyLayer = nil
        testUtilities = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Authentication Tests
    
    func testAPIKeyValidation() async throws {
        // Test valid API key format
        let validAPIKey = "sk-ant-api03-\(String(repeating: "x", count: 64))-\(String(repeating: "y", count: 32))-AA"
        claudeAPIClient.setAPIKey(validAPIKey)
        
        let isValid = claudeAPIClient.validateAPIKey()
        XCTAssertTrue(isValid, "Should validate correct API key format")
        
        // Test invalid API key formats
        let invalidKeys = [
            "",
            "invalid-key",
            "sk-wrong-format",
            String(repeating: "x", count: 200) // Too long
        ]
        
        for invalidKey in invalidKeys {
            claudeAPIClient.setAPIKey(invalidKey)
            let isValid = claudeAPIClient.validateAPIKey()
            XCTAssertFalse(isValid, "Should reject invalid API key: \(invalidKey)")
        }
    }
    
    func testAPIKeySecureStorage() throws {
        let testAPIKey = "sk-ant-api03-test-key-for-secure-storage"
        
        // Test storing API key securely
        try claudeAPIClient.storeAPIKeySecurely(testAPIKey)
        
        // Test retrieving API key
        let retrievedKey = try claudeAPIClient.getSecureAPIKey()
        XCTAssertEqual(retrievedKey, testAPIKey, "Should retrieve stored API key")
        
        // Test key deletion
        try claudeAPIClient.deleteStoredAPIKey()
        
        XCTAssertThrowsError(try claudeAPIClient.getSecureAPIKey()) { error in
            XCTAssertTrue(error is ClaudeAPIError, "Should throw API error when key not found")
        }
    }
    
    func testAuthenticationHeaders() {
        let testAPIKey = "sk-ant-api03-test-authentication-headers"
        claudeAPIClient.setAPIKey(testAPIKey)
        
        let headers = claudeAPIClient.getAuthenticationHeaders()
        
        XCTAssertEqual(headers["x-api-key"], testAPIKey, "Should include API key in headers")
        XCTAssertEqual(headers["anthropic-version"], "2023-06-01", "Should include correct API version")
        XCTAssertEqual(headers["content-type"], "application/json", "Should set correct content type")
        
        // Test privacy headers are included
        XCTAssertNotNil(headers["User-Agent"], "Should include privacy-focused user agent")
        XCTAssertEqual(headers["DNT"], "1", "Should include Do Not Track header")
    }
    
    // MARK: - Request/Response Tests
    
    func testSuccessfulVisualizationRequest() async throws {
        let testDish = Dish(name: "Grilled Salmon", description: "Fresh Atlantic salmon with herbs",
                           price: "$24.99", category: .seafood, confidence: 0.9)
        
        // Mock successful response
        let mockResponse = """
        {
            "success": true,
            "visualization": {
                "description": "A beautifully grilled piece of Atlantic salmon with a golden-brown exterior",
                "visualStyle": "appetizing, restaurant-quality presentation",
                "ingredients": ["Atlantic salmon fillet", "fresh herbs", "lemon", "olive oil"],
                "preparationNotes": "Grilled to medium, seasoned with herbs and finished with lemon"
            }
        }
        """
        
        mockNetworkSession.mockResponse(data: mockResponse.data(using: .utf8)!, statusCode: 200)
        
        let startTime = Date()
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        let responseTime = Date().timeIntervalSince(startTime)
        
        // Test response time
        XCTAssertLessThanOrEqual(responseTime, apiThresholds.maxResponseTime,
                                "Response time exceeded threshold: \(responseTime)s")
        
        // Test response parsing
        switch result {
        case .success(let visualization):
            XCTAssertEqual(visualization.dishId, testDish.id, "Should link to correct dish")
            XCTAssertFalse(visualization.generatedDescription.isEmpty, "Should have generated description")
            XCTAssertFalse(visualization.visualStyle.isEmpty, "Should have visual style")
            XCTAssertGreaterThan(visualization.ingredients.count, 0, "Should have ingredients")
            XCTAssertFalse(visualization.preparationNotes.isEmpty, "Should have preparation notes")
            
        case .failure(let error):
            XCTFail("Request should succeed: \(error.localizedDescription)")
        }
    }
    
    func testMalformedResponseHandling() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Test malformed JSON response
        let malformedResponse = """
        {
            "success": true,
            "visualization": {
                "description": "Test description"
                // Missing comma and closing brace
        """
        
        mockNetworkSession.mockResponse(data: malformedResponse.data(using: .utf8)!, statusCode: 200)
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success:
            XCTFail("Should fail to parse malformed JSON")
            
        case .failure(let error):
            if case .jsonParsingError = error {
                // Expected behavior
            } else {
                XCTFail("Should return JSON parsing error: \(error)")
            }
        }
    }
    
    func testEmptyResponseHandling() async throws {
        let testDish = testUtilities.createTestDish()
        
        mockNetworkSession.mockResponse(data: Data(), statusCode: 200)
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success:
            XCTFail("Should fail with empty response")
            
        case .failure(let error):
            XCTAssertTrue(error == .jsonParsingError || error == .emptyResponse,
                         "Should handle empty response appropriately")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHTTPErrorCodes() async throws {
        let testDish = testUtilities.createTestDish()
        
        let errorCodes = [400, 401, 403, 404, 429, 500, 502, 503]
        
        for statusCode in errorCodes {
            let errorResponse = """
            {
                "error": {
                    "type": "invalid_request_error",
                    "message": "Test error for status code \(statusCode)"
                }
            }
            """
            
            mockNetworkSession.mockResponse(data: errorResponse.data(using: .utf8)!, statusCode: statusCode)
            
            let result = await claudeAPIClient.generateDishVisualization(for: testDish)
            
            switch result {
            case .success:
                XCTFail("Should fail with HTTP error code \(statusCode)")
                
            case .failure(let error):
                switch statusCode {
                case 401:
                    XCTAssertTrue(error == .authenticationFailed, "Should handle auth error")
                case 429:
                    XCTAssertTrue(error == .rateLimitExceeded, "Should handle rate limit")
                case 500...599:
                    XCTAssertTrue(error == .serverError("Server error"), "Should handle server error")
                default:
                    XCTAssertTrue(error == .invalidRequest("Client error"), "Should handle client error")
                }
            }
        }
    }
    
    func testNetworkTimeoutHandling() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Configure timeout
        claudeAPIClient.setRequestTimeout(1.0) // 1 second timeout
        
        // Mock delayed response (simulate timeout)
        mockNetworkSession.mockDelayedResponse(delay: 2.0, data: Data(), statusCode: 200)
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success:
            XCTFail("Should timeout")
            
        case .failure(let error):
            XCTAssertTrue(error == .networkTimeout, "Should handle timeout error")
        }
    }
    
    func testNetworkConnectivityHandling() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Mock network error
        mockNetworkSession.mockNetworkError(NSError(domain: NSURLErrorDomain,
                                                    code: NSURLErrorNotConnectedToInternet,
                                                    userInfo: nil))
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success:
            XCTFail("Should fail with network error")
            
        case .failure(let error):
            XCTAssertTrue(error == .noInternetConnection, "Should handle connectivity error")
        }
    }
    
    // MARK: - Privacy Validation Tests
    
    func testRequestPrivacyValidation() async throws {
        let sensitiveTestDish = Dish(name: "User's Personal Dish", 
                                   description: "Contains user@example.com contact info",
                                   price: "$25.00", category: .mainCourse, confidence: 0.9)
        
        // This should be caught by privacy validation
        let result = await claudeAPIClient.generateDishVisualization(for: sensitiveTestDish)
        
        switch result {
        case .success:
            XCTFail("Should reject request with sensitive data")
            
        case .failure(let error):
            XCTAssertTrue(error == .privacyViolation("Sensitive data detected"),
                         "Should detect and reject sensitive data")
        }
    }
    
    func testPayloadSanitization() {
        let testDish = Dish(name: "Test Dish <script>alert('xss')</script>",
                           description: "Description with SQL'; DROP TABLE dishes;--",
                           price: "$15.99", category: .mainCourse, confidence: 0.9)
        
        let sanitizedPayload = claudeAPIClient.createSanitizedPayload(for: testDish)
        
        XCTAssertFalse(sanitizedPayload.name.contains("<script>"), "Should sanitize HTML")
        XCTAssertFalse(sanitizedPayload.description?.contains("DROP TABLE") ?? false, "Should sanitize SQL")
        
        // Should preserve safe content
        XCTAssertTrue(sanitizedPayload.name.contains("Test Dish"), "Should preserve safe content")
        XCTAssertTrue(sanitizedPayload.description?.contains("Description") ?? false, "Should preserve safe content")
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryOnTransientErrors() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Mock sequence: fail, fail, succeed
        let responses = [
            MockResponse(data: Data(), statusCode: 503, delay: 0.1), // Service unavailable
            MockResponse(data: Data(), statusCode: 429, delay: 0.1), // Rate limited
            MockResponse(data: testUtilities.createSuccessResponse().data(using: .utf8)!, statusCode: 200, delay: 0.1)
        ]
        
        mockNetworkSession.mockSequentialResponses(responses)
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success(let visualization):
            XCTAssertFalse(visualization.generatedDescription.isEmpty, "Should eventually succeed")
            
        case .failure(let error):
            XCTFail("Should succeed after retries: \(error)")
        }
        
        // Verify retry attempts
        XCTAssertEqual(mockNetworkSession.requestCount, 3, "Should have made 3 requests")
    }
    
    func testMaxRetryLimitRespected() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Mock consistent failures
        for _ in 0..<5 {
            mockNetworkSession.mockResponse(data: Data(), statusCode: 503)
        }
        
        let result = await claudeAPIClient.generateDishVisualization(for: testDish)
        
        switch result {
        case .success:
            XCTFail("Should fail after max retries")
            
        case .failure(let error):
            XCTAssertTrue(error == .maxRetriesExceeded, "Should respect max retry limit")
        }
        
        // Should not exceed max retry attempts
        XCTAssertLessThanOrEqual(mockNetworkSession.requestCount, apiThresholds.maxRetryAttempts + 1,
                                "Should respect max retry limit")
    }
    
    func testExponentialBackoff() async throws {
        let testDish = testUtilities.createTestDish()
        
        // Mock failures to trigger retries
        for _ in 0..<3 {
            mockNetworkSession.mockResponse(data: Data(), statusCode: 503)
        }
        
        let startTime = Date()
        let _ = await claudeAPIClient.generateDishVisualization(for: testDish)
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Should take time due to exponential backoff
        // Expected delays: 0.5s, 1.0s, 2.0s = 3.5s minimum
        XCTAssertGreaterThan(totalTime, 3.0, "Should implement exponential backoff")
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimitingRespected() async throws {
        let dishes = (0..<10).map { index in
            testUtilities.createTestDish(name: "Test Dish \(index)")
        }
        
        // Mock rate limit responses
        mockNetworkSession.mockResponse(data: Data(), statusCode: 429)
        
        var rateLimitErrors = 0
        
        // Make concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for dish in dishes {
                group.addTask {
                    let result = await self.claudeAPIClient.generateDishVisualization(for: dish)
                    if case .failure(let error) = result, error == .rateLimitExceeded {
                        rateLimitErrors += 1
                    }
                }
            }
        }
        
        XCTAssertGreaterThan(rateLimitErrors, 0, "Should detect rate limiting")
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentRequestHandling() async throws {
        let dishes = (0..<5).map { index in
            testUtilities.createTestDish(name: "Concurrent Dish \(index)")
        }
        
        // Mock successful responses
        for _ in dishes {
            mockNetworkSession.mockResponse(
                data: testUtilities.createSuccessResponse().data(using: .utf8)!,
                statusCode: 200
            )
        }
        
        let startTime = Date()
        
        // Execute concurrent requests
        let results = await withTaskGroup(of: Result<DishVisualization, ClaudeAPIError>.self, returning: [Result<DishVisualization, ClaudeAPIError>].self) { group in
            for dish in dishes {
                group.addTask {
                    return await self.claudeAPIClient.generateDishVisualization(for: dish)
                }
            }
            
            var results: [Result<DishVisualization, ClaudeAPIError>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Should handle concurrent requests efficiently
        XCTAssertLessThan(totalTime, 15.0, "Concurrent requests should complete efficiently")
        
        // All requests should succeed
        let successCount = results.filter { 
            if case .success = $0 { return true }
            return false
        }.count
        
        XCTAssertEqual(successCount, dishes.count, "All concurrent requests should succeed")
    }
    
    func testMemoryUsageUnderLoad() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Generate many requests to test memory usage
        let dishes = (0..<50).map { index in
            testUtilities.createTestDish(name: "Memory Test Dish \(index)")
        }
        
        for dish in dishes {
            mockNetworkSession.mockResponse(
                data: testUtilities.createSuccessResponse().data(using: .utf8)!,
                statusCode: 200
            )
        }
        
        // Execute requests
        for dish in dishes {
            let _ = await claudeAPIClient.generateDishVisualization(for: dish)
        }
        
        let peakMemory = testUtilities.getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Memory usage should be reasonable
        XCTAssertLessThan(memoryIncrease, 50.0, "Memory usage should remain reasonable: \(memoryIncrease)MB")
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndVisualizationWorkflow() async throws {
        // This test uses real network calls in integration environment
        guard claudeAPIClient.isIntegrationTestEnabled() else {
            throw XCTSkip("Integration tests disabled")
        }
        
        let realDish = Dish(name: "Grilled Salmon", 
                           description: "Fresh Atlantic salmon with seasonal vegetables",
                           price: "$26.99", category: .seafood, confidence: 0.95)
        
        let result = await claudeAPIClient.generateDishVisualization(for: realDish)
        
        switch result {
        case .success(let visualization):
            XCTAssertFalse(visualization.generatedDescription.isEmpty, "Should generate description")
            XCTAssertGreaterThan(visualization.ingredients.count, 0, "Should identify ingredients")
            XCTAssertFalse(visualization.preparationNotes.isEmpty, "Should provide preparation notes")
            
            // Validate content quality
            XCTAssertTrue(visualization.generatedDescription.contains("salmon") ||
                         visualization.generatedDescription.contains("fish"),
                         "Description should be relevant to dish")
            
        case .failure(let error):
            XCTFail("Integration test failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Test Configuration and Helpers

private struct APIThresholds {
    let maxResponseTime: TimeInterval
    let minSuccessRate: Double
    let maxRetryAttempts: Int
    let timeoutInterval: TimeInterval
}

// MARK: - Mock Network Session

private class MockURLSession: URLSessionProtocol {
    var mockResponses: [MockResponse] = []
    var mockError: Error?
    var requestCount = 0
    
    func mockResponse(data: Data, statusCode: Int) {
        mockResponses = [MockResponse(data: data, statusCode: statusCode, delay: 0)]
    }
    
    func mockSequentialResponses(_ responses: [MockResponse]) {
        mockResponses = responses
    }
    
    func mockNetworkError(_ error: Error) {
        mockError = error
    }
    
    func mockDelayedResponse(delay: TimeInterval, data: Data, statusCode: Int) {
        mockResponses = [MockResponse(data: data, statusCode: statusCode, delay: delay)]
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        guard let mockResponse = mockResponses.first else {
            throw URLError(.badServerResponse)
        }
        
        // Remove used response for sequential testing
        if mockResponses.count > 1 {
            mockResponses.removeFirst()
        }
        
        // Simulate delay if specified
        if mockResponse.delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(mockResponse.delay * 1_000_000_000))
        }
        
        let httpResponse = HTTPURLResponse(url: request.url!, 
                                         statusCode: mockResponse.statusCode,
                                         httpVersion: nil,
                                         headerFields: nil)!
        
        return (mockResponse.data, httpResponse)
    }
}

private struct MockResponse {
    let data: Data
    let statusCode: Int
    let delay: TimeInterval
}

// Protocol to allow dependency injection
private protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}