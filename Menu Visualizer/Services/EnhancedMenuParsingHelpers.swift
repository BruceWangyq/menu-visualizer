//
//  EnhancedMenuParsingHelpers.swift
//  Menu Visualizer
//
//  Helper methods for advanced menu parsing functionality
//

import Foundation
import SwiftUI
import NaturalLanguage

extension MenuParsingService {
    
    // MARK: - Helper Calculation Methods
    
    func calculateGroupConfidence(_ blocks: [OCRResult.TextBlock]) -> Float {
        guard !blocks.isEmpty else { return 0.0 }
        let totalConfidence = blocks.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(blocks.count)
    }
    
    func calculateGroupBoundingBox(_ blocks: [OCRResult.TextBlock]) -> CGRect {
        guard !blocks.isEmpty else { return CGRect.zero }
        
        let minX = blocks.map { $0.boundingBox.minX }.min() ?? 0
        let minY = blocks.map { $0.boundingBox.minY }.min() ?? 0
        let maxX = blocks.map { $0.boundingBox.maxX }.max() ?? 0
        let maxY = blocks.map { $0.boundingBox.maxY }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func calculateCandidateBounds(_ candidate: DishCandidate) -> CGRect {
        return calculateGroupBoundingBox(candidate.sourceBlocks)
    }
    
    func calculateDistance(from rect1: CGRect, to rect2: CGRect) -> CGFloat {
        let center1 = CGPoint(x: rect1.midX, y: rect1.midY)
        let center2 = CGPoint(x: rect2.midX, y: rect2.midY)
        
        let dx = center1.x - center2.x
        let dy = center1.y - center2.y
        
        return sqrt(dx * dx + dy * dy)
    }
    
    func determineGroupType(_ blocks: [OCRResult.TextBlock]) -> TextGroup.GroupType {
        let combinedText = blocks.map { $0.text }.joined(separator: " ").lowercased()
        
        // Check for section headers
        let headerKeywords = ["appetizers", "entrees", "mains", "desserts", "beverages", "drinks", "wine", "specials"]
        if headerKeywords.contains(where: { combinedText.contains($0) }) {
            return .sectionHeader
        }
        
        // Check for price-only blocks
        if blocks.count == 1 && containsPrice(blocks[0].text) && blocks[0].text.split(separator: " ").count <= 2 {
            return .priceOnly
        }
        
        // Check for restaurant info (typically at top of menu)
        if isRestaurantInfo(combinedText) {
            return .restaurantInfo
        }
        
        // Check for descriptions (longer text without obvious dish structure)
        if combinedText.count > 50 && !isPotentialDishName(combinedText) {
            return .description
        }
        
        return .dishItem
    }
    
    // MARK: - Text Analysis Methods
    
    func areBlocksRelated(_ block1: OCRResult.TextBlock, _ block2: OCRResult.TextBlock) -> Bool {
        let verticalThreshold: CGFloat = 0.03
        let horizontalThreshold: CGFloat = 0.1
        
        // Check if blocks are on the same line
        let yDifference = abs(block1.boundingBox.midY - block2.boundingBox.midY)
        if yDifference < verticalThreshold {
            return true
        }
        
        // Check if blocks are vertically aligned
        let xOverlap = max(0, min(block1.boundingBox.maxX, block2.boundingBox.maxX) - 
                          max(block1.boundingBox.minX, block2.boundingBox.minX))
        let overlapRatio = xOverlap / min(block1.boundingBox.width, block2.boundingBox.width)
        
        return overlapRatio > horizontalThreshold && yDifference < 0.15
    }
    
    func isPotentialDishName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        
        // Basic filtering
        guard words.count >= 2 && words.count <= 10 else { return false }
        guard !containsPrice(text) else { return false }
        guard !isHeaderText(text) else { return false }
        
        // Look for food-related keywords
        let foodKeywords = [
            "salad", "soup", "pasta", "chicken", "beef", "fish", "salmon", "pizza",
            "sandwich", "burger", "wrap", "bowl", "rice", "noodles", "steak",
            "shrimp", "lobster", "dessert", "cake", "pie", "cream", "grilled",
            "fried", "roasted", "steamed", "sautéed", "braised"
        ]
        
        let textLower = text.lowercased()
        let hasKeyword = foodKeywords.contains { textLower.contains($0) }
        
        // Additional scoring based on capitalization and structure
        let isCapitalized = text.first?.isUppercase == true
        let hasReasonableLength = text.count >= 5 && text.count <= 50
        
        return hasKeyword || (isCapitalized && hasReasonableLength)
    }
    
    func isDishNameValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmed.isEmpty &&
               trimmed.count >= 3 &&
               trimmed.count <= 100 &&
               !containsPrice(trimmed) &&
               !isHeaderText(trimmed) &&
               !isRestaurantInfo(trimmed)
    }
    
    func cleanDishName(_ name: String) -> String {
        var cleaned = name
        
        // Remove price patterns
        for pattern in MenuParsingService.pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Remove common menu artifacts
        let artifactPatterns = ["\\(.*?\\)", "\\[.*?\\]", "\\*+", "#+"]
        for pattern in artifactPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func containsPrice(_ text: String) -> Bool {
        for pattern in MenuParsingService.pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    func isHeaderText(_ text: String) -> Bool {
        let headerKeywords = [
            "appetizers", "entrees", "mains", "main courses", "desserts", "beverages",
            "drinks", "starters", "salads", "soups", "menu", "specials", "wine",
            "beer", "cocktails", "sides"
        ]
        
        let textLower = text.lowercased()
        return headerKeywords.contains { textLower.contains($0) } || 
               (text.uppercased() == text && text.count <= 25)
    }
    
    func isRestaurantInfo(_ text: String) -> Bool {
        let infoKeywords = [
            "restaurant", "cafe", "bistro", "grill", "kitchen", "bar", "pub",
            "tel", "phone", "address", "www", ".com", "hours", "open", "closed"
        ]
        
        let textLower = text.lowercased()
        return infoKeywords.contains { textLower.contains($0) }
    }
    
    // MARK: - Advanced Analysis Methods
    
    func intelligentCategoryDetection(for candidate: DishCandidate) -> Dish.DishCategory {
        let fullText = "\(candidate.name) \(candidate.description ?? "")".lowercased()
        
        // Enhanced category detection with confidence scoring
        let categoryScores: [Dish.DishCategory: Float] = [
            .appetizer: calculateCategoryScore(fullText, keywords: [
                "appetizer", "starter", "small plate", "share", "tapas", "bruschetta",
                "soup", "salad", "wings", "nachos", "dip", "cheese", "olives"
            ]),
            .mainCourse: calculateCategoryScore(fullText, keywords: [
                "entree", "main", "pasta", "pizza", "burger", "steak", "chicken",
                "fish", "salmon", "beef", "pork", "lamb", "seafood", "rice", "noodles"
            ]),
            .dessert: calculateCategoryScore(fullText, keywords: [
                "dessert", "sweet", "cake", "pie", "ice cream", "chocolate",
                "cheesecake", "cookie", "brownie", "fruit", "sorbet", "pudding"
            ]),
            .beverage: calculateCategoryScore(fullText, keywords: [
                "drink", "beverage", "coffee", "tea", "juice", "soda", "water",
                "wine", "beer", "cocktail", "smoothie", "latte", "cappuccino"
            ]),
            .special: calculateCategoryScore(fullText, keywords: [
                "special", "chef", "signature", "house", "seasonal", "featured", "daily"
            ])
        ]
        
        // Return category with highest score
        let bestCategory = categoryScores.max { $0.value < $1.value }
        return bestCategory?.key ?? .mainCourse
    }
    
    private func calculateCategoryScore(_ text: String, keywords: [String]) -> Float {
        let matches = keywords.filter { text.contains($0) }
        return Float(matches.count) / Float(keywords.count)
    }
    
    func enhancedDietaryAnalysis(for candidate: DishCandidate) -> [Dish.DietaryInfo] {
        let fullText = "\(candidate.name) \(candidate.description ?? "")".lowercased()
        var dietaryInfo: [Dish.DietaryInfo] = []
        
        // Enhanced dietary detection
        let dietaryKeywords: [Dish.DietaryInfo: [String]] = [
            .vegetarian: ["vegetarian", "veggie", "no meat", "plant-based"],
            .vegan: ["vegan", "plant-based", "no dairy", "no eggs"],
            .glutenFree: ["gluten free", "gluten-free", "gf", "celiac"],
            .dairyFree: ["dairy free", "dairy-free", "lactose free", "no dairy"],
            .spicy: ["spicy", "hot", "chili", "jalapeño", "habanero", "sriracha", "🌶"],
            .healthy: ["healthy", "light", "low fat", "fresh", "organic", "superfood"]
        ]
        
        for (info, keywords) in dietaryKeywords {
            if keywords.contains(where: { fullText.contains($0) }) {
                dietaryInfo.append(info)
            }
        }
        
        return Array(Set(dietaryInfo)) // Remove duplicates
    }
    
    func detectAllergens(in candidate: DishCandidate) -> [String] {
        let fullText = "\(candidate.name) \(candidate.description ?? "")".lowercased()
        
        let allergenKeywords = [
            "nuts": ["nuts", "almond", "walnut", "pecan", "cashew", "pistachio"],
            "peanuts": ["peanut", "peanuts"],
            "shellfish": ["shellfish", "shrimp", "lobster", "crab", "oyster", "clam"],
            "fish": ["fish", "salmon", "tuna", "cod", "halibut"],
            "eggs": ["egg", "eggs", "mayo", "mayonnaise"],
            "dairy": ["milk", "cheese", "butter", "cream", "yogurt"],
            "soy": ["soy", "tofu", "soybean", "edamame"],
            "wheat": ["wheat", "bread", "pasta", "flour", "gluten"]
        ]
        
        var detectedAllergens: [String] = []
        
        for (allergen, keywords) in allergenKeywords {
            if keywords.contains(where: { fullText.contains($0) }) {
                detectedAllergens.append(allergen)
            }
        }
        
        return detectedAllergens
    }
    
    func calculateDishConfidence(_ candidate: DishCandidate) -> Float {
        var confidence: Float = candidate.groupConfidence
        
        // Boost confidence for well-structured dishes
        if candidate.price != nil { confidence += 0.2 }
        if candidate.description != nil && candidate.description!.count > 10 { confidence += 0.1 }
        if candidate.category != nil && candidate.category != .unknown { confidence += 0.1 }
        
        // Penalize poor dish names
        if candidate.name.count < 5 { confidence -= 0.2 }
        if candidate.name.uppercased() == candidate.name { confidence -= 0.1 }
        
        return min(1.0, max(0.0, confidence))
    }
    
    func mergeSimilarDishes(_ dishes: [Dish]) -> [Dish] {
        var mergedDishes: [Dish] = []
        var processedIndices = Set<Int>()
        
        for (i, dish) in dishes.enumerated() {
            if processedIndices.contains(i) { continue }
            
            var currentDish = dish
            processedIndices.insert(i)
            
            // Look for similar dishes to merge
            for (j, otherDish) in dishes.enumerated() {
                if i != j && !processedIndices.contains(j) {
                    if areDishiesSimilar(dish, otherDish) {
                        currentDish = mergeDishes(currentDish, otherDish)
                        processedIndices.insert(j)
                    }
                }
            }
            
            mergedDishes.append(currentDish)
        }
        
        return mergedDishes
    }
    
    private func areDishiesSimilar(_ dish1: Dish, _ dish2: Dish) -> Bool {
        let similarity = calculateStringSimilarity(dish1.name, dish2.name)
        return similarity > 0.8 // 80% similarity threshold
    }
    
    private func calculateStringSimilarity(_ str1: String, _ str2: String) -> Float {
        let words1 = Set(str1.lowercased().split(separator: " "))
        let words2 = Set(str2.lowercased().split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Float(intersection.count) / Float(union.count)
    }
    
    private func mergeDishes(_ dish1: Dish, _ dish2: Dish) -> Dish {
        // Choose the dish with higher confidence as base
        let baseDish = dish1.extractionConfidence >= dish2.extractionConfidence ? dish1 : dish2
        let otherDish = dish1.extractionConfidence >= dish2.extractionConfidence ? dish2 : dish1
        
        return Dish(
            name: baseDish.name,
            description: baseDish.description ?? otherDish.description,
            price: baseDish.price ?? otherDish.price,
            category: baseDish.category ?? otherDish.category,
            allergens: Array(Set(baseDish.allergens + otherDish.allergens)),
            dietaryInfo: Array(Set(baseDish.dietaryInfo + otherDish.dietaryInfo)),
            extractionConfidence: max(baseDish.extractionConfidence, otherDish.extractionConfidence)
        )
    }
    
    func analyzeRestaurantInfo(_ ocrResult: OCRResult) -> RestaurantInfo {
        let allText = ocrResult.recognizedText.map { $0.text }.joined(separator: " ")
        
        // Simple restaurant name extraction (first few lines of high-confidence text)
        let topBlocks = ocrResult.recognizedText
            .filter { $0.confidence > 0.7 }
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .prefix(3)
        
        let potentialName = topBlocks.first { block in
            !isHeaderText(block.text) && 
            !containsPrice(block.text) && 
            block.text.count >= 3 && 
            block.text.count <= 50
        }?.text
        
        return RestaurantInfo(
            name: potentialName,
            address: nil, // Could be enhanced with address detection
            phone: nil,   // Could be enhanced with phone detection
            website: nil, // Could be enhanced with URL detection
            confidence: potentialName != nil ? 0.7 : 0.0
        )
    }
}