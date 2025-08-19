//
//  MenuParsingTests.swift
//  Menu VisualizerTests
//
//  Tests for menu parsing and dish extraction accuracy
//  Validates dish name recognition, price extraction, and categorization
//

import XCTest
@testable import Menu_Visualizer

final class MenuParsingTests: XCTestCase {
    
    var menuParsingService: MenuParsingService!
    var testUtilities: TestUtilities!
    
    // Accuracy benchmarks
    private let parsingThresholds = ParsingThresholds(
        dishNameAccuracy: 0.90,    // 90% accuracy for dish name extraction
        priceAccuracy: 0.85,       // 85% accuracy for price extraction
        categoryAccuracy: 0.80,    // 80% accuracy for dish categorization
        minimumConfidence: 0.7     // Minimum confidence for accepted dishes
    )
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        menuParsingService = MenuParsingService()
        testUtilities = TestUtilities()
    }
    
    override func tearDownWithError() throws {
        menuParsingService = nil
        testUtilities = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Dish Name Extraction Tests
    
    func testSimpleDishNameExtraction() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Caesar Salad", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$12.95", type: .price, confidence: 0.95),
            TestUtilities.createTextBlock(text: "Grilled Chicken Breast", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "$18.50", type: .price, confidence: 0.92)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 2, "Should extract 2 dishes")
        
        let dishNames = extractedDishes.map { $0.name }
        XCTAssertTrue(dishNames.contains("Caesar Salad"), "Should extract Caesar Salad")
        XCTAssertTrue(dishNames.contains("Grilled Chicken Breast"), "Should extract Grilled Chicken Breast")
        
        // Validate confidence scores
        for dish in extractedDishes {
            XCTAssertGreaterThanOrEqual(dish.confidence, parsingThresholds.minimumConfidence,
                                       "Dish confidence below threshold: \(dish.name)")
        }
    }
    
    func testComplexDishNameExtraction() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Pan-Seared Atlantic Salmon", type: .dishName, confidence: 0.87),
            TestUtilities.createTextBlock(text: "with lemon butter sauce", type: .description, confidence: 0.82),
            TestUtilities.createTextBlock(text: "$24.00", type: .price, confidence: 0.94),
            TestUtilities.createTextBlock(text: "Beef Tenderloin Medallions", type: .dishName, confidence: 0.89),
            TestUtilities.createTextBlock(text: "served with roasted vegetables", type: .description, confidence: 0.85),
            TestUtilities.createTextBlock(text: "$32.00", type: .price, confidence: 0.96)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 2, "Should extract 2 complex dishes")
        
        let firstDish = extractedDishes.first { $0.name.contains("Salmon") }
        XCTAssertNotNil(firstDish, "Should find salmon dish")
        XCTAssertEqual(firstDish?.price, "$24.00", "Should extract correct price")
        XCTAssertTrue(firstDish?.description?.contains("lemon butter") ?? false, "Should include description")
        
        let secondDish = extractedDishes.first { $0.name.contains("Tenderloin") }
        XCTAssertNotNil(secondDish, "Should find beef dish")
        XCTAssertEqual(secondDish?.price, "$32.00", "Should extract correct price")
        XCTAssertTrue(secondDish?.description?.contains("roasted vegetables") ?? false, "Should include description")
    }
    
    func testDishNameWithSpecialCharacters() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Coq au Vin", type: .dishName, confidence: 0.85),
            TestUtilities.createTextBlock(text: "Café au Lait", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "Crème Brûlée", type: .dishName, confidence: 0.82),
            TestUtilities.createTextBlock(text: "Piña Colada", type: .dishName, confidence: 0.90)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 4, "Should extract all dishes with special characters")
        
        let dishNames = extractedDishes.map { $0.name }
        XCTAssertTrue(dishNames.contains("Coq au Vin"), "Should handle French dish names")
        XCTAssertTrue(dishNames.contains("Café au Lait"), "Should handle accented characters")
        XCTAssertTrue(dishNames.contains("Crème Brûlée"), "Should handle multiple accents")
        XCTAssertTrue(dishNames.contains("Piña Colada"), "Should handle Spanish characters")
    }
    
    // MARK: - Price Extraction Tests
    
    func testDollarPriceExtraction() async throws {
        let testCases = [
            ("$12.99", "$12.99"),
            ("$ 15.50", "$15.50"),
            ("$8", "$8.00"),
            ("12.95$", "$12.95"),
            ("USD 20.00", "$20.00")
        ]
        
        for (inputText, expectedPrice) in testCases {
            let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
                TestUtilities.createTextBlock(text: "Test Dish", type: .dishName, confidence: 0.9),
                TestUtilities.createTextBlock(text: inputText, type: .price, confidence: 0.9)
            ])
            
            let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
            
            XCTAssertEqual(extractedDishes.count, 1, "Should extract one dish for: \(inputText)")
            XCTAssertEqual(extractedDishes.first?.price, expectedPrice,
                          "Price parsing failed for: \(inputText)")
        }
    }
    
    func testEuropeanPriceExtraction() async throws {
        let testCases = [
            ("€15.99", "€15.99"),
            ("£12.50", "£12.50"),
            ("¥800", "¥800"),
            ("15,50 €", "€15.50")
        ]
        
        for (inputText, expectedPrice) in testCases {
            let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
                TestUtilities.createTextBlock(text: "Test Dish", type: .dishName, confidence: 0.9),
                TestUtilities.createTextBlock(text: inputText, type: .price, confidence: 0.9)
            ])
            
            let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
            
            XCTAssertEqual(extractedDishes.count, 1, "Should extract one dish for: \(inputText)")
            XCTAssertEqual(extractedDishes.first?.price, expectedPrice,
                          "European price parsing failed for: \(inputText)")
        }
    }
    
    func testPriceRangeExtraction() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Pizza", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$12 - $18", type: .price, confidence: 0.88),
            TestUtilities.createTextBlock(text: "Pasta", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$14-16", type: .price, confidence: 0.85)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 2, "Should extract both dishes with price ranges")
        
        let pizzaDish = extractedDishes.first { $0.name == "Pizza" }
        XCTAssertEqual(pizzaDish?.price, "$12-$18", "Should handle price range with spaces")
        
        let pastaDish = extractedDishes.first { $0.name == "Pasta" }
        XCTAssertEqual(pastaDish?.price, "$14-$16", "Should handle price range without spaces")
    }
    
    // MARK: - Category Classification Tests
    
    func testAppetizingCategoryClassification() async throws {
        let appetizerKeywords = [
            "Buffalo Wings", "Mozzarella Sticks", "Nachos", "Calamari", "Bruschetta",
            "Shrimp Cocktail", "Stuffed Mushrooms", "Spinach Dip"
        ]
        
        for dishName in appetizerKeywords {
            let dish = Dish(name: dishName, description: nil, price: "$8.99", 
                           category: .unknown, confidence: 0.9)
            let classifiedDish = await menuParsingService.classifyDish(dish)
            
            XCTAssertEqual(classifiedDish.category, .appetizer,
                          "\(dishName) should be classified as appetizer")
        }
    }
    
    func testMainCourseCategoryClassification() async throws {
        let mainCourseKeywords = [
            "Grilled Salmon", "Ribeye Steak", "Chicken Parmesan", "Lamb Chops",
            "Pork Tenderloin", "Sea Bass", "Beef Brisket"
        ]
        
        for dishName in mainCourseKeywords {
            let dish = Dish(name: dishName, description: nil, price: "$24.99",
                           category: .unknown, confidence: 0.9)
            let classifiedDish = await menuParsingService.classifyDish(dish)
            
            XCTAssertEqual(classifiedDish.category, .mainCourse,
                          "\(dishName) should be classified as main course")
        }
    }
    
    func testDessertCategoryClassification() async throws {
        let dessertKeywords = [
            "Chocolate Cake", "Cheesecake", "Tiramisu", "Ice Cream", "Apple Pie",
            "Crème Brûlée", "Brownie", "Gelato"
        ]
        
        for dishName in dessertKeywords {
            let dish = Dish(name: dishName, description: nil, price: "$7.99",
                           category: .unknown, confidence: 0.9)
            let classifiedDish = await menuParsingService.classifyDish(dish)
            
            XCTAssertEqual(classifiedDish.category, .dessert,
                          "\(dishName) should be classified as dessert")
        }
    }
    
    func testBeverageCategoryClassification() async throws {
        let beverageKeywords = [
            "Coffee", "Espresso", "Latte", "Wine", "Beer", "Cocktail", "Soda",
            "Juice", "Tea", "Smoothie"
        ]
        
        for dishName in beverageKeywords {
            let dish = Dish(name: dishName, description: nil, price: "$4.99",
                           category: .unknown, confidence: 0.9)
            let classifiedDish = await menuParsingService.classifyDish(dish)
            
            XCTAssertEqual(classifiedDish.category, .beverage,
                          "\(dishName) should be classified as beverage")
        }
    }
    
    func testVegetarianCategoryClassification() async throws {
        let vegetarianDishes = [
            ("Veggie Burger", "plant-based patty with vegetables"),
            ("Quinoa Salad", "fresh quinoa with mixed vegetables"),
            ("Vegetarian Pasta", "pasta with seasonal vegetables"),
            ("Garden Salad", "mixed greens with vegetables")
        ]
        
        for (dishName, description) in vegetarianDishes {
            let dish = Dish(name: dishName, description: description, price: "$12.99",
                           category: .unknown, confidence: 0.9)
            let classifiedDish = await menuParsingService.classifyDish(dish)
            
            XCTAssertEqual(classifiedDish.category, .vegetarian,
                          "\(dishName) should be classified as vegetarian")
        }
    }
    
    // MARK: - Menu Structure Parsing Tests
    
    func testSectionHeaderDetection() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "APPETIZERS", type: .sectionHeader, confidence: 0.95),
            TestUtilities.createTextBlock(text: "Caesar Salad", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$8.99", type: .price, confidence: 0.94),
            TestUtilities.createTextBlock(text: "MAIN COURSES", type: .sectionHeader, confidence: 0.93),
            TestUtilities.createTextBlock(text: "Grilled Salmon", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "$22.99", type: .price, confidence: 0.96)
        ])
        
        let menuStructure = try await menuParsingService.parseMenuStructure(from: ocrResult)
        
        XCTAssertEqual(menuStructure.sections.count, 2, "Should detect 2 menu sections")
        
        let appetizerSection = menuStructure.sections.first { $0.header == "APPETIZERS" }
        XCTAssertNotNil(appetizerSection, "Should find appetizer section")
        XCTAssertEqual(appetizerSection?.dishes.count, 1, "Appetizer section should have 1 dish")
        
        let mainCourseSection = menuStructure.sections.first { $0.header == "MAIN COURSES" }
        XCTAssertNotNil(mainCourseSection, "Should find main course section")
        XCTAssertEqual(mainCourseSection?.dishes.count, 1, "Main course section should have 1 dish")
    }
    
    func testMultiColumnMenuParsing() async throws {
        // Create mock OCR result with multi-column layout
        let leftColumnBlocks = [
            TestUtilities.createTextBlock(text: "Appetizers", type: .sectionHeader, confidence: 0.95, boundingBox: CGRect(x: 0.1, y: 0.9, width: 0.35, height: 0.05)),
            TestUtilities.createTextBlock(text: "Wings", type: .dishName, confidence: 0.88, boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.04)),
            TestUtilities.createTextBlock(text: "$9.99", type: .price, confidence: 0.92, boundingBox: CGRect(x: 0.3, y: 0.8, width: 0.1, height: 0.04))
        ]
        
        let rightColumnBlocks = [
            TestUtilities.createTextBlock(text: "Desserts", type: .sectionHeader, confidence: 0.93, boundingBox: CGRect(x: 0.6, y: 0.9, width: 0.3, height: 0.05)),
            TestUtilities.createTextBlock(text: "Cake", type: .dishName, confidence: 0.87, boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.15, height: 0.04)),
            TestUtilities.createTextBlock(text: "$6.99", type: .price, confidence: 0.94, boundingBox: CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.04))
        ]
        
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: leftColumnBlocks + rightColumnBlocks)
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 2, "Should extract dishes from both columns")
        
        let wingsDish = extractedDishes.first { $0.name == "Wings" }
        let cakeDish = extractedDishes.first { $0.name == "Cake" }
        
        XCTAssertNotNil(wingsDish, "Should extract wings from left column")
        XCTAssertNotNil(cakeDish, "Should extract cake from right column")
        XCTAssertEqual(wingsDish?.price, "$9.99", "Should associate correct price")
        XCTAssertEqual(cakeDish?.price, "$6.99", "Should associate correct price")
    }
    
    // MARK: - Description Extraction Tests
    
    func testDishDescriptionExtraction() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Grilled Atlantic Salmon", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "Fresh salmon fillet grilled to perfection, served with seasonal vegetables and rice pilaf", type: .description, confidence: 0.85),
            TestUtilities.createTextBlock(text: "$24.99", type: .price, confidence: 0.95),
            TestUtilities.createTextBlock(text: "Beef Tenderloin", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "8oz certified Angus beef, grilled and served with mashed potatoes", type: .description, confidence: 0.82),
            TestUtilities.createTextBlock(text: "$32.00", type: .price, confidence: 0.96)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        XCTAssertEqual(extractedDishes.count, 2, "Should extract both dishes with descriptions")
        
        let salmonDish = extractedDishes.first { $0.name.contains("Salmon") }
        XCTAssertNotNil(salmonDish?.description, "Salmon dish should have description")
        XCTAssertTrue(salmonDish?.description?.contains("seasonal vegetables") ?? false,
                     "Should include description details")
        
        let beefDish = extractedDishes.first { $0.name.contains("Tenderloin") }
        XCTAssertNotNil(beefDish?.description, "Beef dish should have description")
        XCTAssertTrue(beefDish?.description?.contains("certified Angus") ?? false,
                     "Should include description details")
    }
    
    func testDescriptionWithAllergensAndDietary() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Quinoa Buddha Bowl", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "Organic quinoa with roasted vegetables, avocado, and tahini dressing (V, GF)", type: .description, confidence: 0.87),
            TestUtilities.createTextBlock(text: "$16.99", type: .price, confidence: 0.93),
            TestUtilities.createTextBlock(text: "Seafood Linguine", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "Fresh pasta with shrimp, scallops, and mussels in white wine sauce (Contains shellfish)", type: .description, confidence: 0.84),
            TestUtilities.createTextBlock(text: "$22.99", type: .price, confidence: 0.95)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        let buddhaBowl = extractedDishes.first { $0.name.contains("Buddha") }
        XCTAssertTrue(buddhaBowl?.description?.contains("(V, GF)") ?? false,
                     "Should preserve dietary indicators")
        
        let linguine = extractedDishes.first { $0.name.contains("Linguine") }
        XCTAssertTrue(linguine?.description?.contains("shellfish") ?? false,
                     "Should preserve allergen information")
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyOCRResultHandling() async throws {
        let emptyOCRResult = testUtilities.createEmptyOCRResult()
        
        do {
            let dishes = try await menuParsingService.extractDishes(from: emptyOCRResult)
            XCTAssertTrue(dishes.isEmpty, "Empty OCR result should return no dishes")
        } catch {
            XCTFail("Should handle empty OCR result gracefully: \(error)")
        }
    }
    
    func testLowConfidenceTextHandling() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Unclear Dish", type: .dishName, confidence: 0.3),
            TestUtilities.createTextBlock(text: "$??", type: .price, confidence: 0.2),
            TestUtilities.createTextBlock(text: "Clear Dish", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "$12.99", type: .price, confidence: 0.95)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        // Should filter out low confidence dishes
        XCTAssertEqual(extractedDishes.count, 1, "Should only extract high confidence dish")
        XCTAssertEqual(extractedDishes.first?.name, "Clear Dish", "Should extract the clear dish")
    }
    
    func testMalformedPriceHandling() async throws {
        let ocrResult = testUtilities.createMockOCRResult(textBlocks: [
            TestUtilities.createTextBlock(text: "Good Dish", type: .dishName, confidence: 0.9),
            TestUtilities.createTextBlock(text: "ABC.XY", type: .price, confidence: 0.7),
            TestUtilities.createTextBlock(text: "Another Dish", type: .dishName, confidence: 0.88),
            TestUtilities.createTextBlock(text: "$15.99", type: .price, confidence: 0.94)
        ])
        
        let extractedDishes = try await menuParsingService.extractDishes(from: ocrResult)
        
        let goodDish = extractedDishes.first { $0.name == "Good Dish" }
        XCTAssertNil(goodDish?.price, "Should handle malformed price gracefully")
        
        let anotherDish = extractedDishes.first { $0.name == "Another Dish" }
        XCTAssertEqual(anotherDish?.price, "$15.99", "Should parse valid price correctly")
    }
    
    // MARK: - Performance Tests
    
    func testMenuParsingPerformance() async throws {
        let largeMenuOCR = testUtilities.createLargeMenuOCRResult(dishCount: 100)
        
        let startTime = Date()
        let extractedDishes = try await menuParsingService.extractDishes(from: largeMenuOCR)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThanOrEqual(processingTime, 5.0, "Large menu parsing should complete within 5 seconds")
        XCTAssertGreaterThan(extractedDishes.count, 80, "Should extract most dishes from large menu")
        
        // Validate parsing quality
        let averageConfidence = extractedDishes.reduce(0.0) { $0 + $1.confidence } / Float(extractedDishes.count)
        XCTAssertGreaterThanOrEqual(averageConfidence, parsingThresholds.minimumConfidence,
                                   "Average confidence should meet threshold")
    }
    
    // MARK: - Integration Tests
    
    func testFullMenuParsingWorkflow() async throws {
        // Test with realistic restaurant menu structure
        let restaurantMenuOCR = testUtilities.createRestaurantMenuOCRResult()
        
        let menuStructure = try await menuParsingService.parseMenuStructure(from: restaurantMenuOCR)
        let extractedDishes = try await menuParsingService.extractDishes(from: restaurantMenuOCR)
        
        // Validate menu structure
        XCTAssertGreaterThan(menuStructure.sections.count, 3, "Should detect multiple sections")
        XCTAssertTrue(menuStructure.sections.contains { $0.header.lowercased().contains("appetizer") },
                     "Should detect appetizer section")
        XCTAssertTrue(menuStructure.sections.contains { $0.header.lowercased().contains("main") },
                     "Should detect main course section")
        
        // Validate dish extraction
        XCTAssertGreaterThan(extractedDishes.count, 15, "Should extract significant number of dishes")
        
        // Validate categorization distribution
        let categoryGroups = extractedDishes.groupedByCategory()
        XCTAssertGreaterThan(categoryGroups.keys.count, 3, "Should have multiple categories")
        XCTAssertFalse(categoryGroups[.unknown]?.isEmpty == false || categoryGroups[.unknown] == nil,
                      "Most dishes should be properly categorized")
        
        // Validate price extraction
        let dishesWithPrices = extractedDishes.filter { $0.price != nil }
        let priceExtractionRate = Double(dishesWithPrices.count) / Double(extractedDishes.count)
        XCTAssertGreaterThanOrEqual(priceExtractionRate, parsingThresholds.priceAccuracy,
                                   "Price extraction rate below threshold: \(priceExtractionRate)")
    }
}

// MARK: - Test Configuration

private struct ParsingThresholds {
    let dishNameAccuracy: Double
    let priceAccuracy: Double
    let categoryAccuracy: Double
    let minimumConfidence: Float
}

// MARK: - Helper Extensions

private extension MenuParsingService {
    func classifyDish(_ dish: Dish) async -> Dish {
        // This would be implemented in the actual service
        return dish
    }
    
    func parseMenuStructure(from ocrResult: OCRResult) async throws -> MenuStructure {
        // This would be implemented in the actual service
        return MenuStructure(sections: [])
    }
}

private struct MenuStructure {
    let sections: [MenuSection]
}

private struct MenuSection {
    let header: String
    let dishes: [Dish]
}