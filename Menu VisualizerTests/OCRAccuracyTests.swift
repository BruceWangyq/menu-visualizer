//
//  OCRAccuracyTests.swift
//  Menu VisualizerTests
//
//  Comprehensive OCR accuracy testing suite for Apple Vision framework
//  Tests various menu types, image conditions, and text recognition scenarios
//

import XCTest
import Vision
import UIKit
@testable import Menu_Visualizer

final class OCRAccuracyTests: XCTestCase {
    
    var ocrService: OCRService!
    var testUtilities: TestUtilities!
    
    // Performance benchmarks
    private let accuracyThresholds = AccuracyThresholds(
        cleanImages: 0.95,      // 95% accuracy on clean menu images
        challengingImages: 0.85, // 85% accuracy on challenging images
        minimumConfidence: 0.7,  // Minimum confidence threshold
        processingTimeLimit: 10.0 // Maximum processing time in seconds
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        ocrService = OCRService()
        testUtilities = TestUtilities()
        
        // Ensure we have test images available
        try testUtilities.validateTestAssets()
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        testUtilities = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Menu Type Testing
    
    func testRestaurantMenuRecognition() async throws {
        let testImage = try testUtilities.loadTestImage(.restaurantMenu)
        let expectedDishes = testUtilities.getExpectedDishes(for: .restaurantMenu)
        
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            // Validate overall confidence
            XCTAssertGreaterThanOrEqual(ocrResult.overallConfidence, accuracyThresholds.cleanImages,
                                       "OCR confidence below threshold for restaurant menu")
            
            // Test dish extraction accuracy
            let extractedDishes = try await extractDishesFromOCR(ocrResult)
            let accuracy = calculateDishAccuracy(expected: expectedDishes, extracted: extractedDishes)
            
            XCTAssertGreaterThanOrEqual(accuracy, accuracyThresholds.cleanImages,
                                       "Dish extraction accuracy below threshold: \(accuracy)")
            
            // Validate processing time
            XCTAssertLessThanOrEqual(ocrResult.processingTime, accuracyThresholds.processingTimeLimit,
                                    "Processing time exceeded limit: \(ocrResult.processingTime)s")
            
        case .failure(let error):
            XCTFail("OCR processing failed for restaurant menu: \(error.displayMessage)")
        }
    }
    
    func testCafeMenuRecognition() async throws {
        let testImage = try testUtilities.loadTestImage(.cafeMenu)
        let expectedDishes = testUtilities.getExpectedDishes(for: .cafeMenu)
        
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            let extractedDishes = try await extractDishesFromOCR(ocrResult)
            let accuracy = calculateDishAccuracy(expected: expectedDishes, extracted: extractedDishes)
            
            XCTAssertGreaterThanOrEqual(accuracy, accuracyThresholds.cleanImages,
                                       "Cafe menu accuracy below threshold: \(accuracy)")
            
        case .failure(let error):
            XCTFail("OCR processing failed for cafe menu: \(error.displayMessage)")
        }
    }
    
    func testFineDiningMenuRecognition() async throws {
        let testImage = try testUtilities.loadTestImage(.fineDiningMenu)
        let expectedDishes = testUtilities.getExpectedDishes(for: .fineDiningMenu)
        
        // Fine dining menus often have complex formatting
        let configuration = OCRService.OCRConfiguration(
            quality: .maximum,
            languages: ["en-US", "fr-FR"], // Often include French terms
            enableLayoutAnalysis: true,
            enableRegionDetection: true,
            minimumConfidence: 0.1,
            maxProcessingTime: 45.0
        )
        
        let result = await ocrService.extractText(from: testImage, configuration: configuration)
        
        switch result {
        case .success(let ocrResult):
            let extractedDishes = try await extractDishesFromOCR(ocrResult)
            let accuracy = calculateDishAccuracy(expected: expectedDishes, extracted: extractedDishes)
            
            // Fine dining menus may have lower accuracy due to fancy fonts
            XCTAssertGreaterThanOrEqual(accuracy, accuracyThresholds.challengingImages,
                                       "Fine dining menu accuracy below threshold: \(accuracy)")
            
        case .failure(let error):
            XCTFail("OCR processing failed for fine dining menu: \(error.displayMessage)")
        }
    }
    
    func testFoodTruckMenuRecognition() async throws {
        let testImage = try testUtilities.loadTestImage(.foodTruckMenu)
        let expectedDishes = testUtilities.getExpectedDishes(for: .foodTruckMenu)
        
        // Food truck menus often have handwritten elements and simple formatting
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            let extractedDishes = try await extractDishesFromOCR(ocrResult)
            let accuracy = calculateDishAccuracy(expected: expectedDishes, extracted: extractedDishes)
            
            XCTAssertGreaterThanOrEqual(accuracy, accuracyThresholds.challengingImages,
                                       "Food truck menu accuracy below threshold: \(accuracy)")
            
        case .failure(let error):
            XCTFail("OCR processing failed for food truck menu: \(error.displayMessage)")
        }
    }
    
    // MARK: - Image Condition Testing
    
    func testLowLightConditions() async throws {
        let testImage = try testUtilities.loadTestImage(.lowLightMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .maximum)
        
        switch result {
        case .success(let ocrResult):
            // Lower expectations for low light conditions
            XCTAssertGreaterThanOrEqual(ocrResult.overallConfidence, 0.6,
                                       "Low light OCR confidence too low: \(ocrResult.overallConfidence)")
            
        case .failure(let error):
            // Some failure is acceptable in very low light
            if case .lowConfidenceOCR(let confidence) = error {
                XCTAssertGreaterThanOrEqual(confidence, 0.3,
                                           "Even low light should produce some results")
            } else {
                XCTFail("Unexpected error in low light: \(error.displayMessage)")
            }
        }
    }
    
    func testAngledImageRecognition() async throws {
        let testImage = try testUtilities.loadTestImage(.angledMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            XCTAssertGreaterThanOrEqual(ocrResult.overallConfidence, accuracyThresholds.challengingImages,
                                       "Angled image OCR confidence below threshold")
            
        case .failure(let error):
            XCTFail("OCR should handle moderately angled images: \(error.displayMessage)")
        }
    }
    
    func testBlurryImageHandling() async throws {
        let testImage = try testUtilities.loadTestImage(.blurryMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .maximum)
        
        switch result {
        case .success(let ocrResult):
            // Blurry images should still produce some results
            XCTAssertGreaterThan(ocrResult.recognizedText.count, 0,
                                "Blurry image should still recognize some text")
            
        case .failure(let error):
            // Failure is acceptable for very blurry images
            print("Blurry image failed as expected: \(error.displayMessage)")
        }
    }
    
    func testHighResolutionImages() async throws {
        let testImage = try testUtilities.loadTestImage(.highResolutionMenu)
        let expectedDishes = testUtilities.getExpectedDishes(for: .highResolutionMenu)
        
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            // High resolution images should achieve excellent accuracy
            XCTAssertGreaterThanOrEqual(ocrResult.overallConfidence, 0.95,
                                       "High resolution image should have excellent OCR confidence")
            
            let extractedDishes = try await extractDishesFromOCR(ocrResult)
            let accuracy = calculateDishAccuracy(expected: expectedDishes, extracted: extractedDishes)
            
            XCTAssertGreaterThanOrEqual(accuracy, 0.95,
                                       "High resolution should achieve >95% accuracy: \(accuracy)")
            
        case .failure(let error):
            XCTFail("High resolution image processing failed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Text Challenge Testing
    
    func testMultilingualMenus() async throws {
        let testImage = try testUtilities.loadTestImage(.multilingualMenu)
        
        let multilingualConfig = OCRService.OCRConfiguration(
            quality: .accurate,
            languages: ["en-US", "es-ES", "fr-FR", "it-IT", "de-DE"],
            enableLayoutAnalysis: true,
            enableRegionDetection: true,
            minimumConfidence: 0.2,
            maxProcessingTime: 60.0
        )
        
        let result = await ocrService.extractText(from: testImage, configuration: multilingualConfig)
        
        switch result {
        case .success(let ocrResult):
            // Should detect text in multiple languages
            XCTAssertGreaterThan(ocrResult.detectedLanguages.count, 1,
                                "Should detect multiple languages")
            
            XCTAssertGreaterThanOrEqual(ocrResult.overallConfidence, accuracyThresholds.challengingImages,
                                       "Multilingual menu accuracy below threshold")
            
        case .failure(let error):
            XCTFail("Multilingual menu processing failed: \(error.displayMessage)")
        }
    }
    
    func testSpecialCharactersAndSymbols() async throws {
        let testImage = try testUtilities.loadTestImage(.specialCharactersMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .accurate)
        
        switch result {
        case .success(let ocrResult):
            let fullText = ocrResult.fullText
            
            // Check for common menu symbols
            XCTAssertTrue(fullText.contains("$") || fullText.contains("€") || fullText.contains("£"),
                         "Should recognize currency symbols")
            
            // Check for common punctuation
            XCTAssertTrue(fullText.contains(",") || fullText.contains("."),
                         "Should recognize common punctuation")
            
        case .failure(let error):
            XCTFail("Special characters menu processing failed: \(error.displayMessage)")
        }
    }
    
    func testHandwrittenElements() async throws {
        let testImage = try testUtilities.loadTestImage(.handwrittenSpecials)
        
        // Handwritten text requires maximum quality settings
        let handwritingConfig = OCRService.OCRConfiguration(
            quality: .maximum,
            languages: ["en-US"],
            enableLayoutAnalysis: true,
            enableRegionDetection: true,
            minimumConfidence: 0.1, // Lower confidence for handwriting
            maxProcessingTime: 60.0
        )
        
        let result = await ocrService.extractText(from: testImage, configuration: handwritingConfig)
        
        switch result {
        case .success(let ocrResult):
            // Lower expectations for handwritten text
            XCTAssertGreaterThan(ocrResult.recognizedText.count, 0,
                                "Should recognize some handwritten text")
            
        case .failure(let error):
            // Partial failure acceptable for handwritten text
            print("Handwritten text recognition failed as expected: \(error.displayMessage)")
        }
    }
    
    // MARK: - Layout Variation Testing
    
    func testSingleColumnLayout() async throws {
        let testImage = try testUtilities.loadTestImage(.singleColumnMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            if let layoutAnalysis = ocrResult.layoutAnalysis {
                XCTAssertEqual(layoutAnalysis.detectedColumns, 1,
                              "Should detect single column layout")
                XCTAssertEqual(layoutAnalysis.textAlignment, .left,
                              "Single column menus typically left-aligned")
            }
            
        case .failure(let error):
            XCTFail("Single column menu processing failed: \(error.displayMessage)")
        }
    }
    
    func testMultiColumnLayout() async throws {
        let testImage = try testUtilities.loadTestImage(.multiColumnMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            if let layoutAnalysis = ocrResult.layoutAnalysis {
                XCTAssertGreaterThan(layoutAnalysis.detectedColumns, 1,
                                    "Should detect multi-column layout")
                XCTAssertGreaterThan(layoutAnalysis.menuSections.count, 0,
                                    "Should identify menu sections")
            }
            
        case .failure(let error):
            XCTFail("Multi-column menu processing failed: \(error.displayMessage)")
        }
    }
    
    func testSectionedMenuLayout() async throws {
        let testImage = try testUtilities.loadTestImage(.sectionedMenu)
        let expectedSections = testUtilities.getExpectedSections(for: .sectionedMenu)
        
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            if let layoutAnalysis = ocrResult.layoutAnalysis {
                let detectedSectionCount = layoutAnalysis.menuSections.count
                let expectedSectionCount = expectedSections.count
                
                // Allow some variation in section detection
                let sectionAccuracy = Double(detectedSectionCount) / Double(expectedSectionCount)
                XCTAssertGreaterThanOrEqual(sectionAccuracy, 0.8,
                                           "Section detection accuracy too low: \(sectionAccuracy)")
            }
            
        case .failure(let error):
            XCTFail("Sectioned menu processing failed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Price Format Testing
    
    func testDollarPriceFormats() async throws {
        let testImage = try testUtilities.loadTestImage(.dollarPricesMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            let priceBlocks = ocrResult.recognizedText.filter { $0.textType == .price }
            XCTAssertGreaterThan(priceBlocks.count, 0, "Should detect price information")
            
            // Validate price format recognition
            let fullText = ocrResult.fullText
            XCTAssertTrue(fullText.contains("$"), "Should recognize dollar signs")
            
        case .failure(let error):
            XCTFail("Dollar prices menu processing failed: \(error.displayMessage)")
        }
    }
    
    func testEuroPriceFormats() async throws {
        let testImage = try testUtilities.loadTestImage(.euroPricesMenu)
        let result = await ocrService.extractText(from: testImage, configuration: .menuOptimized)
        
        switch result {
        case .success(let ocrResult):
            let fullText = ocrResult.fullText
            XCTAssertTrue(fullText.contains("€"), "Should recognize Euro symbols")
            
        case .failure(let error):
            XCTFail("Euro prices menu processing failed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Performance Benchmarking
    
    func testOCRPerformanceBenchmarks() async throws {
        let testImages = try testUtilities.loadAllBenchmarkImages()
        var processingTimes: [TimeInterval] = []
        var accuracyScores: [Float] = []
        
        for (imageType, testImage) in testImages {
            let startTime = Date()
            let result = await ocrService.extractText(from: testImage, configuration: .balanced)
            let processingTime = Date().timeIntervalSince(startTime)
            
            processingTimes.append(processingTime)
            
            switch result {
            case .success(let ocrResult):
                accuracyScores.append(ocrResult.overallConfidence)
                
                // Individual image performance validation
                XCTAssertLessThanOrEqual(processingTime, accuracyThresholds.processingTimeLimit,
                                        "Processing time exceeded for \(imageType): \(processingTime)s")
                
            case .failure(let error):
                print("Benchmark failed for \(imageType): \(error.displayMessage)")
                accuracyScores.append(0.0) // Failed recognition
            }
        }
        
        // Overall performance metrics
        let averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let averageAccuracy = accuracyScores.reduce(0, +) / Float(accuracyScores.count)
        
        XCTAssertLessThanOrEqual(averageProcessingTime, accuracyThresholds.processingTimeLimit,
                                "Average processing time too high: \(averageProcessingTime)s")
        XCTAssertGreaterThanOrEqual(averageAccuracy, accuracyThresholds.challengingImages,
                                   "Average accuracy too low: \(averageAccuracy)")
        
        // Log performance metrics for monitoring
        print("OCR Performance Metrics:")
        print("- Average processing time: \(String(format: "%.2f", averageProcessingTime))s")
        print("- Average accuracy: \(String(format: "%.1f", averageAccuracy * 100))%")
        print("- Test images processed: \(testImages.count)")
    }
    
    func testMemoryUsageDuringOCR() async throws {
        let testImage = try testUtilities.loadTestImage(.highResolutionMenu)
        let initialMemory = testUtilities.getCurrentMemoryUsage()
        
        let result = await ocrService.extractText(from: testImage, configuration: .maximum)
        
        let peakMemory = testUtilities.getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Memory usage should be reasonable
        let memoryLimitMB: Float = 100 // 100MB limit for OCR processing
        XCTAssertLessThan(memoryIncrease, memoryLimitMB,
                         "Memory usage too high: \(memoryIncrease)MB")
        
        switch result {
        case .success(let ocrResult):
            XCTAssertGreaterThan(ocrResult.recognizedText.count, 0, "OCR should succeed")
            
        case .failure(let error):
            XCTFail("High resolution OCR failed: \(error.displayMessage)")
        }
    }
    
    // MARK: - Error Handling Testing
    
    func testEmptyImageHandling() async throws {
        let emptyImage = testUtilities.createEmptyImage()
        let result = await ocrService.extractText(from: emptyImage, configuration: .default)
        
        switch result {
        case .success:
            XCTFail("Empty image should not produce successful OCR result")
            
        case .failure(let error):
            XCTAssertEqual(error, .noTextRecognized, "Should return no text recognized error")
        }
    }
    
    func testCorruptedImageHandling() async throws {
        let corruptedImage = testUtilities.createCorruptedImage()
        let result = await ocrService.extractText(from: corruptedImage, configuration: .default)
        
        switch result {
        case .success:
            XCTFail("Corrupted image should not produce successful OCR result")
            
        case .failure(let error):
            XCTAssertEqual(error, .ocrProcessingFailed, "Should return processing failed error")
        }
    }
    
    func testVeryLargeImageHandling() async throws {
        let largeImage = testUtilities.createVeryLargeTestImage()
        let result = await ocrService.extractText(from: largeImage, configuration: .fast)
        
        // Should either succeed with reasonable processing time or fail gracefully
        switch result {
        case .success(let ocrResult):
            XCTAssertLessThanOrEqual(ocrResult.processingTime, 30.0,
                                    "Very large image processing should have timeout")
            
        case .failure(let error):
            // Memory pressure or timeout is acceptable for very large images
            XCTAssertTrue(error == .memoryPressure || error == .ocrProcessingFailed,
                         "Should fail gracefully: \(error.displayMessage)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractDishesFromOCR(_ ocrResult: OCRResult) async throws -> [String] {
        // This would integrate with MenuParsingService
        let menuParser = MenuParsingService()
        let dishes = try await menuParser.extractDishes(from: ocrResult)
        return dishes.map { $0.name }
    }
    
    private func calculateDishAccuracy(expected: [String], extracted: [String]) -> Double {
        guard !expected.isEmpty else { return 0.0 }
        
        let expectedSet = Set(expected.map { $0.lowercased() })
        let extractedSet = Set(extracted.map { $0.lowercased() })
        
        let correctMatches = expectedSet.intersection(extractedSet).count
        return Double(correctMatches) / Double(expected.count)
    }
}

// MARK: - Test Configuration

private struct AccuracyThresholds {
    let cleanImages: Float
    let challengingImages: Float
    let minimumConfidence: Float
    let processingTimeLimit: TimeInterval
}