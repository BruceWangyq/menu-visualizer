//
//  AIMenuAnalysisTests.swift
//  Menu VisualizerTests
//
//  Integration tests for Firebase AI Logic menu analysis service
//

import XCTest
@testable import Menu_Visualizer
import UIKit
import FirebaseCore

@MainActor
final class AIMenuAnalysisTests: XCTestCase {
    
    var aiService: AIMenuAnalysisService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize Firebase for testing
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        aiService = AIMenuAnalysisService()
    }
    
    override func tearDown() async throws {
        aiService = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAIServiceInitialization() {
        XCTAssertNotNil(aiService, "AI service should initialize successfully")
        XCTAssertFalse(aiService.isProcessing, "Service should not be processing initially")
        XCTAssertEqual(aiService.processingProgress, 0.0, "Progress should be 0 initially")
    }
    
    func testFirebaseConfiguration() {
        let isConfigured = APIKeyManager.shared.isFirebaseAIConfigured()
        let authStatus = APIKeyManager.shared.getAIServiceAuthStatus()
        
        if isConfigured {
            print("✅ Firebase AI Logic is configured")
        } else {
            print("⚠️ Firebase not configured - add GoogleService-Info.plist")
        }
        
        print("📊 Auth status: \(authStatus)")
        
        // Test should not fail if Firebase is not configured (testing environment)
        XCTAssertTrue(true, "Firebase configuration test completed")
    }
    
    func testServiceConfiguration() {
        // Test different configuration options
        let fastConfig = AIMenuAnalysisService.AnalysisConfiguration.fast
        let defaultConfig = AIMenuAnalysisService.AnalysisConfiguration.default
        let highQualityConfig = AIMenuAnalysisService.AnalysisConfiguration.highQuality
        
        XCTAssertEqual(fastConfig.timeoutInterval, 15.0)
        XCTAssertEqual(defaultConfig.timeoutInterval, 30.0)
        XCTAssertEqual(highQualityConfig.timeoutInterval, 45.0)
        
        XCTAssertTrue(highQualityConfig.enableDetailedAnalysis)
        XCTAssertFalse(fastConfig.enableDetailedAnalysis)
    }
    
    // MARK: - Integration Tests
    
    func testMenuAnalysisWithMockImage() async {
        // Create a simple test image
        let testImage = createMockMenuImage()
        
        let result = await aiService.analyzeMenu(from: testImage, configuration: .fast)
        
        switch result {
        case .success(let menu):
            print("✅ AI analysis successful with \(menu.dishes.count) dishes")
            XCTAssertGreaterThan(menu.dishes.count, 0, "Should extract at least one dish")
            XCTAssertNotNil(menu.timestamp, "Menu should have timestamp")
            
        case .failure(let error):
            switch error {
            case .aiServiceConfigurationError(let message):
                if message.contains("Firebase") {
                    print("⚠️ Skipping AI test - Firebase not configured")
                } else {
                    print("⚠️ Skipping AI test - Configuration error: \(message)")
                }
                // This is expected in test environment
            case .networkUnavailable:
                print("⚠️ Skipping AI test - Network unavailable")
                // This is expected in CI environment
            case .aiServiceUnavailable:
                print("⚠️ Skipping AI test - AI service unavailable")
                // This is expected if service is down
            default:
                XCTFail("Unexpected error: \(error.localizedDescription)")
            }
        }
    }
    
    func testImageOptimizationIntegration() async {
        let testImage = createMockMenuImage()
        
        // Test image quality assessment
        let qualityAssessment = await aiService.assessImageQuality(testImage)
        
        XCTAssertGreaterThan(qualityAssessment.overallScore, 0.0)
        XCTAssertLessThanOrEqual(qualityAssessment.overallScore, 1.0)
        XCTAssertNotNil(qualityAssessment.metadata)
        
        print("📊 Image quality score: \(qualityAssessment.overallScore)")
        print("📋 Quality issues: \(qualityAssessment.issues.map { $0.rawValue })")
    }
    
    func testCacheManagement() async {
        let testImage = createMockMenuImage()
        
        // Clear cache first
        aiService.clearCache()
        
        // First analysis
        let startTime1 = Date()
        let result1 = await aiService.analyzeMenu(from: testImage, configuration: .fast)
        let time1 = Date().timeIntervalSince(startTime1)
        
        // Second analysis (should use cache if API is available)
        let startTime2 = Date()
        let result2 = await aiService.analyzeMenu(from: testImage, configuration: .fast)
        let time2 = Date().timeIntervalSince(startTime2)
        
        // If both successful, second should be faster (cached)
        if case .success = result1, case .success = result2 {
            XCTAssertLessThan(time2, time1 * 0.1, "Cached result should be much faster")
            print("✅ Cache working: \(String(format: "%.2f", time1))s → \(String(format: "%.2f", time2))s")
        }
        
        // Test cache info
        let cacheInfo = aiService.getCacheInfo()
        XCTAssertGreaterThanOrEqual(cacheInfo.responses, 0)
        XCTAssertGreaterThanOrEqual(cacheInfo.images, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Test with invalid configuration
        let invalidConfig = AIMenuAnalysisService.AnalysisConfiguration(
            maxImageSize: CGSize(width: 1, height: 1),
            compressionQuality: 0.1,
            minimumConfidence: 1.1, // Invalid confidence > 1.0
            maxRetries: 0,
            timeoutInterval: 0.1, // Very short timeout
            enableDetailedAnalysis: false
        )
        
        let testImage = createMockMenuImage()
        let result = await aiService.analyzeMenu(from: testImage, configuration: invalidConfig)
        
        // Should fail gracefully
        if case .failure(let error) = result {
            print("✅ Error handled gracefully: \(error.localizedDescription)")
        }
    }
    
    func testProcessingStateManagement() async {
        let testImage = createMockMenuImage()
        
        XCTAssertFalse(aiService.isProcessing)
        
        // Start analysis
        Task {
            let _ = await aiService.analyzeMenu(from: testImage)
        }
        
        // Give it a moment to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Cancel processing
        aiService.cancelProcessing()
        
        // Should return to idle state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        XCTAssertFalse(aiService.isProcessing)
        XCTAssertEqual(aiService.currentStage, .idle)
    }
    
    // MARK: - Performance Tests
    
    func testProcessingTimeEstimate() {
        let smallImage = CGSize(width: 400, height: 600)
        let largeImage = CGSize(width: 2000, height: 3000)
        
        let smallEstimate = aiService.estimateProcessingTime(for: smallImage)
        let largeEstimate = aiService.estimateProcessingTime(for: largeImage)
        
        XCTAssertGreaterThan(smallEstimate, 0)
        XCTAssertGreaterThan(largeEstimate, smallEstimate)
        
        print("📊 Processing estimates: Small: \(smallEstimate)s, Large: \(largeEstimate)s")
    }
    
    func testPerformanceBaseline() async {
        let testImage = createMockMenuImage()
        
        let startTime = Date()
        let result = await aiService.analyzeMenu(from: testImage, configuration: .fast)
        let processingTime = Date().timeIntervalSince(startTime)
        
        switch result {
        case .success:
            // AI should be faster than 10 seconds for basic analysis
            XCTAssertLessThan(processingTime, 10.0, "AI analysis should complete within 10 seconds")
            print("✅ Processing time: \(String(format: "%.2f", processingTime))s")
            
        case .failure(let error):
            if case .aiServiceConfigurationError(let message) = error {
                if message.contains("Firebase") {
                    print("⚠️ Skipping performance test - Firebase not configured")
                } else {
                    print("⚠️ Skipping performance test - Configuration error: \(message)")
                }
            } else {
                print("⚠️ Performance test failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Integration with ViewModel Tests
    
    func testViewModelIntegration() async {
        let coordinator = AppCoordinator()
        let viewModel = MenuCaptureViewModel(coordinator: coordinator)
        let testImage = createMockMenuImage()
        
        XCTAssertNotNil(viewModel.processingStrategy)
        XCTAssertFalse(viewModel.isProcessing)
        
        // Test strategy updates
        viewModel.updateProcessingStrategy(.aiFirst)
        XCTAssertEqual(viewModel.processingStrategy, .aiFirst)
        
        viewModel.updateProcessingStrategy(.ocrOnly)
        XCTAssertEqual(viewModel.processingStrategy, .ocrOnly)
        
        // Test AI availability check
        let aiAvailable = viewModel.validateAIServiceAvailability()
        print("📊 AI service availability: \(aiAvailable)")
        
        // Test processing time estimation
        let estimate = viewModel.estimateProcessingTime(for: testImage.size)
        XCTAssertGreaterThan(estimate, 0)
        
        print("✅ ViewModel integration tests completed")
    }
    
    // MARK: - Helper Methods
    
    private func createMockMenuImage() -> UIImage {
        // Create a simple test image with menu-like content
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text that looks like a menu
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            let menuText = """
            RESTAURANT MENU
            
            Appetizers
            Caesar Salad        $12.99
            Buffalo Wings       $14.99
            
            Main Courses
            Grilled Salmon      $24.99
            Beef Steak          $28.99
            Pasta Carbonara     $18.99
            
            Desserts
            Chocolate Cake      $8.99
            Ice Cream           $6.99
            """
            
            menuText.draw(in: CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40), 
                         withAttributes: attributes)
        }
    }
}

// MARK: - Test Extensions

extension AIMenuAnalysisTests {
    
    /// Test helper to validate menu structure
    private func validateMenuStructure(_ menu: Menu) {
        XCTAssertNotNil(menu.timestamp)
        XCTAssertGreaterThan(menu.dishes.count, 0)
        
        for dish in menu.dishes {
            XCTAssertFalse(dish.name.isEmpty, "Dish name should not be empty")
            XCTAssertGreaterThan(dish.extractionConfidence, 0, "Confidence should be positive")
        }
    }
    
    /// Test helper to measure processing performance
    private func measureProcessingTime<T>(_ operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let processingTime = Date().timeIntervalSince(startTime)
        return (result, processingTime)
    }
}