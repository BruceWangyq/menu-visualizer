//
//  MenuParsingService.swift
//  Menu Visualizer
//
//  Advanced menu parsing service with intelligent dish extraction and price detection
//

import Foundation
import SwiftUI
import NaturalLanguage

/// Advanced service for parsing OCR results into structured dish information
@MainActor
final class MenuParsingService: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentStage: ParsingStage = .idle
    
    // MARK: - Configuration
    
    enum ParsingStage: String, CaseIterable {
        case idle = "Ready"
        case grouping = "Grouping text"
        case extracting = "Extracting dishes"
        case categorizing = "Categorizing items"
        case pricing = "Analyzing prices"
        case validation = "Validating results"
        case completed = "Completed"
    }
    
    struct ParsingConfiguration {
        let enableAdvancedPricing: Bool
        let enableCategoryDetection: Bool
        let enableDietaryAnalysis: Bool
        let minimumDishConfidence: Float
        let mergeSimilarDishes: Bool
        let enableLayoutAwareness: Bool
        
        static let `default` = ParsingConfiguration(
            enableAdvancedPricing: true,
            enableCategoryDetection: true,
            enableDietaryAnalysis: true,
            minimumDishConfidence: 0.3,
            mergeSimilarDishes: true,
            enableLayoutAwareness: true
        )
        
        static let fast = ParsingConfiguration(
            enableAdvancedPricing: false,
            enableCategoryDetection: false,
            enableDietaryAnalysis: false,
            minimumDishConfidence: 0.5,
            mergeSimilarDishes: false,
            enableLayoutAwareness: false
        )
        
        static let comprehensive = ParsingConfiguration(
            enableAdvancedPricing: true,
            enableCategoryDetection: true,
            enableDietaryAnalysis: true,
            minimumDishConfidence: 0.2,
            mergeSimilarDishes: true,
            enableLayoutAwareness: true
        )
    }
    
    // MARK: - Properties
    
    private let parsingQueue = DispatchQueue(label: "com.menuly.parsing", qos: .userInitiated)
    private let languageRecognizer = NLLanguageRecognizer()
    private let sentimentAnalyzer = NLSentimentAnalyzer()
    
    // Enhanced price detection patterns for multiple currencies
    private let pricePatterns = [
        #"[\$]\s*\d+(?:[.,]\d{2})?"#,  // USD: $12.99, $12,99
        #"[€]\s*\d+(?:[.,]\d{2})?"#,   // EUR: €12.99, €12,99
        #"[£]\s*\d+(?:[.,]\d{2})?"#,   // GBP: £12.99, £12,99
        #"[¥]\s*\d+(?:[.,]\d{2})?"#,   // JPY/CNY: ¥1299, ¥12.99
        #"\d+(?:[.,]\d{2})?\s*[\$€£¥]"#, // Reverse: 12.99$, 12,99€
        #"\d+\.\d{2}"#,                // Just numbers: 12.99
        #"\d+,\d{2}"#                  // European format: 12,99
    ]
    
    // MARK: - Menu Parsing
    
    /// Enhanced dish extraction with layout awareness and advanced parsing
    func extractDishes(
        from ocrResult: OCRResult,
        configuration: ParsingConfiguration = .default
    ) async -> Result<Menu, MenulyError> {
        guard !isProcessing else {
            return .failure(.dishExtractionFailed)
        }
        
        isProcessing = true
        processingProgress = 0.0
        currentStage = .grouping
        
        return await withTaskCancellationHandler {
            await performAdvancedDishExtraction(ocrResult: ocrResult, configuration: configuration)
        } onCancel: {
            Task { @MainActor in
                self.isProcessing = false
                self.processingProgress = 0.0
                self.currentStage = .idle
            }
        }
    }
    
    private func performAdvancedDishExtraction(
        ocrResult: OCRResult,
        configuration: ParsingConfiguration
    ) async -> Result<Menu, MenulyError> {
        
        do {
            currentStage = .grouping
            processingProgress = 0.1
            
            // Step 1: Analyze layout and group text intelligently
            let textGroups = await analyzeAndGroupText(ocrResult, configuration: configuration)
            
            currentStage = .extracting
            processingProgress = 0.3
            
            // Step 2: Extract potential dishes from grouped text
            let extractedDishes = await extractDishesFromGroups(textGroups, configuration: configuration)
            
            currentStage = .pricing
            processingProgress = 0.5
            
            // Step 3: Advanced price detection and association
            let dishesWithPrices = await associatePricesWithDishes(extractedDishes, ocrResult: ocrResult, configuration: configuration)
            
            currentStage = .categorizing
            processingProgress = 0.7
            
            // Step 4: Enhanced categorization and dietary analysis
            let categorizedDishes = await categorizeDishesIntelligently(dishesWithPrices, configuration: configuration)
            
            currentStage = .validation
            processingProgress = 0.9
            
            // Step 5: Validation and confidence scoring
            let validatedDishes = await validateAndScoreDishes(categorizedDishes, configuration: configuration)
            
            // Step 6: Extract restaurant information
            let restaurantInfo = await extractRestaurantInformation(ocrResult)
            
            currentStage = .completed
            processingProgress = 1.0
            
            guard !validatedDishes.isEmpty else {
                return .failure(.noDishesFound)
            }
            
            let menu = Menu(
                dishes: validatedDishes,
                restaurantName: restaurantInfo.name,
                ocrConfidence: ocrResult.overallConfidence
            )
            
            return .success(menu)
            
        } catch {
            return .failure(.dishExtractionFailed)
        }
    }
    
    // MARK: - Advanced Parsing Methods
    
    private func analyzeAndGroupText(
        _ ocrResult: OCRResult,
        configuration: ParsingConfiguration
    ) async -> [TextGroup] {
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                let textBlocks = ocrResult.recognizedText.filter { $0.confidence >= configuration.minimumDishConfidence }
                
                var groups: [TextGroup] = []
                
                if configuration.enableLayoutAwareness, let layoutAnalysis = ocrResult.layoutAnalysis {
                    // Use layout analysis for intelligent grouping
                    groups = self.groupByLayoutAnalysis(textBlocks, layoutAnalysis: layoutAnalysis)
                } else {
                    // Fall back to proximity-based grouping
                    groups = self.groupByProximity(textBlocks)
                }
                
                continuation.resume(returning: groups)
            }
        }
    }
    
    private func extractDishesFromGroups(
        _ textGroups: [TextGroup],
        configuration: ParsingConfiguration
    ) async -> [DishCandidate] {
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                var candidates: [DishCandidate] = []
                
                for group in textGroups {
                    if let candidate = self.extractDishCandidate(from: group, configuration: configuration) {
                        candidates.append(candidate)
                    }
                }
                
                continuation.resume(returning: candidates)
            }
        }
    }
    
    private func associatePricesWithDishes(
        _ dishCandidates: [DishCandidate],
        ocrResult: OCRResult,
        configuration: ParsingConfiguration
    ) async -> [DishCandidate] {
        
        guard configuration.enableAdvancedPricing else {
            return dishCandidates
        }
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                let priceBlocks = self.extractPriceBlocks(from: ocrResult.recognizedText)
                let enhancedCandidates = self.associatePrices(dishCandidates, with: priceBlocks)
                continuation.resume(returning: enhancedCandidates)
            }
        }
    }
    
    private func categorizeDishesIntelligently(
        _ dishCandidates: [DishCandidate],
        configuration: ParsingConfiguration
    ) async -> [DishCandidate] {
        
        guard configuration.enableCategoryDetection else {
            return dishCandidates
        }
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                let categorized = dishCandidates.map { candidate in
                    var updated = candidate
                    updated.category = self.intelligentCategoryDetection(for: candidate)
                    
                    if configuration.enableDietaryAnalysis {
                        updated.dietaryInfo = self.enhancedDietaryAnalysis(for: candidate)
                        updated.allergens = self.detectAllergens(in: candidate)
                    }
                    
                    return updated
                }
                continuation.resume(returning: categorized)
            }
        }
    }
    
    private func validateAndScoreDishes(
        _ dishCandidates: [DishCandidate],
        configuration: ParsingConfiguration
    ) async -> [Dish] {
        
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                var validDishes: [Dish] = []
                
                for candidate in dishCandidates {
                    // Calculate confidence score based on multiple factors
                    let confidenceScore = self.calculateDishConfidence(candidate)
                    
                    guard confidenceScore >= configuration.minimumDishConfidence else { continue }
                    
                    let dish = Dish(
                        name: candidate.name,
                        description: candidate.description,
                        price: candidate.price,
                        category: candidate.category,
                        allergens: candidate.allergens,
                        dietaryInfo: candidate.dietaryInfo,
                        extractionConfidence: confidenceScore
                    )
                    
                    validDishes.append(dish)
                }
                
                // Merge similar dishes if enabled
                let finalDishes = configuration.mergeSimilarDishes ? 
                    self.mergeSimilarDishes(validDishes) : validDishes
                
                continuation.resume(returning: finalDishes)
            }
        }
    }
    
    private func extractRestaurantInformation(_ ocrResult: OCRResult) async -> RestaurantInfo {
        return await withCheckedContinuation { continuation in
            parsingQueue.async {
                let info = self.analyzeRestaurantInfo(ocrResult)
                continuation.resume(returning: info)
            }
        }
    }
    
    // MARK: - Supporting Data Structures
    
    struct TextGroup {
        let blocks: [OCRResult.TextBlock]
        let boundingBox: CGRect
        let groupType: GroupType
        let confidence: Float
        
        enum GroupType {
            case dishItem
            case sectionHeader
            case priceOnly
            case description
            case restaurantInfo
        }
        
        var combinedText: String {
            blocks.map { $0.text }.joined(separator: " ")
        }
    }
    
    struct DishCandidate {
        let name: String
        var description: String?
        var price: String?
        var category: Dish.DishCategory?
        var allergens: [String]
        var dietaryInfo: [Dish.DietaryInfo]
        let sourceBlocks: [OCRResult.TextBlock]
        let groupConfidence: Float
        
        init(name: String, sourceBlocks: [OCRResult.TextBlock], groupConfidence: Float) {
            self.name = name
            self.sourceBlocks = sourceBlocks
            self.groupConfidence = groupConfidence
            self.allergens = []
            self.dietaryInfo = []
        }
    }
    
    struct RestaurantInfo {
        let name: String?
        let address: String?
        let phone: String?
        let website: String?
        let confidence: Float
    }
    
    struct PriceInfo {
        let value: String
        let currency: String?
        let position: CGRect
        let confidence: Float
        let originalText: String
    }
    
    // MARK: - Layout Analysis Methods
    
    private func groupByLayoutAnalysis(
        _ textBlocks: [OCRResult.TextBlock],
        layoutAnalysis: LayoutAnalysisResult
    ) -> [TextGroup] {
        
        var groups: [TextGroup] = []
        
        // Use menu sections from layout analysis
        for section in layoutAnalysis.menuSections {
            let sectionBlocks = textBlocks.filter { block in
                section.textBlocks.contains { $0.text == block.text }
            }
            
            if !sectionBlocks.isEmpty {
                let group = TextGroup(
                    blocks: sectionBlocks,
                    boundingBox: section.boundingBox,
                    groupType: .dishItem,
                    confidence: calculateGroupConfidence(sectionBlocks)
                )
                groups.append(group)
            }
        }
        
        // Add remaining blocks that weren't part of identified sections
        let assignedBlocks = Set(groups.flatMap { $0.blocks.map { $0.text } })
        let remainingBlocks = textBlocks.filter { !assignedBlocks.contains($0.text) }
        
        if !remainingBlocks.isEmpty {
            let proximityGroups = groupByProximity(remainingBlocks)
            groups.append(contentsOf: proximityGroups)
        }
        
        return groups
    }
    
    private func groupByProximity(_ textBlocks: [OCRResult.TextBlock]) -> [TextGroup] {
        var groups: [TextGroup] = []
        var processedBlocks = Set<String>()
        
        for block in textBlocks {
            let blockId = "\(block.text)_\(block.boundingBox.origin)"
            if processedBlocks.contains(blockId) { continue }
            
            var groupBlocks = [block]
            processedBlocks.insert(blockId)
            
            // Find nearby blocks
            for otherBlock in textBlocks {
                let otherBlockId = "\(otherBlock.text)_\(otherBlock.boundingBox.origin)"
                if processedBlocks.contains(otherBlockId) { continue }
                
                if areBlocksRelated(block, otherBlock) {
                    groupBlocks.append(otherBlock)
                    processedBlocks.insert(otherBlockId)
                }
            }
            
            let groupType = determineGroupType(groupBlocks)
            let boundingBox = calculateGroupBoundingBox(groupBlocks)
            let confidence = calculateGroupConfidence(groupBlocks)
            
            let group = TextGroup(
                blocks: groupBlocks,
                boundingBox: boundingBox,
                groupType: groupType,
                confidence: confidence
            )
            
            groups.append(group)
        }
        
        return groups
    }
    
    // MARK: - Dish Extraction Methods
    
    private func extractDishCandidate(
        from group: TextGroup,
        configuration: ParsingConfiguration
    ) -> DishCandidate? {
        
        guard group.groupType == .dishItem else { return nil }
        
        let combinedText = group.combinedText
        let lines = combinedText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return nil }
        
        // Identify the dish name (usually the first line or most prominent)
        var dishName = ""
        var description: String?
        
        for (index, line) in lines.enumerated() {
            if index == 0 || (dishName.isEmpty && isPotentialDishName(line)) {
                dishName = cleanDishName(line)
            } else if !line.isEmpty && description == nil && !containsPrice(line) {
                description = line
            }
        }
        
        guard !dishName.isEmpty, isDishNameValid(dishName) else { return nil }
        
        var candidate = DishCandidate(
            name: dishName,
            sourceBlocks: group.blocks,
            groupConfidence: group.confidence
        )
        
        candidate.description = description
        
        return candidate
    }
    
    // MARK: - Advanced Price Detection
    
    private func extractPriceBlocks(from textBlocks: [OCRResult.TextBlock]) -> [PriceInfo] {
        var priceInfos: [PriceInfo] = []
        
        for block in textBlocks {
            if let priceInfo = extractPriceInfo(from: block) {
                priceInfos.append(priceInfo)
            }
        }
        
        return priceInfos
    }
    
    private func extractPriceInfo(from block: OCRResult.TextBlock) -> PriceInfo? {
        let text = block.text
        
        for pattern in pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)) {
                
                let matchText = String(text[Range(match.range, in: text)!])
                let (value, currency) = parsePrice(matchText)
                
                return PriceInfo(
                    value: value,
                    currency: currency,
                    position: block.boundingBox,
                    confidence: block.confidence,
                    originalText: matchText
                )
            }
        }
        
        return nil
    }
    
    private func parsePrice(_ priceText: String) -> (value: String, currency: String?) {
        let currencySymbols = ["$", "€", "£", "¥"]
        
        for symbol in currencySymbols {
            if priceText.contains(symbol) {
                let value = priceText.replacingOccurrences(of: symbol, with: "").trimmingCharacters(in: .whitespaces)
                return (value, symbol)
            }
        }
        
        // No currency symbol found
        return (priceText, nil)
    }
    
    private func associatePrices(_ candidates: [DishCandidate], with priceInfos: [PriceInfo]) -> [DishCandidate] {
        return candidates.map { candidate in
            var updated = candidate
            
            // Find the nearest price based on spatial proximity
            let nearestPrice = findNearestPrice(to: candidate, in: priceInfos)
            if let price = nearestPrice {
                updated.price = formatPrice(price)
            }
            
            return updated
        }
    }
    
    private func findNearestPrice(to candidate: DishCandidate, in priceInfos: [PriceInfo]) -> PriceInfo? {
        guard !priceInfos.isEmpty else { return nil }
        
        let candidateBounds = calculateCandidateBounds(candidate)
        
        let sortedPrices = priceInfos.sorted { price1, price2 in
            let distance1 = calculateDistance(from: candidateBounds, to: price1.position)
            let distance2 = calculateDistance(from: candidateBounds, to: price2.position)
            return distance1 < distance2
        }
        
        // Return the nearest price if it's reasonably close
        if let nearest = sortedPrices.first {
            let distance = calculateDistance(from: candidateBounds, to: nearest.position)
            return distance < 0.15 ? nearest : nil // 15% of screen width as max distance
        }
        
        return nil
    }
    
    private func formatPrice(_ priceInfo: PriceInfo) -> String {
        if let currency = priceInfo.currency {
            return "\(currency)\(priceInfo.value)"
        } else {
            return priceInfo.value
        }
    }
    
    // MARK: - Public API Extensions
    
    /// Cancel ongoing parsing operation
    func cancelProcessing() {
        Task { @MainActor in
            isProcessing = false
            processingProgress = 0.0
            currentStage = .idle
        }
    }
    
    /// Get recommended parsing configuration for different scenarios
    func getRecommendedConfiguration(for scenario: ParsingScenario) -> ParsingConfiguration {
        switch scenario {
        case .quickScan:
            return .fast
        case .standardMenu:
            return .default
        case .detailedAnalysis:
            return .comprehensive
        case .lowQualityImage:
            return ParsingConfiguration(
                enableAdvancedPricing: true,
                enableCategoryDetection: true,
                enableDietaryAnalysis: true,
                minimumDishConfidence: 0.1,
                mergeSimilarDishes: true,
                enableLayoutAwareness: true
            )
        }
    }
    
    enum ParsingScenario {
        case quickScan
        case standardMenu
        case detailedAnalysis
        case lowQualityImage
    }
}

// MARK: - Legacy Support (for backward compatibility)

extension MenuParsingService {
    
    /// Legacy method for backward compatibility
    func extractDishes(from ocrResult: OCRResult) async -> Result<Menu, MenulyError> {
        return await extractDishes(from: ocrResult, configuration: .default)
    }
    
    // Note: Legacy grouping methods have been replaced with enhanced layout-aware grouping
    // See groupByProximity() and groupByLayoutAnalysis() methods above for the improved implementation
}