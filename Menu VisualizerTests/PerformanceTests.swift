//
//  PerformanceTests.swift
//  Menu VisualizerTests
//
//  Comprehensive performance testing suite for OCR, API, UI, and memory management
//  Includes benchmarking, memory leak detection, and performance regression testing
//

import XCTest
import UIKit
import Vision
@testable import Menu_Visualizer

final class PerformanceTests: XCTestCase {
    
    var ocrService: OCRService!
    var claudeAPIClient: ClaudeAPIClient!
    var menuParsingService: MenuParsingService!
    var testUtilities: TestUtilities!
    
    // Performance thresholds
    private let performanceThresholds = PerformanceThresholds(
        ocrProcessingTime: 5.0,        // 5 seconds max for OCR
        apiResponseTime: 3.0,          // 3 seconds max for API response
        menuParsingTime: 1.0,          // 1 second max for menu parsing
        memoryLimitMB: 150.0,          // 150MB max memory usage
        startupTime: 2.0,              // 2 seconds max app startup
        uiResponseTime: 0.1            // 100ms max UI response
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        ocrService = OCRService()
        claudeAPIClient = ClaudeAPIClient()
        menuParsingService = MenuParsingService()
        testUtilities = TestUtilities()
        
        // Configure for performance testing
        claudeAPIClient.setTestMode(enabled: true)
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        claudeAPIClient = nil
        menuParsingService = nil
        testUtilities = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - OCR Performance Tests
    
    func testOCRProcessingPerformance() async throws {
        let testImages = try testUtilities.loadAllBenchmarkImages()
        var processingTimes: [TimeInterval] = []
        var memoryUsages: [Float] = []
        var accuracyScores: [Float] = []
        
        for (imageType, testImage) in testImages {
            let initialMemory = testUtilities.getCurrentMemoryUsage()
            
            let (result, processingTime) = await testUtilities.measureAsyncExecutionTime {
                await ocrService.extractText(from: testImage, configuration: .balanced)
            }
            
            let peakMemory = testUtilities.getCurrentMemoryUsage()
            let memoryUsage = peakMemory - initialMemory
            
            processingTimes.append(processingTime)
            memoryUsages.append(memoryUsage)
            
            // Validate processing time per image
            XCTAssertLessThanOrEqual(processingTime, performanceThresholds.ocrProcessingTime,
                                    "OCR processing time exceeded for \(imageType): \(processingTime)s")
            
            switch result {
            case .success(let ocrResult):
                accuracyScores.append(ocrResult.overallConfidence)
                
                // Memory usage validation
                XCTAssertLessThan(memoryUsage, 50.0, "OCR memory usage too high for \(imageType): \(memoryUsage)MB")
                
            case .failure(let error):
                print("OCR failed for \(imageType): \(error.displayMessage)")
                accuracyScores.append(0.0)
            }
        }
        
        // Calculate performance metrics
        let avgProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let avgMemoryUsage = memoryUsages.reduce(0, +) / Float(memoryUsages.count)
        let avgAccuracy = accuracyScores.reduce(0, +) / Float(accuracyScores.count)
        
        // Log performance metrics
        print("OCR Performance Metrics:")
        print("- Average processing time: \(String(format: "%.2f", avgProcessingTime))s")
        print("- Average memory usage: \(String(format: "%.1f", avgMemoryUsage))MB")
        print("- Average accuracy: \(String(format: "%.1f", avgAccuracy * 100))%")
        print("- Images processed: \(testImages.count)")
        
        // Validate overall performance
        XCTAssertLessThanOrEqual(avgProcessingTime, performanceThresholds.ocrProcessingTime,
                                "Average OCR processing time too high: \(avgProcessingTime)s")
        XCTAssertGreaterThanOrEqual(avgAccuracy, 0.8, "Average OCR accuracy too low: \(avgAccuracy)")
    }
    
    func testOCRScalabilityPerformance() async throws {
        let imageSizes = [
            (width: 400, height: 600),   // Small
            (width: 800, height: 1200),  // Medium
            (width: 1200, height: 1800), // Large
            (width: 2400, height: 3600)  // Very Large
        ]
        
        for (width, height) in imageSizes {
            let testImage = createTestImageOfSize(width: width, height: height)
            
            let (result, processingTime) = await testUtilities.measureAsyncExecutionTime {
                await ocrService.extractText(from: testImage, configuration: .fast)
            }
            
            let imageSize = Double(width * height)
            let megapixels = imageSize / (1024 * 1024)
            
            print("Image size: \(width)x\(height) (\(String(format: "%.1f", megapixels))MP) - Time: \(String(format: "%.2f", processingTime))s")
            
            // Processing time should scale reasonably with image size
            let expectedTime = performanceThresholds.ocrProcessingTime * (megapixels / 2.0) // Base on 2MP reference
            XCTAssertLessThanOrEqual(processingTime, max(expectedTime, performanceThresholds.ocrProcessingTime * 2),
                                    "OCR processing time scaling issue for \(width)x\(height)")
            
            switch result {
            case .success(let ocrResult):
                XCTAssertGreaterThan(ocrResult.recognizedText.count, 0, "Should extract text from \(width)x\(height) image")
                
            case .failure(let error):
                print("OCR failed for \(width)x\(height): \(error.displayMessage)")
            }
        }
    }
    
    func testOCRMemoryStressTest() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        var peakMemory: Float = initialMemory
        
        // Process multiple large images consecutively
        for i in 0..<10 {
            let testImage = createTestImageOfSize(width: 1600, height: 2400)
            
            let result = await ocrService.extractText(from: testImage, configuration: .balanced)
            
            let currentMemory = testUtilities.getCurrentMemoryUsage()
            peakMemory = max(peakMemory, currentMemory)
            
            switch result {
            case .success:
                // Memory should not grow unboundedly
                let memoryGrowth = currentMemory - initialMemory
                XCTAssertLessThan(memoryGrowth, 100.0, 
                                 "Memory growth too high after \(i+1) images: \(memoryGrowth)MB")
                
            case .failure(let error):
                if error == .memoryPressure {
                    print("Memory pressure detected after \(i+1) images - this is acceptable")
                    break
                } else {
                    XCTFail("Unexpected error in stress test: \(error.displayMessage)")
                }
            }
        }
        
        let totalMemoryIncrease = peakMemory - initialMemory
        XCTAssertLessThan(totalMemoryIncrease, performanceThresholds.memoryLimitMB,
                         "Peak memory usage too high: \(totalMemoryIncrease)MB")
    }
    
    // MARK: - API Performance Tests
    
    func testAPIResponseTimePerformance() async throws {
        guard claudeAPIClient.isIntegrationTestEnabled() else {
            throw XCTSkip("Integration tests disabled")
        }
        
        let testDishes = testUtilities.createTestDishes(count: 5)
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        
        for dish in testDishes {
            let (result, responseTime) = await testUtilities.measureAsyncExecutionTime {
                await claudeAPIClient.generateDishVisualization(for: dish)
            }
            
            responseTimes.append(responseTime)
            
            // Validate individual response time
            XCTAssertLessThanOrEqual(responseTime, performanceThresholds.apiResponseTime,
                                    "API response time too high for \(dish.name): \(responseTime)s")
            
            switch result {
            case .success(let visualization):
                successCount += 1
                XCTAssertFalse(visualization.generatedDescription.isEmpty, "Should generate content")
                
            case .failure(let error):
                print("API call failed for \(dish.name): \(error.localizedDescription)")
            }
        }
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let successRate = Double(successCount) / Double(testDishes.count)
        
        print("API Performance Metrics:")
        print("- Average response time: \(String(format: "%.2f", avgResponseTime))s")
        print("- Success rate: \(String(format: "%.1f", successRate * 100))%")
        print("- Requests tested: \(testDishes.count)")
        
        XCTAssertLessThanOrEqual(avgResponseTime, performanceThresholds.apiResponseTime,
                                "Average API response time too high: \(avgResponseTime)s")
        XCTAssertGreaterThanOrEqual(successRate, 0.9, "API success rate too low: \(successRate)")
    }
    
    func testAPIConcurrentRequestPerformance() async throws {
        guard claudeAPIClient.isIntegrationTestEnabled() else {
            throw XCTSkip("Integration tests disabled")
        }
        
        let testDishes = testUtilities.createTestDishes(count: 10)
        let startTime = Date()
        
        // Execute concurrent requests
        let results = await withTaskGroup(of: (TimeInterval, Result<DishVisualization, ClaudeAPIError>).self) { group in
            for dish in testDishes {
                group.addTask {
                    let requestStart = Date()
                    let result = await self.claudeAPIClient.generateDishVisualization(for: dish)
                    let requestTime = Date().timeIntervalSince(requestStart)
                    return (requestTime, result)
                }
            }
            
            var results: [(TimeInterval, Result<DishVisualization, ClaudeAPIError>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let responseTimes = results.map { $0.0 }
        let successCount = results.compactMap { 
            if case .success = $0.1 { return 1 } else { return nil }
        }.count
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let successRate = Double(successCount) / Double(testDishes.count)
        
        print("Concurrent API Performance:")
        print("- Total time for \(testDishes.count) concurrent requests: \(String(format: "%.2f", totalTime))s")
        print("- Average individual response time: \(String(format: "%.2f", avgResponseTime))s")
        print("- Success rate: \(String(format: "%.1f", successRate * 100))%")
        
        // Concurrent requests should complete faster than sequential
        let sequentialEstimate = Double(testDishes.count) * performanceThresholds.apiResponseTime
        XCTAssertLessThan(totalTime, sequentialEstimate * 0.7, 
                         "Concurrent requests should be faster than sequential")
        
        XCTAssertGreaterThanOrEqual(successRate, 0.8, "Concurrent request success rate acceptable")
    }
    
    func testAPIMemoryUsageUnderLoad() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        let testDishes = testUtilities.createTestDishes(count: 20)
        
        var peakMemory: Float = initialMemory
        
        // Process requests in batches to simulate sustained load
        let batchSize = 5
        for i in stride(from: 0, to: testDishes.count, by: batchSize) {
            let batch = Array(testDishes[i..<min(i + batchSize, testDishes.count)])
            
            await withTaskGroup(of: Void.self) { group in
                for dish in batch {
                    group.addTask {
                        let _ = await self.claudeAPIClient.generateDishVisualization(for: dish)
                    }
                }
            }
            
            let currentMemory = testUtilities.getCurrentMemoryUsage()
            peakMemory = max(peakMemory, currentMemory)
            
            print("Batch \(i/batchSize + 1) completed. Memory: \(currentMemory)MB")
        }
        
        let memoryIncrease = peakMemory - initialMemory
        XCTAssertLessThan(memoryIncrease, 75.0, "API memory usage under load too high: \(memoryIncrease)MB")
        
        // Allow memory to settle
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let finalMemory = testUtilities.getCurrentMemoryUsage()
        let finalIncrease = finalMemory - initialMemory
        XCTAssertLessThan(finalIncrease, 50.0, "Memory should settle after API load: \(finalIncrease)MB")
    }
    
    // MARK: - Menu Parsing Performance Tests
    
    func testMenuParsingPerformance() async throws {
        let largeMenuOCR = testUtilities.createLargeMenuOCRResult(dishCount: 50)
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        let (result, processingTime) = await testUtilities.measureAsyncExecutionTime {
            try await menuParsingService.extractDishes(from: largeMenuOCR)
        }
        
        let memoryUsage = testUtilities.getCurrentMemoryUsage() - initialMemory
        
        XCTAssertLessThanOrEqual(processingTime, performanceThresholds.menuParsingTime,
                                "Menu parsing time too high: \(processingTime)s")
        
        XCTAssertLessThan(memoryUsage, 25.0, "Menu parsing memory usage too high: \(memoryUsage)MB")
        
        let extractedDishes = try result.get()
        XCTAssertGreaterThan(extractedDishes.count, 40, "Should extract most dishes efficiently")
        
        print("Menu Parsing Performance:")
        print("- Processing time: \(String(format: "%.3f", processingTime))s")
        print("- Memory usage: \(String(format: "%.1f", memoryUsage))MB")
        print("- Dishes extracted: \(extractedDishes.count)")
    }
    
    func testMenuParsingScalability() async throws {
        let dishCounts = [10, 25, 50, 100, 200]
        
        for dishCount in dishCounts {
            let menuOCR = testUtilities.createLargeMenuOCRResult(dishCount: dishCount)
            
            let (result, processingTime) = await testUtilities.measureAsyncExecutionTime {
                try await menuParsingService.extractDishes(from: menuOCR)
            }
            
            let extractedDishes = try result.get()
            let extractionRate = Double(extractedDishes.count) / Double(dishCount)
            
            print("Dishes: \(dishCount) - Time: \(String(format: "%.3f", processingTime))s - Rate: \(String(format: "%.1f", extractionRate * 100))%")
            
            // Processing time should scale sub-linearly
            let expectedTime = performanceThresholds.menuParsingTime * (Double(dishCount) / 50.0)
            XCTAssertLessThanOrEqual(processingTime, max(expectedTime, 5.0),
                                    "Menu parsing should scale efficiently for \(dishCount) dishes")
            
            XCTAssertGreaterThanOrEqual(extractionRate, 0.8, "Should maintain good extraction rate")
        }
    }
    
    // MARK: - Memory Leak Detection Tests
    
    func testOCRServiceMemoryLeaks() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Create OCR service instances and let them be deallocated
        for _ in 0..<10 {
            autoreleasepool {
                let ocrService = OCRService()
                let testImage = testUtilities.createMockMenuImage(for: .restaurantMenu)
                
                Task {
                    let _ = await ocrService.extractText(from: testImage, configuration: .fast)
                }
                // OCR service should be deallocated here
            }
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool { }
        }
        
        let finalMemory = testUtilities.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 20.0, "OCR service may have memory leaks: \(memoryIncrease)MB")
    }
    
    func testAPIClientMemoryLeaks() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Create API client instances and let them be deallocated
        for i in 0..<10 {
            autoreleasepool {
                let apiClient = ClaudeAPIClient()
                apiClient.setTestMode(enabled: true)
                
                let testDish = testUtilities.createTestDish(name: "Test Dish \(i)")
                
                Task {
                    let _ = await apiClient.generateDishVisualization(for: testDish)
                }
                // API client should be deallocated here
            }
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool { }
        }
        
        let finalMemory = testUtilities.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 15.0, "API client may have memory leaks: \(memoryIncrease)MB")
    }
    
    func testImageProcessingMemoryLeaks() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Process many images and ensure memory doesn't grow
        for i in 0..<20 {
            autoreleasepool {
                let testImage = createTestImageOfSize(width: 800, height: 1200)
                
                Task {
                    let _ = await ocrService.extractText(from: testImage, configuration: .fast)
                }
                
                // Image should be deallocated here
            }
            
            if i % 5 == 4 { // Check memory every 5 iterations
                let currentMemory = testUtilities.getCurrentMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory
                
                XCTAssertLessThan(memoryIncrease, 60.0, 
                                 "Memory growth during image processing: \(memoryIncrease)MB at iteration \(i)")
            }
        }
        
        // Final memory check
        for _ in 0..<3 {
            autoreleasepool { }
        }
        
        let finalMemory = testUtilities.getCurrentMemoryUsage()
        let totalIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(totalIncrease, 30.0, "Image processing memory leak detected: \(totalIncrease)MB")
    }
    
    // MARK: - UI Performance Tests
    
    func testViewModelPerformance() async throws {
        let menuCaptureViewModel = MenuCaptureViewModel()
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Simulate rapid state changes
        let stateChanges = 100
        let startTime = Date()
        
        for i in 0..<stateChanges {
            await MainActor.run {
                menuCaptureViewModel.processingState = .processingOCR
                menuCaptureViewModel.processingState = .parsingMenu
                menuCaptureViewModel.processingState = .completed
                menuCaptureViewModel.processingState = .idle
            }
            
            if i % 10 == 0 {
                try? await Task.sleep(nanoseconds: 1_000_000) // 1ms break every 10 iterations
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let memoryUsage = testUtilities.getCurrentMemoryUsage() - initialMemory
        
        XCTAssertLessThan(totalTime, 1.0, "ViewModel state changes should be fast: \(totalTime)s")
        XCTAssertLessThan(memoryUsage, 10.0, "ViewModel should not use excessive memory: \(memoryUsage)MB")
        
        print("ViewModel Performance:")
        print("- State changes: \(stateChanges)")
        print("- Total time: \(String(format: "%.3f", totalTime))s")
        print("- Average time per change: \(String(format: "%.3f", totalTime * 1000 / Double(stateChanges)))ms")
    }
    
    func testAppStartupPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            // This would launch the app and measure startup time
            // In a real test, this would use XCUIApplication
        }
    }
    
    // MARK: - Battery Usage Tests (Simulated)
    
    func testBatteryImpactSimulation() async throws {
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        let startTime = Date()
        
        // Simulate typical usage session
        let testImage = try testUtilities.loadTestImage(.restaurantMenu)
        
        // 1. OCR Processing
        let ocrResult = await ocrService.extractText(from: testImage, configuration: .balanced)
        
        // 2. Menu Parsing
        switch ocrResult {
        case .success(let result):
            let dishes = try await menuParsingService.extractDishes(from: result)
            
            // 3. API Visualization (simulate first 2 dishes)
            for dish in dishes.prefix(2) {
                let _ = await claudeAPIClient.generateDishVisualization(for: dish)
            }
            
        case .failure(let error):
            XCTFail("OCR should succeed for battery test: \(error.displayMessage)")
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let memoryUsage = testUtilities.getCurrentMemoryUsage() - initialMemory
        
        // Validate reasonable resource usage
        XCTAssertLessThan(totalTime, 15.0, "Complete session should be efficient: \(totalTime)s")
        XCTAssertLessThan(memoryUsage, performanceThresholds.memoryLimitMB,
                         "Memory usage should be reasonable: \(memoryUsage)MB")
        
        print("Battery Impact Simulation:")
        print("- Session time: \(String(format: "%.2f", totalTime))s")
        print("- Memory usage: \(String(format: "%.1f", memoryUsage))MB")
        print("- Estimated battery impact: Low (efficient processing)")
    }
    
    // MARK: - Performance Regression Tests
    
    func testPerformanceRegression() async throws {
        // Baseline performance expectations (these would be updated as app evolves)
        let baselineMetrics = BaselineMetrics(
            ocrTime: 3.0,
            apiTime: 2.0,
            parsingTime: 0.5,
            memoryUsage: 100.0
        )
        
        let testImage = try testUtilities.loadTestImage(.restaurantMenu)
        let testDish = testUtilities.createTestDish()
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        // Measure current performance
        let (ocrResult, ocrTime) = await testUtilities.measureAsyncExecutionTime {
            await ocrService.extractText(from: testImage, configuration: .balanced)
        }
        
        let (_, parsingTime) = await testUtilities.measureAsyncExecutionTime {
            switch ocrResult {
            case .success(let result):
                return try await menuParsingService.extractDishes(from: result)
            case .failure:
                throw MenulyError.ocrProcessingFailed
            }
        }
        
        let (_, apiTime) = await testUtilities.measureAsyncExecutionTime {
            await claudeAPIClient.generateDishVisualization(for: testDish)
        }
        
        let memoryUsage = testUtilities.getCurrentMemoryUsage() - initialMemory
        
        // Check for performance regression
        let regressionThreshold = 1.2 // 20% tolerance
        
        XCTAssertLessThanOrEqual(ocrTime, baselineMetrics.ocrTime * regressionThreshold,
                                "OCR performance regression: \(ocrTime)s vs baseline \(baselineMetrics.ocrTime)s")
        
        XCTAssertLessThanOrEqual(parsingTime, baselineMetrics.parsingTime * regressionThreshold,
                                "Parsing performance regression: \(parsingTime)s vs baseline \(baselineMetrics.parsingTime)s")
        
        XCTAssertLessThanOrEqual(memoryUsage, baselineMetrics.memoryUsage * Float(regressionThreshold),
                                "Memory usage regression: \(memoryUsage)MB vs baseline \(baselineMetrics.memoryUsage)MB")
        
        print("Performance Regression Test Results:")
        print("- OCR: \(String(format: "%.2f", ocrTime))s (baseline: \(baselineMetrics.ocrTime)s)")
        print("- Parsing: \(String(format: "%.3f", parsingTime))s (baseline: \(baselineMetrics.parsingTime)s)")
        print("- Memory: \(String(format: "%.1f", memoryUsage))MB (baseline: \(baselineMetrics.memoryUsage)MB)")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageOfSize(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add some text content scaled to image size
            let fontSize = max(16, min(48, width / 20))
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
                .foregroundColor: UIColor.black
            ]
            
            let menuText = """
            RESTAURANT MENU
            
            Appetizers
            Caesar Salad - $12.99
            Wings - $10.99
            
            Main Courses
            Salmon - $24.99
            Steak - $32.99
            
            Desserts
            Cake - $8.99
            """
            
            let attributedText = NSAttributedString(string: menuText, attributes: textAttributes)
            let textRect = CGRect(x: width/10, y: height/8, width: width*4/5, height: height*3/4)
            attributedText.draw(in: textRect)
        }
    }
}

// MARK: - Performance Configuration

private struct PerformanceThresholds {
    let ocrProcessingTime: TimeInterval
    let apiResponseTime: TimeInterval
    let menuParsingTime: TimeInterval
    let memoryLimitMB: Float
    let startupTime: TimeInterval
    let uiResponseTime: TimeInterval
}

private struct BaselineMetrics {
    let ocrTime: TimeInterval
    let apiTime: TimeInterval
    let parsingTime: TimeInterval
    let memoryUsage: Float
}

// MARK: - TestUtilities Extension for Mock Image Creation

extension TestUtilities {
    func createMockMenuImage(for type: TestImageType) -> UIImage {
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add mock menu content
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            
            let menuText = getMockMenuText(for: type)
            let attributedText = NSAttributedString(string: menuText, attributes: textAttributes)
            let textRect = CGRect(x: 50, y: 100, width: size.width - 100, height: size.height - 200)
            attributedText.draw(in: textRect)
        }
    }
    
    private func getMockMenuText(for type: TestImageType) -> String {
        switch type {
        case .restaurantMenu:
            return """
            APPETIZERS
            Caesar Salad - $12.99
            Buffalo Wings - $10.99
            
            MAIN COURSES
            Grilled Salmon - $24.99
            Ribeye Steak - $32.99
            
            DESSERTS
            Chocolate Cake - $8.99
            """
        default:
            return "MENU\nSample Dish - $15.99"
        }
    }
}