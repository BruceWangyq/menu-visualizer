//
//  TestUtilities.swift
//  Menu VisualizerTests
//
//  Comprehensive test utilities, data generators, and helper functions
//  for the Menuly iOS app testing suite
//

import XCTest
import UIKit
import Vision
@testable import Menu_Visualizer

/// Comprehensive test utilities for Menuly testing suite
final class TestUtilities {
    
    // MARK: - Test Configuration
    
    enum TestImageType: String, CaseIterable {
        case restaurantMenu = "restaurant_menu"
        case cafeMenu = "cafe_menu"
        case fineDiningMenu = "fine_dining_menu"
        case foodTruckMenu = "food_truck_menu"
        case lowLightMenu = "low_light_menu"
        case angledMenu = "angled_menu"
        case blurryMenu = "blurry_menu"
        case highResolutionMenu = "high_resolution_menu"
        case multilingualMenu = "multilingual_menu"
        case specialCharactersMenu = "special_characters_menu"
        case handwrittenSpecials = "handwritten_specials"
        case singleColumnMenu = "single_column_menu"
        case multiColumnMenu = "multi_column_menu"
        case sectionedMenu = "sectioned_menu"
        case dollarPricesMenu = "dollar_prices_menu"
        case euroPricesMenu = "euro_prices_menu"
        
        var expectedAccuracy: Float {
            switch self {
            case .restaurantMenu, .cafeMenu, .highResolutionMenu, .dollarPricesMenu:
                return 0.95
            case .fineDiningMenu, .multilingualMenu, .sectionedMenu:
                return 0.90
            case .foodTruckMenu, .angledMenu, .specialCharactersMenu:
                return 0.85
            case .lowLightMenu, .blurryMenu:
                return 0.70
            case .handwrittenSpecials:
                return 0.60
            default:
                return 0.80
            }
        }
    }
    
    // MARK: - Image Generation and Loading
    
    /// Load test image for specified type
    func loadTestImage(_ type: TestImageType) throws -> UIImage {
        // In a real implementation, this would load from test bundle
        // For now, we'll create mock images
        return createMockMenuImage(for: type)
    }
    
    /// Load all benchmark images for performance testing
    func loadAllBenchmarkImages() throws -> [(TestImageType, UIImage)] {
        return TestImageType.allCases.map { type in
            (type, createMockMenuImage(for: type))
        }
    }
    
    /// Create mock menu image for testing
    private func createMockMenuImage(for type: TestImageType) -> UIImage {
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add mock menu content based on type
            addMockMenuContent(to: cgContext, size: size, type: type)
        }
    }
    
    private func addMockMenuContent(to context: CGContext, size: CGSize, type: TestImageType) {
        // This would contain image-specific mock content
        // For brevity, adding basic content
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let sampleText = getMockMenuText(for: type)
        let attributedText = NSAttributedString(string: sampleText, attributes: textAttributes)
        
        let textRect = CGRect(x: 50, y: 100, width: size.width - 100, height: size.height - 200)
        attributedText.draw(in: textRect)
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
            Tiramisu - $9.99
            """
            
        case .cafeMenu:
            return """
            COFFEE
            Espresso - $3.50
            Latte - $4.50
            Cappuccino - $4.25
            
            PASTRIES
            Croissant - $3.99
            Muffin - $2.99
            Scone - $3.50
            """
            
        case .multilingualMenu:
            return """
            ANTIPASTI
            Bruschetta - €8.50
            Prosciutto - €12.00
            
            PLATS PRINCIPAUX
            Coq au Vin - €18.50
            Bouillabaisse - €22.00
            
            HAUPTGERICHTE
            Schnitzel - €16.50
            Sauerbraten - €19.00
            """
            
        default:
            return """
            MENU
            Sample Dish 1 - $15.99
            Sample Dish 2 - $18.99
            Sample Dish 3 - $12.99
            """
        }
    }
    
    // MARK: - Test Data Generation
    
    /// Create a test dish with specified parameters
    func createTestDish(name: String = "Test Dish", 
                       description: String? = "A delicious test dish", 
                       price: String = "$15.99",
                       category: DishCategory = .mainCourse,
                       confidence: Float = 0.9) -> Dish {
        return Dish(name: name, description: description, price: price, 
                   category: category, confidence: confidence)
    }
    
    /// Create multiple test dishes for batch testing
    func createTestDishes(count: Int) -> [Dish] {
        return (0..<count).map { index in
            createTestDish(name: "Test Dish \(index)", 
                          price: "$\(10 + index).99",
                          confidence: Float.random(in: 0.7...0.95))
        }
    }
    
    /// Create mock OCR result with specified text blocks
    func createMockOCRResult(textBlocks: [OCRResult.TextBlock]) -> OCRResult {
        return OCRResult(
            recognizedText: textBlocks,
            processingTime: 2.5,
            overallConfidence: textBlocks.isEmpty ? 0.0 : textBlocks.reduce(0.0) { $0 + $1.confidence } / Float(textBlocks.count),
            imageSize: CGSize(width: 800, height: 1200),
            detectedLanguages: ["en-US"],
            layoutAnalysis: createMockLayoutAnalysis()
        )
    }
    
    /// Create empty OCR result for error testing
    func createEmptyOCRResult() -> OCRResult {
        return OCRResult(
            recognizedText: [],
            processingTime: 1.0,
            overallConfidence: 0.0,
            imageSize: CGSize(width: 800, height: 1200),
            detectedLanguages: [],
            layoutAnalysis: nil
        )
    }
    
    /// Create large menu OCR result for performance testing
    func createLargeMenuOCRResult(dishCount: Int) -> OCRResult {
        var textBlocks: [OCRResult.TextBlock] = []
        
        for i in 0..<dishCount {
            // Add dish name
            textBlocks.append(createTextBlock(text: "Test Dish \(i)", 
                                            type: .dishName, 
                                            confidence: Float.random(in: 0.7...0.95)))
            
            // Add price
            textBlocks.append(createTextBlock(text: "$\(10 + i).99", 
                                            type: .price, 
                                            confidence: Float.random(in: 0.8...0.98)))
            
            // Occasionally add description
            if i % 3 == 0 {
                textBlocks.append(createTextBlock(text: "Description for dish \(i)", 
                                                type: .description, 
                                                confidence: Float.random(in: 0.6...0.85)))
            }
        }
        
        return createMockOCRResult(textBlocks: textBlocks)
    }
    
    /// Create realistic restaurant menu OCR result
    func createRestaurantMenuOCRResult() -> OCRResult {
        let textBlocks = [
            // Appetizers section
            createTextBlock(text: "APPETIZERS", type: .sectionHeader, confidence: 0.95),
            createTextBlock(text: "Caesar Salad", type: .dishName, confidence: 0.92),
            createTextBlock(text: "Fresh romaine lettuce with parmesan and croutons", type: .description, confidence: 0.88),
            createTextBlock(text: "$12.99", type: .price, confidence: 0.94),
            createTextBlock(text: "Buffalo Wings", type: .dishName, confidence: 0.89),
            createTextBlock(text: "8 pieces with blue cheese", type: .description, confidence: 0.85),
            createTextBlock(text: "$10.99", type: .price, confidence: 0.93),
            
            // Main courses section
            createTextBlock(text: "MAIN COURSES", type: .sectionHeader, confidence: 0.96),
            createTextBlock(text: "Grilled Atlantic Salmon", type: .dishName, confidence: 0.91),
            createTextBlock(text: "Fresh salmon with seasonal vegetables", type: .description, confidence: 0.87),
            createTextBlock(text: "$24.99", type: .price, confidence: 0.95),
            createTextBlock(text: "Prime Ribeye Steak", type: .dishName, confidence: 0.93),
            createTextBlock(text: "12oz certified Angus beef", type: .description, confidence: 0.89),
            createTextBlock(text: "$32.99", type: .price, confidence: 0.97),
            
            // Desserts section
            createTextBlock(text: "DESSERTS", type: .sectionHeader, confidence: 0.94),
            createTextBlock(text: "Chocolate Cake", type: .dishName, confidence: 0.90),
            createTextBlock(text: "$8.99", type: .price, confidence: 0.92),
            createTextBlock(text: "Tiramisu", type: .dishName, confidence: 0.88),
            createTextBlock(text: "$9.99", type: .price, confidence: 0.91)
        ]
        
        return createMockOCRResult(textBlocks: textBlocks)
    }
    
    // MARK: - OCR Test Block Creation
    
    /// Create a test text block with specified parameters
    static func createTextBlock(text: String, 
                               type: TextType = .other, 
                               confidence: Float = 0.9,
                               boundingBox: CGRect? = nil) -> OCRResult.TextBlock {
        let box = boundingBox ?? CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05)
        
        return OCRResult.TextBlock(
            text: text,
            boundingBox: box,
            confidence: confidence,
            recognitionLevel: .accurate,
            alternatives: [],
            textType: type
        )
    }
    
    private func createMockLayoutAnalysis() -> LayoutAnalysisResult {
        return LayoutAnalysisResult(
            detectedColumns: 1,
            menuSections: [
                MenuSection(header: "Appetizers", boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.2), textBlocks: []),
                MenuSection(header: "Main Courses", boundingBox: CGRect(x: 0, y: 0.4, width: 1, height: 0.4), textBlocks: []),
                MenuSection(header: "Desserts", boundingBox: CGRect(x: 0, y: 0.1, width: 1, height: 0.3), textBlocks: [])
            ],
            averageLineSpacing: 0.03,
            textAlignment: .left
        )
    }
    
    // MARK: - Expected Test Data
    
    /// Get expected dishes for a menu type (ground truth for accuracy testing)
    func getExpectedDishes(for type: TestImageType) -> [String] {
        switch type {
        case .restaurantMenu:
            return ["Caesar Salad", "Buffalo Wings", "Grilled Salmon", "Ribeye Steak", "Chocolate Cake", "Tiramisu"]
        case .cafeMenu:
            return ["Espresso", "Latte", "Cappuccino", "Croissant", "Muffin", "Scone"]
        case .fineDiningMenu:
            return ["Foie Gras", "Lobster Bisque", "Duck Confit", "Beef Wellington", "Crème Brûlée"]
        case .foodTruckMenu:
            return ["Burger", "Tacos", "Hot Dog", "Fries", "Nachos"]
        default:
            return ["Sample Dish 1", "Sample Dish 2", "Sample Dish 3"]
        }
    }
    
    /// Get expected sections for a menu type
    func getExpectedSections(for type: TestImageType) -> [String] {
        switch type {
        case .restaurantMenu, .sectionedMenu:
            return ["APPETIZERS", "MAIN COURSES", "DESSERTS"]
        case .cafeMenu:
            return ["COFFEE", "PASTRIES"]
        case .fineDiningMenu:
            return ["AMUSE-BOUCHE", "ENTRÉES", "PLATS PRINCIPAUX", "DESSERTS"]
        default:
            return ["MENU"]
        }
    }
    
    // MARK: - Mock API Response Generation
    
    /// Create successful API response JSON
    func createSuccessResponse() -> String {
        return """
        {
            "success": true,
            "visualization": {
                "description": "A beautifully prepared dish with excellent presentation and flavor",
                "visualStyle": "elegant, restaurant-quality presentation",
                "ingredients": ["main ingredient", "herbs", "seasonal vegetables"],
                "preparationNotes": "Carefully prepared using traditional methods"
            }
        }
        """
    }
    
    /// Create error API response JSON
    func createErrorResponse(message: String = "Test error") -> String {
        return """
        {
            "success": false,
            "error": {
                "type": "test_error",
                "message": "\(message)"
            }
        }
        """
    }
    
    // MARK: - Image Quality Testing
    
    /// Create empty/transparent image for error testing
    func createEmptyImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// Create corrupted/invalid image for error testing
    func createCorruptedImage() -> UIImage {
        // Create a minimal valid image that might cause processing issues
        return UIImage(systemName: "questionmark") ?? createEmptyImage()
    }
    
    /// Create very large image for stress testing
    func createVeryLargeTestImage() -> UIImage {
        let size = CGSize(width: 4000, height: 6000) // 24MP image
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add some text content
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48),
                .foregroundColor: UIColor.black
            ]
            
            let text = NSAttributedString(string: "Large Test Menu\nWith Multiple Items", attributes: textAttributes)
            let textRect = CGRect(x: 200, y: 1000, width: size.width - 400, height: 200)
            text.draw(in: textRect)
        }
    }
    
    // MARK: - Memory and Performance Testing
    
    /// Get current memory usage in MB
    func getCurrentMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Float(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0.0
    }
    
    /// Measure execution time of a block
    func measureExecutionTime<T>(block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try block()
        let executionTime = Date().timeIntervalSince(startTime)
        return (result, executionTime)
    }
    
    /// Measure async execution time
    func measureAsyncExecutionTime<T>(block: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await block()
        let executionTime = Date().timeIntervalSince(startTime)
        return (result, executionTime)
    }
    
    // MARK: - Validation and Assertion Helpers
    
    /// Validate test assets are available
    func validateTestAssets() throws {
        // In a real implementation, this would check that test images exist in bundle
        // For now, we just validate that we can create mock images
        for imageType in TestImageType.allCases {
            let image = createMockMenuImage(for: imageType)
            guard image.size.width > 0 && image.size.height > 0 else {
                throw TestError.invalidTestAsset("Failed to create image for \(imageType)")
            }
        }
    }
    
    /// Validate OCR result quality
    func validateOCRResult(_ result: OCRResult, expectedAccuracy: Float = 0.8) -> Bool {
        return result.overallConfidence >= expectedAccuracy && !result.recognizedText.isEmpty
    }
    
    /// Validate dish extraction quality
    func validateDishExtraction(_ dishes: [Dish], minimumCount: Int = 1, minimumConfidence: Float = 0.7) -> Bool {
        guard dishes.count >= minimumCount else { return false }
        
        let averageConfidence = dishes.reduce(0.0) { $0 + $1.confidence } / Float(dishes.count)
        return averageConfidence >= minimumConfidence
    }
    
    // MARK: - Network Testing Helpers
    
    /// Get mock Anthropic certificate data
    func getAnthropicCertificateData() -> Data {
        // This would return actual certificate data in a real implementation
        return "MOCK_ANTHROPIC_CERT_DATA".data(using: .utf8) ?? Data()
    }
    
    /// Get fake certificate data for negative testing
    func getFakeCertificateData() -> Data {
        return "FAKE_CERTIFICATE_DATA".data(using: .utf8) ?? Data()
    }
    
    /// Create mock network conditions for testing
    func simulateNetworkConditions(_ condition: NetworkCondition) {
        // This would configure mock network conditions
        // Implementation would depend on network testing framework
    }
    
    // MARK: - Test Configuration
    
    enum NetworkCondition {
        case offline
        case slowConnection
        case intermittent
        case normal
        case fast
    }
    
    enum TestError: Error {
        case invalidTestAsset(String)
        case insufficientTestData
        case configurationError(String)
        
        var localizedDescription: String {
            switch self {
            case .invalidTestAsset(let message):
                return "Invalid test asset: \(message)"
            case .insufficientTestData:
                return "Insufficient test data provided"
            case .configurationError(let message):
                return "Test configuration error: \(message)"
            }
        }
    }
    
    // MARK: - Privacy Testing Helpers
    
    /// Create test dish with sensitive information
    func createSensitiveDish() -> Dish {
        return Dish(name: "Contact us at chef@restaurant.com",
                   description: "Call 555-123-4567 for reservations. Located at 123 Main St.",
                   price: "$25.00",
                   category: .mainCourse,
                   confidence: 0.9)
    }
    
    /// Create privacy-compliant test dish
    func createPrivacyCompliantDish() -> Dish {
        return Dish(name: "Grilled Salmon",
                   description: "Fresh Atlantic salmon with herbs and seasonal vegetables",
                   price: "$24.99",
                   category: .seafood,
                   confidence: 0.92)
    }
    
    // MARK: - Accessibility Testing Helpers
    
    /// Validate accessibility attributes
    func validateAccessibilityAttributes(_ element: NSObject) -> [String] {
        var issues: [String] = []
        
        // Check if element has accessibility label
        if let label = element.value(forKey: "accessibilityLabel") as? String, label.isEmpty {
            issues.append("Missing accessibility label")
        }
        
        // Check if element has accessibility traits
        if let traits = element.value(forKey: "accessibilityTraits") as? UInt64, traits == 0 {
            issues.append("Missing accessibility traits")
        }
        
        return issues
    }
    
    /// Create mock accessibility announcement
    func createAccessibilityAnnouncement(_ message: String) {
        // This would post accessibility notification in real implementation
        print("Accessibility announcement: \(message)")
    }
}

// MARK: - Extensions for Missing Types

// These would be defined in the actual OCRResult implementation
extension OCRResult {
    struct TextBlock {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        let recognitionLevel: VNRequestTextRecognitionLevel
        let alternatives: [String]
        let textType: TextType
    }
}

enum TextType {
    case dishName
    case price
    case description
    case sectionHeader
    case other
}

struct LayoutAnalysisResult {
    let detectedColumns: Int
    let menuSections: [MenuSection]
    let averageLineSpacing: CGFloat
    let textAlignment: TextAlignment
}

struct MenuSection {
    let header: String
    let boundingBox: CGRect
    let textBlocks: [OCRResult.TextBlock]
}

enum TextAlignment {
    case left
    case right
    case center
    case mixed
}

// Additional OCRResult initializer to match test usage
extension OCRResult {
    init(recognizedText: [TextBlock], 
         processingTime: TimeInterval, 
         overallConfidence: Float, 
         imageSize: CGSize, 
         detectedLanguages: [String], 
         layoutAnalysis: LayoutAnalysisResult?) {
        
        // Convert TextBlocks to RecognizedLines for compatibility
        let recognizedLines = recognizedText.map { block in
            RecognizedLine(text: block.text, 
                          confidence: block.confidence, 
                          boundingBox: block.boundingBox)
        }
        
        self.init(rawText: recognizedText.map { $0.text }.joined(separator: "\n"),
                 recognizedLines: recognizedLines,
                 confidence: overallConfidence,
                 processingTime: processingTime,
                 imageSize: imageSize)
    }
}