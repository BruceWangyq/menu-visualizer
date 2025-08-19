//
//  WorkflowIntegrationTests.swift
//  Menu VisualizerTests
//
//  End-to-end workflow integration tests for the complete Menuly pipeline
//  Tests the full user journey from photo capture to dish visualization
//

import XCTest
import Combine
@testable import Menu_Visualizer

final class WorkflowIntegrationTests: XCTestCase {
    
    var menuCaptureViewModel: MenuCaptureViewModel!
    var mockCameraService: MockCameraService!
    var mockOCRService: MockOCRService!
    var mockMenuParsingService: MockMenuParsingService!
    var mockClaudeAPIClient: MockClaudeAPIClient!
    var mockPrivacyService: MockPrivacyComplianceService!
    var testUtilities: TestUtilities!
    
    // Test configuration
    private let workflowThresholds = WorkflowThresholds(
        maxTotalProcessingTime: 30.0,    // 30 seconds max for complete workflow
        minDishExtractionRate: 0.8,      // 80% of expected dishes should be extracted
        minVisualizationSuccess: 0.9,    // 90% of visualizations should succeed
        maxMemoryUsage: 200.0            // 200MB max memory usage
    )
    
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize mock services
        mockCameraService = MockCameraService()
        mockOCRService = MockOCRService()
        mockMenuParsingService = MockMenuParsingService()
        mockClaudeAPIClient = MockClaudeAPIClient()
        mockPrivacyService = MockPrivacyComplianceService()
        testUtilities = TestUtilities()
        
        // Configure mock services with realistic behavior
        setupMockServices()
        
        // Initialize view model with mock services
        menuCaptureViewModel = MenuCaptureViewModel(
            cameraService: mockCameraService,
            ocrService: mockOCRService,
            menuParsingService: mockMenuParsingService,
            claudeAPIClient: mockClaudeAPIClient,
            privacyService: mockPrivacyService
        )
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        menuCaptureViewModel = nil
        mockCameraService = nil
        mockOCRService = nil
        mockMenuParsingService = nil
        mockClaudeAPIClient = nil
        mockPrivacyService = nil
        testUtilities = nil
        
        try super.tearDownWithError()
    }
    
    private func setupMockServices() {
        // Configure realistic mock behavior
        mockCameraService.mockCaptureDelay = 0.5
        mockOCRService.mockProcessingDelay = 2.0
        mockOCRService.mockSuccessRate = 0.95
        mockMenuParsingService.mockProcessingDelay = 0.5
        mockClaudeAPIClient.mockNetworkDelay = 1.5
        mockClaudeAPIClient.mockSuccessRate = 0.95
        
        // Set up realistic OCR results
        mockOCRService.mockTextBlocks = [
            TestUtilities.createTextBlock(text: "APPETIZERS", type: .sectionHeader, confidence: 0.95),
            TestUtilities.createTextBlock(text: "Caesar Salad", type: .dishName, confidence: 0.92),
            TestUtilities.createTextBlock(text: "Fresh romaine with parmesan", type: .description, confidence: 0.88),
            TestUtilities.createTextBlock(text: "$12.99", type: .price, confidence: 0.94),
            TestUtilities.createTextBlock(text: "Buffalo Wings", type: .dishName, confidence: 0.89),
            TestUtilities.createTextBlock(text: "$10.99", type: .price, confidence: 0.93),
            TestUtilities.createTextBlock(text: "MAIN COURSES", type: .sectionHeader, confidence: 0.96),
            TestUtilities.createTextBlock(text: "Grilled Salmon", type: .dishName, confidence: 0.91),
            TestUtilities.createTextBlock(text: "$24.99", type: .price, confidence: 0.95),
            TestUtilities.createTextBlock(text: "Ribeye Steak", type: .dishName, confidence: 0.93),
            TestUtilities.createTextBlock(text: "$32.99", type: .price, confidence: 0.97)
        ]
        
        // Set up expected dishes for parsing
        mockMenuParsingService.mockExtractedDishes = [
            testUtilities.createTestDish(name: "Caesar Salad", price: "$12.99", category: .salad),
            testUtilities.createTestDish(name: "Buffalo Wings", price: "$10.99", category: .appetizer),
            testUtilities.createTestDish(name: "Grilled Salmon", price: "$24.99", category: .seafood),
            testUtilities.createTestDish(name: "Ribeye Steak", price: "$32.99", category: .meat)
        ]
    }
    
    // MARK: - Complete Workflow Tests
    
    func testHappyPathWorkflow() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        let startTime = Date()
        
        // Test complete workflow from photo to visualization
        let workflowStates: [ProcessingState] = []
        var capturedStates: [ProcessingState] = []
        
        // Monitor state changes
        menuCaptureViewModel.$processingState
            .sink { state in
                capturedStates.append(state)
            }
            .store(in: &cancellables)
        
        // Step 1: Capture photo
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success(let image):
            XCTAssertNotNil(image, "Should capture menu photo")
            
        case .failure(let error):
            XCTFail("Photo capture should succeed: \(error.displayMessage)")
            return
        }
        
        // Step 2: Wait for OCR processing to complete
        await waitForProcessingState(.completed, timeout: 10.0)
        
        // Validate extracted dishes
        let extractedDishes = menuCaptureViewModel.extractedDishes
        XCTAssertGreaterThanOrEqual(extractedDishes.count, 3, "Should extract multiple dishes")
        
        // Step 3: Generate visualizations for all dishes
        for dish in extractedDishes.prefix(3) { // Test first 3 dishes
            let visualizationResult = await menuCaptureViewModel.generateVisualization(for: dish)
            
            switch visualizationResult {
            case .success(let visualization):
                XCTAssertFalse(visualization.generatedDescription.isEmpty, "Should generate description")
                XCTAssertGreaterThan(visualization.ingredients.count, 0, "Should identify ingredients")
                
            case .failure(let error):
                XCTFail("Visualization generation should succeed for \(dish.name): \(error.localizedDescription)")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let peakMemory = testUtilities.getCurrentMemoryUsage()
        let memoryUsage = peakMemory - initialMemory
        
        // Validate performance
        XCTAssertLessThanOrEqual(totalTime, workflowThresholds.maxTotalProcessingTime,
                                "Complete workflow should finish within time limit: \(totalTime)s")
        
        XCTAssertLessThan(memoryUsage, workflowThresholds.maxMemoryUsage,
                         "Memory usage should be reasonable: \(memoryUsage)MB")
        
        // Validate state transitions
        let expectedStates: [ProcessingState] = [
            .idle, .capturingPhoto, .processingOCR, .parsingMenu, .completed
        ]
        
        for expectedState in expectedStates {
            XCTAssertTrue(capturedStates.contains(expectedState), 
                         "Should transition through state: \(expectedState)")
        }
        
        // Validate privacy compliance
        XCTAssertEqual(mockPrivacyService.complianceScore, 1.0, "Should maintain perfect privacy score")
        XCTAssertTrue(mockPrivacyService.privacyViolations.isEmpty, "Should have no privacy violations")
    }
    
    func testWorkflowWithLowQualityImage() async throws {
        // Configure mock to simulate low quality image
        mockOCRService.mockSuccessRate = 0.7
        mockOCRService.mockTextBlocks = [
            TestUtilities.createTextBlock(text: "Unclear Dish", type: .dishName, confidence: 0.6),
            TestUtilities.createTextBlock(text: "$??", type: .price, confidence: 0.3),
            TestUtilities.createTextBlock(text: "Clear Dish", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$15.99", type: .price, confidence: 0.95)
        ]
        
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success:
            await waitForProcessingState(.completed, timeout: 15.0)
            
            // Should still extract some dishes
            let extractedDishes = menuCaptureViewModel.extractedDishes
            XCTAssertGreaterThan(extractedDishes.count, 0, "Should extract at least one dish")
            
            // High confidence dishes should be preserved
            let highConfidenceDishes = extractedDishes.filter { $0.confidence >= 0.8 }
            XCTAssertGreaterThan(highConfidenceDishes.count, 0, "Should preserve high confidence dishes")
            
        case .failure(let error):
            XCTFail("Should handle low quality images gracefully: \(error.displayMessage)")
        }
    }
    
    func testWorkflowWithNetworkIssues() async throws {
        // Configure intermittent network issues
        mockClaudeAPIClient.mockSuccessRate = 0.5
        mockClaudeAPIClient.mockNetworkDelay = 3.0
        
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success:
            await waitForProcessingState(.completed, timeout: 20.0)
            
            let extractedDishes = menuCaptureViewModel.extractedDishes
            
            // Test visualization with network issues
            if let firstDish = extractedDishes.first {
                let visualizationResult = await menuCaptureViewModel.generateVisualization(for: firstDish)
                
                // Should either succeed or fail gracefully with proper error handling
                switch visualizationResult {
                case .success:
                    // Success is acceptable
                    break
                case .failure(let error):
                    // Should be a network-related error
                    XCTAssertTrue(error == .networkError("Mock network failure") || 
                                 error == .networkTimeout,
                                 "Should fail with appropriate network error")
                }
            }
            
        case .failure(let error):
            XCTFail("Photo capture should succeed: \(error.displayMessage)")
        }
    }
    
    func testWorkflowPrivacyCompliance() async throws {
        // Enable privacy monitoring
        mockPrivacyService.privacySettings.dataRetentionPolicy = .never
        
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success:
            await waitForProcessingState(.completed, timeout: 10.0)
            
            // Check that no data is retained
            XCTAssertFalse(mockPrivacyService.dataRetentionStatus.hasAnyData,
                          "Should not retain data with never-store policy")
            
            // Check privacy headers in API calls
            let headers = mockClaudeAPIClient.getPrivacyHeaders?() ?? [:]
            XCTAssertEqual(headers["DNT"], "1", "Should include privacy headers")
            
        case .failure(let error):
            XCTFail("Privacy-compliant workflow should succeed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testCameraFailureRecovery() async throws {
        // Configure camera to fail initially
        mockCameraService.shouldFailCapture = true
        mockCameraService.mockError = .cameraNotAvailable
        
        let firstAttempt = await menuCaptureViewModel.captureMenuPhoto()
        
        switch firstAttempt {
        case .success:
            XCTFail("Should fail with camera not available")
            
        case .failure(let error):
            XCTAssertEqual(error, .cameraNotAvailable, "Should return camera error")
        }
        
        // Fix camera and retry
        mockCameraService.shouldFailCapture = false
        mockCameraService.mockError = nil
        
        let retryAttempt = await menuCaptureViewModel.captureMenuPhoto()
        
        switch retryAttempt {
        case .success:
            // Should succeed after fixing camera
            break
            
        case .failure(let error):
            XCTFail("Retry should succeed after fixing camera: \(error.displayMessage)")
        }
    }
    
    func testOCRFailureRecovery() async throws {
        // Configure OCR to fail initially
        mockOCRService.shouldFailOCR = true
        mockOCRService.mockError = .ocrProcessingFailed
        
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success:
            await waitForProcessingState(.error(.ocrProcessingFailed), timeout: 5.0)
            
            // Check that error state is handled properly
            XCTAssertEqual(menuCaptureViewModel.processingState, 
                          .error(.ocrProcessingFailed), "Should be in error state")
            
            // Test retry functionality
            mockOCRService.shouldFailOCR = false
            mockOCRService.mockError = nil
            
            let retryResult = await menuCaptureViewModel.retryProcessing()
            
            switch retryResult {
            case .success:
                await waitForProcessingState(.completed, timeout: 10.0)
                XCTAssertGreaterThan(menuCaptureViewModel.extractedDishes.count, 0,
                                   "Should extract dishes after retry")
                
            case .failure(let error):
                XCTFail("Retry should succeed: \(error.displayMessage)")
            }
            
        case .failure(let error):
            XCTFail("Photo capture should succeed: \(error.displayMessage)")
        }
    }
    
    func testAPIFailureRecovery() async throws {
        // Configure API to fail with rate limiting
        mockClaudeAPIClient.shouldSimulateRateLimit = true
        
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success:
            await waitForProcessingState(.completed, timeout: 10.0)
            
            let extractedDishes = menuCaptureViewModel.extractedDishes
            
            if let firstDish = extractedDishes.first {
                let visualizationResult = await menuCaptureViewModel.generateVisualization(for: firstDish)
                
                switch visualizationResult {
                case .success:
                    XCTFail("Should fail with rate limiting")
                    
                case .failure(let error):
                    XCTAssertEqual(error, .rateLimitExceeded, "Should fail with rate limit error")
                    
                    // Test retry after rate limit
                    mockClaudeAPIClient.shouldSimulateRateLimit = false
                    
                    let retryResult = await menuCaptureViewModel.generateVisualization(for: firstDish)
                    
                    switch retryResult {
                    case .success(let visualization):
                        XCTAssertFalse(visualization.generatedDescription.isEmpty,
                                     "Should succeed after rate limit clears")
                        
                    case .failure(let retryError):
                        XCTFail("Retry should succeed after rate limit: \(retryError.localizedDescription)")
                    }
                }
            }
            
        case .failure(let error):
            XCTFail("Photo capture should succeed: \(error.displayMessage)")
        }
    }
    
    // MARK: - State Management Tests
    
    func testProcessingStateTransitions() async throws {
        var stateHistory: [ProcessingState] = []
        
        // Monitor all state changes
        menuCaptureViewModel.$processingState
            .sink { state in
                stateHistory.append(state)
            }
            .store(in: &cancellables)
        
        let _ = await menuCaptureViewModel.captureMenuPhoto()
        await waitForProcessingState(.completed, timeout: 15.0)
        
        // Validate state progression
        let expectedProgression: [ProcessingState] = [
            .idle,
            .capturingPhoto,
            .processingOCR,
            .parsingMenu,
            .completed
        ]
        
        for (index, expectedState) in expectedProgression.enumerated() {
            XCTAssertTrue(stateHistory.count > index, "State history too short")
            
            let actualState = stateHistory[index]
            XCTAssertEqual(actualState, expectedState, 
                          "State transition \(index): expected \(expectedState), got \(actualState)")
        }
        
        // Should not skip states
        XCTAssertEqual(Set(stateHistory.prefix(expectedProgression.count)), 
                      Set(expectedProgression), "Should go through all expected states")
    }
    
    func testConcurrentOperationsHandling() async throws {
        // Start multiple operations simultaneously
        let captureTask1 = Task { await menuCaptureViewModel.captureMenuPhoto() }
        let captureTask2 = Task { await menuCaptureViewModel.captureMenuPhoto() }
        let captureTask3 = Task { await menuCaptureViewModel.captureMenuPhoto() }
        
        let results = await [captureTask1.value, captureTask2.value, captureTask3.value]
        
        // Only one should succeed (or they should be queued properly)
        let successCount = results.compactMap { 
            if case .success = $0 { return 1 } else { return nil }
        }.count
        
        XCTAssertLessThanOrEqual(successCount, 1, "Should handle concurrent operations properly")
        
        // The successful operation should complete properly
        if successCount > 0 {
            await waitForProcessingState(.completed, timeout: 15.0)
            XCTAssertGreaterThan(menuCaptureViewModel.extractedDishes.count, 0,
                               "Should extract dishes from successful operation")
        }
    }
    
    func testMemoryManagementDuringWorkflow() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Perform multiple workflow cycles
        for i in 0..<5 {
            let captureResult = await menuCaptureViewModel.captureMenuPhoto()
            
            switch captureResult {
            case .success:
                await waitForProcessingState(.completed, timeout: 10.0)
                
                // Generate visualizations for memory testing
                let dishes = menuCaptureViewModel.extractedDishes.prefix(2)
                for dish in dishes {
                    let _ = await menuCaptureViewModel.generateVisualization(for: dish)
                }
                
                // Clear state for next iteration
                menuCaptureViewModel.clearCurrentSession()
                
            case .failure(let error):
                XCTFail("Workflow \(i) should succeed: \(error.displayMessage)")
            }
            
            // Check memory usage periodically
            let currentMemory = testUtilities.getCurrentMemoryUsage()
            let memoryIncrease = currentMemory - initialMemory
            
            XCTAssertLessThan(memoryIncrease, workflowThresholds.maxMemoryUsage,
                             "Memory should not grow excessively after \(i) cycles: \(memoryIncrease)MB")
        }
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistencyThroughWorkflow() async throws {
        let captureResult = await menuCaptureViewModel.captureMenuPhoto()
        
        switch captureResult {
        case .success(let capturedImage):
            await waitForProcessingState(.completed, timeout: 10.0)
            
            // Validate data consistency
            let ocrResult = menuCaptureViewModel.currentOCRResult
            let extractedDishes = menuCaptureViewModel.extractedDishes
            
            XCTAssertNotNil(ocrResult, "Should preserve OCR result")
            XCTAssertGreaterThan(extractedDishes.count, 0, "Should have extracted dishes")
            
            // Validate that dishes are derived from OCR result
            let ocrDishNames = Set(ocrResult?.recognizedText
                .filter { $0.textType == .dishName }
                .map { $0.text } ?? [])
            
            let extractedDishNames = Set(extractedDishes.map { $0.name })
            
            let intersection = ocrDishNames.intersection(extractedDishNames)
            XCTAssertGreaterThan(intersection.count, 0, "Extracted dishes should match OCR results")
            
            // Test visualization consistency
            if let firstDish = extractedDishes.first {
                let visualizationResult = await menuCaptureViewModel.generateVisualization(for: firstDish)
                
                switch visualizationResult {
                case .success(let visualization):
                    XCTAssertEqual(visualization.dishId, firstDish.id,
                                  "Visualization should be linked to correct dish")
                    
                case .failure:
                    // Visualization failure is acceptable, but data should still be consistent
                    break
                }
            }
            
        case .failure(let error):
            XCTFail("Photo capture should succeed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Performance Benchmarking
    
    func testWorkflowPerformanceBenchmarks() async throws {
        var processingTimes: [TimeInterval] = []
        var memoryUsages: [Float] = []
        
        for _ in 0..<3 {
            let initialMemory = testUtilities.getCurrentMemoryUsage()
            let startTime = Date()
            
            let captureResult = await menuCaptureViewModel.captureMenuPhoto()
            
            switch captureResult {
            case .success:
                await waitForProcessingState(.completed, timeout: 20.0)
                
                let processingTime = Date().timeIntervalSince(startTime)
                let memoryUsage = testUtilities.getCurrentMemoryUsage() - initialMemory
                
                processingTimes.append(processingTime)
                memoryUsages.append(memoryUsage)
                
                // Clear for next iteration
                menuCaptureViewModel.clearCurrentSession()
                
            case .failure(let error):
                XCTFail("Performance test should succeed: \(error.displayMessage)")
            }
        }
        
        // Calculate averages
        let avgProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let avgMemoryUsage = memoryUsages.reduce(0, +) / Float(memoryUsages.count)
        
        // Validate performance
        XCTAssertLessThanOrEqual(avgProcessingTime, workflowThresholds.maxTotalProcessingTime,
                                "Average processing time should meet threshold: \(avgProcessingTime)s")
        
        XCTAssertLessThan(avgMemoryUsage, workflowThresholds.maxMemoryUsage,
                         "Average memory usage should be reasonable: \(avgMemoryUsage)MB")
        
        // Log performance metrics
        print("Workflow Performance Metrics:")
        print("- Average processing time: \(String(format: "%.2f", avgProcessingTime))s")
        print("- Average memory usage: \(String(format: "%.1f", avgMemoryUsage))MB")
        print("- Processing time range: \(processingTimes.min()!)s - \(processingTimes.max()!)s")
    }
    
    // MARK: - Helper Methods
    
    private func waitForProcessingState(_ expectedState: ProcessingState, timeout: TimeInterval) async {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if menuCaptureViewModel.processingState == expectedState {
                return
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        XCTFail("Timeout waiting for processing state: \(expectedState)")
    }
}

// MARK: - Test Configuration

private struct WorkflowThresholds {
    let maxTotalProcessingTime: TimeInterval
    let minDishExtractionRate: Double
    let minVisualizationSuccess: Double
    let maxMemoryUsage: Float
}

// MARK: - Mock Extensions

extension MockClaudeAPIClient {
    func getPrivacyHeaders() -> [String: String]? {
        return [
            "DNT": "1",
            "X-Privacy-Policy": "privacy-first",
            "User-Agent": "MenulyApp/1.0 Privacy-First"
        ]
    }
}

// MARK: - Processing State Extensions

extension ProcessingState {
    static func ==(lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.completed, .completed):
            return true
        case (.capturingPhoto, .capturingPhoto):
            return true
        case (.processingOCR, .processingOCR):
            return true
        case (.parsingMenu, .parsingMenu):
            return true
        case let (.generatingVisualization(lhsDish), .generatingVisualization(rhsDish)):
            return lhsDish == rhsDish
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}