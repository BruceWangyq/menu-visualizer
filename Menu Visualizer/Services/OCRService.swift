//
//  OCRService.swift
//  Menu Visualizer
//
//  Advanced OCR service using Apple Vision framework with menu-specific optimizations
//

import SwiftUI
import Vision
import UIKit
import NaturalLanguage

/// Advanced OCR service with menu-specific optimizations and multi-language support
@MainActor
final class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentStage: ProcessingStage = .idle
    
    // MARK: - Configuration
    
    enum ProcessingStage: String, CaseIterable {
        case idle = "Ready"
        case preprocessing = "Preparing image"
        case textRecognition = "Recognizing text"
        case layoutAnalysis = "Analyzing layout"
        case postprocessing = "Optimizing results"
        case completed = "Completed"
    }
    
    enum OCRQuality: String, CaseIterable {
        case fast = "Fast"
        case balanced = "Balanced"
        case accurate = "Accurate"
        case maximum = "Maximum"
        
        var recognitionLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast, .balanced:
                return .fast
            case .accurate, .maximum:
                return .accurate
            }
        }
        
        var minimumTextHeight: Float {
            switch self {
            case .fast: return 0.03
            case .balanced: return 0.025
            case .accurate: return 0.02
            case .maximum: return 0.015
            }
        }
        
        var useImagePreprocessing: Bool {
            return self != .fast
        }
    }
    
    struct OCRConfiguration {
        let quality: OCRQuality
        let languages: [String]
        let enableLayoutAnalysis: Bool
        let enableRegionDetection: Bool
        let minimumConfidence: Float
        let maxProcessingTime: TimeInterval
        
        static let `default` = OCRConfiguration(
            quality: .balanced,
            languages: ["en-US"],
            enableLayoutAnalysis: true,
            enableRegionDetection: true,
            minimumConfidence: 0.1,
            maxProcessingTime: 30.0
        )
        
        static let menuOptimized = OCRConfiguration(
            quality: .accurate,
            languages: ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT"],
            enableLayoutAnalysis: true,
            enableRegionDetection: true,
            minimumConfidence: 0.2,
            maxProcessingTime: 45.0
        )
        
        static let performance = OCRConfiguration(
            quality: .fast,
            languages: ["en-US"],
            enableLayoutAnalysis: false,
            enableRegionDetection: false,
            minimumConfidence: 0.3,
            maxProcessingTime: 15.0
        )
    }
    
    // MARK: - Properties
    
    private let textRecognitionQueue = DispatchQueue(label: "com.menuly.ocr", qos: .userInitiated)
    private let imagePreprocessor = ImagePreprocessor()
    private var currentTask: Task<Void, Never>?
    private let languageRecognizer = NLLanguageRecognizer()
    
    // MARK: - Text Recognition
    
    /// Enhanced text extraction with automatic language detection and preprocessing
    func extractText(
        from image: UIImage,
        configuration: OCRConfiguration = .menuOptimized
    ) async -> Result<OCRResult, MenulyError> {
        guard !isProcessing else {
            return .failure(.ocrProcessingFailed)
        }
        
        // Cancel any existing task
        currentTask?.cancel()
        
        isProcessing = true
        processingProgress = 0.0
        currentStage = .preprocessing
        
        let startTime = Date()
        
        return await withTaskCancellationHandler {
            await performAdvancedTextRecognition(image: image, configuration: configuration, startTime: startTime)
        } onCancel: {
            Task { @MainActor in
                self.isProcessing = false
                self.processingProgress = 0.0
                self.currentStage = .idle
            }
        }
    }
    
    private func performAdvancedTextRecognition(
        image: UIImage,
        configuration: OCRConfiguration,
        startTime: Date
    ) async -> Result<OCRResult, MenulyError> {
        
        do {
            // Step 1: Image preprocessing (if enabled)
            var processedImage = image
            if configuration.quality.useImagePreprocessing {
                currentStage = .preprocessing
                processingProgress = 0.1
                
                let preprocessingConfig = imagePreprocessor.getOptimalConfiguration(for: .printed)
                
                let result = await imagePreprocessor.preprocessImage(image, configuration: preprocessingConfig) { progressHandler in
                    Task { @MainActor in
                        self.processingProgress = 0.1 + (progressHandler * 0.2)
                    }
                }
                
                switch result {
                case .success(let enhanced):
                    processedImage = enhanced
                case .failure(let error):
                    return .failure(error)
                }
            } else {
                processingProgress = 0.3
            }
            
            // Step 2: Language detection
            let detectedLanguages = await detectLanguages(in: image)
            let finalLanguages = mergeLanguages(detected: detectedLanguages, configured: configuration.languages)
            
            // Step 3: Text recognition
            currentStage = .textRecognition
            processingProgress = 0.4
            
            let textBlocks = try await performVisionTextRecognition(
                image: processedImage,
                languages: finalLanguages,
                configuration: configuration
            )
            
            // Step 4: Layout analysis (if enabled)
            currentStage = .layoutAnalysis
            processingProgress = 0.7
            
            let layoutAnalysisResult: LayoutAnalysisResult?
            if configuration.enableLayoutAnalysis {
                layoutAnalysisResult = await analyzeMenuLayout(textBlocks, imageSize: processedImage.size)
            } else {
                layoutAnalysisResult = nil
            }
            
            // Step 5: Post-processing and optimization
            currentStage = .postprocessing
            processingProgress = 0.9
            
            let optimizedBlocks = optimizeTextBlocks(textBlocks, layoutAnalysis: layoutAnalysisResult)
            
            // Step 6: Create final result
            let processingTime = Date().timeIntervalSince(startTime)
            let overallConfidence = calculateOverallConfidence(optimizedBlocks)
            
            let ocrResult = OCRResult(
                recognizedText: optimizedBlocks,
                processingTime: processingTime,
                overallConfidence: overallConfidence,
                imageSize: processedImage.size,
                detectedLanguages: detectedLanguages,
                layoutAnalysis: layoutAnalysisResult
            )
            
            currentStage = .completed
            processingProgress = 1.0
            
            // Final validation
            guard overallConfidence >= configuration.minimumConfidence else {
                return .failure(.lowConfidenceOCR(overallConfidence))
            }
            
            guard !optimizedBlocks.isEmpty else {
                return .failure(.noTextRecognized)
            }
            
            return .success(ocrResult)
            
        } catch {
            return .failure(.ocrProcessingFailed)
        }
    }
    
    // MARK: - Advanced Processing Methods
    
    private func performVisionTextRecognition(
        image: UIImage,
        languages: [String],
        configuration: OCRConfiguration
    ) async throws -> [OCRResult.TextBlock] {
        
        guard let cgImage = image.cgImage else {
            throw MenulyError.ocrProcessingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Vision OCR Error: \(error)")
                    continuation.resume(throwing: MenulyError.ocrProcessingFailed)
                    return
                }
                
                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: MenulyError.noTextRecognized)
                    return
                }
                
                let textBlocks = self.processVisionResults(results, minimumConfidence: configuration.minimumConfidence)
                continuation.resume(returning: textBlocks)
            }
            
            // Advanced configuration for menu text
            request.recognitionLevel = configuration.quality.recognitionLevel
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            request.minimumTextHeight = configuration.quality.minimumTextHeight
            request.customWords = self.getMenuSpecificVocabulary()
            
            // Enable automatic language detection if supported (iOS 16+)
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = languages.count > 1
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Vision request execution error: \(error)")
                continuation.resume(throwing: MenulyError.ocrProcessingFailed)
            }
        }
    }
    
    private func processVisionResults(
        _ results: [VNRecognizedTextObservation],
        minimumConfidence: Float
    ) -> [OCRResult.TextBlock] {
        
        var textBlocks: [OCRResult.TextBlock] = []
        
        for observation in results {
            // Try multiple candidates for better accuracy
            let candidates = observation.topCandidates(3)
            
            guard let bestCandidate = candidates.first,
                  bestCandidate.confidence >= minimumConfidence else { continue }
            
            let text = bestCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            
            // Additional filtering for menu-specific text
            guard isLikelyMenuText(text) else { continue }
            
            let textBlock = OCRResult.TextBlock(
                text: text,
                boundingBox: observation.boundingBox,
                confidence: bestCandidate.confidence,
                recognitionLevel: .accurate,
                alternatives: candidates.dropFirst().map { $0.string },
                textType: classifyTextType(text)
            )
            
            textBlocks.append(textBlock)
        }
        
        return textBlocks
    }
    
    // MARK: - Language Detection
    
    private func detectLanguages(in image: UIImage) async -> [String] {
        // This is a simplified implementation - in production you might want to
        // perform preliminary OCR with fast mode to detect languages
        return ["en-US"] // Default to English, can be enhanced with actual detection
    }
    
    private func mergeLanguages(detected: [String], configured: [String]) -> [String] {
        var finalLanguages = Set(configured)
        
        // Add detected languages that aren't already configured
        for lang in detected {
            finalLanguages.insert(lang)
        }
        
        // Limit to reasonable number for performance
        return Array(finalLanguages.prefix(5))
    }
    
    // MARK: - Layout Analysis
    
    private func analyzeMenuLayout(_ textBlocks: [OCRResult.TextBlock], imageSize: CGSize) async -> LayoutAnalysisResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.performLayoutAnalysis(textBlocks, imageSize: imageSize)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performLayoutAnalysis(_ textBlocks: [OCRResult.TextBlock], imageSize: CGSize) -> LayoutAnalysisResult {
        // Analyze text positioning to identify menu structure
        let sortedBlocks = textBlocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        
        var sections: [MenuSection] = []
        var currentSection: MenuSection?
        
        for block in sortedBlocks {
            if isPotentialSectionHeader(block) {
                // Save previous section if it exists
                if let section = currentSection {
                    sections.append(section)
                }
                
                // Start new section
                currentSection = MenuSection(
                    header: block.text,
                    boundingBox: block.boundingBox,
                    textBlocks: [block]
                )
            } else if var section = currentSection {
                section.textBlocks.append(block)
                currentSection = section
            } else {
                // Text without a clear section - create default section
                if currentSection == nil {
                    currentSection = MenuSection(
                        header: "Menu Items",
                        boundingBox: block.boundingBox,
                        textBlocks: [block]
                    )
                }
            }
        }
        
        // Don't forget the last section
        if let section = currentSection {
            sections.append(section)
        }
        
        return LayoutAnalysisResult(
            detectedColumns: detectColumnLayout(sortedBlocks),
            menuSections: sections,
            averageLineSpacing: calculateAverageLineSpacing(sortedBlocks),
            textAlignment: detectTextAlignment(sortedBlocks)
        )
    }
    
    // MARK: - Text Classification
    
    private func getMenuSpecificVocabulary() -> [String] {
        return [
            // Food categories
            "appetizers", "starters", "entrees", "mains", "desserts", "beverages",
            "salads", "soups", "pasta", "pizza", "seafood", "vegetarian", "vegan",
            
            // Common food items
            "chicken", "beef", "pork", "salmon", "shrimp", "lobster", "cheese",
            "pasta", "rice", "bread", "sauce", "dressing", "grilled", "fried",
            
            // Dietary information
            "gluten-free", "dairy-free", "organic", "spicy", "mild", "seasonal",
            
            // Restaurant terms
            "specials", "wine", "beer", "cocktails", "coffee", "tea"
        ]
    }
    
    private func isLikelyMenuText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Filter out obvious non-menu text
        guard trimmed.count >= 2 else { return false }
        guard !isOnlySymbols(trimmed) else { return false }
        guard !isOnlyNumbers(trimmed) else { return false }
        
        return true
    }
    
    private func classifyTextType(_ text: String) -> TextType {
        let trimmed = text.lowercased()
        
        // Check for prices
        if containsPrice(text) {
            return .price
        }
        
        // Check for section headers
        if isPotentialSectionHeader(text) {
            return .sectionHeader
        }
        
        // Check for dish names
        if isPotentialDishName(trimmed) {
            return .dishName
        }
        
        // Check for descriptions
        if trimmed.count > 30 && trimmed.contains(" ") {
            return .description
        }
        
        return .other
    }
    
    private func isPotentialSectionHeader(_ block: OCRResult.TextBlock) -> Bool {
        return isPotentialSectionHeader(block.text)
    }
    
    private func isPotentialSectionHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let sectionKeywords = [
            "appetizers", "starters", "entrees", "main courses", "mains",
            "desserts", "beverages", "drinks", "wine", "beer", "cocktails",
            "salads", "soups", "pasta", "pizza", "seafood", "specials"
        ]
        
        return sectionKeywords.contains { trimmed.contains($0) } ||
               (text.uppercased() == text && trimmed.count <= 20)
    }
    
    private func isPotentialDishName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        return words.count >= 2 && words.count <= 8 && !containsPrice(text)
    }
    
    private func containsPrice(_ text: String) -> Bool {
        let pricePattern = #"[\$€£¥]\s*\d+[\.,]?\d*"#
        let regex = try? NSRegularExpression(pattern: pricePattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex?.firstMatch(in: text, options: [], range: range) != nil
    }
    
    // MARK: - Text Optimization
    
    private func optimizeTextBlocks(_ textBlocks: [OCRResult.TextBlock], layoutAnalysis: LayoutAnalysisResult?) -> [OCRResult.TextBlock] {
        var optimized = textBlocks
        
        // Sort by reading order (top to bottom, left to right)
        optimized.sort { block1, block2 in
            let yDiff = abs(block1.boundingBox.minY - block2.boundingBox.minY)
            if yDiff < 0.02 { // Same line
                return block1.boundingBox.minX < block2.boundingBox.minX
            }
            return block1.boundingBox.minY > block2.boundingBox.minY
        }
        
        // Apply confidence-based filtering
        optimized = optimized.filter { $0.confidence >= 0.1 }
        
        // Merge adjacent blocks that likely belong together
        optimized = mergeAdjacentBlocks(optimized)
        
        return optimized
    }
    
    private func mergeAdjacentBlocks(_ blocks: [OCRResult.TextBlock]) -> [OCRResult.TextBlock] {
        guard blocks.count > 1 else { return blocks }
        
        var merged: [OCRResult.TextBlock] = []
        var currentBlock = blocks[0]
        
        for i in 1..<blocks.count {
            let nextBlock = blocks[i]
            
            if shouldMergeBlocks(currentBlock, nextBlock) {
                // Merge blocks
                let mergedText = "\(currentBlock.text) \(nextBlock.text)"
                let mergedBoundingBox = currentBlock.boundingBox.union(nextBlock.boundingBox)
                let averageConfidence = (currentBlock.confidence + nextBlock.confidence) / 2
                
                currentBlock = OCRResult.TextBlock(
                    text: mergedText,
                    boundingBox: mergedBoundingBox,
                    confidence: averageConfidence,
                    recognitionLevel: currentBlock.recognitionLevel,
                    alternatives: currentBlock.alternatives + nextBlock.alternatives,
                    textType: currentBlock.textType
                )
            } else {
                merged.append(currentBlock)
                currentBlock = nextBlock
            }
        }
        
        merged.append(currentBlock)
        return merged
    }
    
    private func shouldMergeBlocks(_ block1: OCRResult.TextBlock, _ block2: OCRResult.TextBlock) -> Bool {
        // Check if blocks are on the same line and close together
        let yDiff = abs(block1.boundingBox.midY - block2.boundingBox.midY)
        let xGap = block2.boundingBox.minX - block1.boundingBox.maxX
        
        return yDiff < 0.02 && xGap < 0.05 && xGap > -0.01
    }
    
    // MARK: - Layout Analysis Helpers
    
    private func detectColumnLayout(_ blocks: [OCRResult.TextBlock]) -> Int {
        // Simple column detection based on X positions
        let xPositions = blocks.map { $0.boundingBox.minX }
        let uniqueX = Set(xPositions.map { round($0 * 10) / 10 }) // Round to nearest 0.1
        
        return min(uniqueX.count, 3) // Cap at 3 columns for menus
    }
    
    private func calculateAverageLineSpacing(_ blocks: [OCRResult.TextBlock]) -> CGFloat {
        guard blocks.count > 1 else { return 0.0 }
        
        let sortedBlocks = blocks.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        var spacings: [CGFloat] = []
        
        for i in 0..<(sortedBlocks.count - 1) {
            let spacing = sortedBlocks[i].boundingBox.minY - sortedBlocks[i + 1].boundingBox.maxY
            if spacing > 0 {
                spacings.append(spacing)
            }
        }
        
        return spacings.isEmpty ? 0.0 : spacings.reduce(0, +) / CGFloat(spacings.count)
    }
    
    private func detectTextAlignment(_ blocks: [OCRResult.TextBlock]) -> TextAlignment {
        let leftAligned = blocks.filter { $0.boundingBox.minX < 0.1 }.count
        let rightAligned = blocks.filter { $0.boundingBox.minX > 0.7 }.count
        let centered = blocks.filter { $0.boundingBox.minX > 0.3 && $0.boundingBox.minX < 0.7 }.count
        
        if leftAligned > rightAligned && leftAligned > centered {
            return .left
        } else if rightAligned > leftAligned && rightAligned > centered {
            return .right
        } else if centered > leftAligned && centered > rightAligned {
            return .center
        } else {
            return .mixed
        }
    }
    
    private func calculateOverallConfidence(_ blocks: [OCRResult.TextBlock]) -> Float {
        guard !blocks.isEmpty else { return 0.0 }
        
        let totalConfidence = blocks.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(blocks.count)
    }
    
    // MARK: - Helper Functions
    
    private func isOnlySymbols(_ text: String) -> Bool {
        let symbolSet = CharacterSet.punctuationCharacters.union(.symbols)
        return text.unicodeScalars.allSatisfy { symbolSet.contains($0) }
    }
    
    private func isOnlyNumbers(_ text: String) -> Bool {
        return text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
    }
    
    // MARK: - Utility Methods
    
    func estimateProcessingTime(for imageSize: CGSize, quality: OCRQuality = .balanced) -> TimeInterval {
        let pixelCount = imageSize.width * imageSize.height
        let megapixels = pixelCount / (1024 * 1024)
        
        let baseTime: TimeInterval
        switch quality {
        case .fast:
            baseTime = 1.0
        case .balanced:
            baseTime = 2.5
        case .accurate:
            baseTime = 4.0
        case .maximum:
            baseTime = 6.0
        }
        
        let scaleFactor = sqrt(megapixels) // Diminishing returns for larger images
        return baseTime + (scaleFactor * 0.8)
    }
    
    func cancelProcessing() {
        currentTask?.cancel()
        
        Task { @MainActor in
            isProcessing = false
            processingProgress = 0.0
            currentStage = .idle
        }
    }
    
    // MARK: - Public API Extensions
    
    /// Quick quality assessment of an image for OCR suitability
    func assessImageQuality(_ image: UIImage) async -> ImagePreprocessor.QualityAssessment {
        return await imagePreprocessor.assessImageQuality(image)
    }
    
    /// Get optimal configuration for specific scenarios
    func getRecommendedConfiguration(for scenario: OCRScenario) -> OCRConfiguration {
        switch scenario {
        case .quickPreview:
            return .performance
        case .standardMenu:
            return .default
        case .detailedMenu:
            return .menuOptimized
        case .lowQualityImage:
            return OCRConfiguration(
                quality: .maximum,
                languages: ["en-US"],
                enableLayoutAnalysis: true,
                enableRegionDetection: true,
                minimumConfidence: 0.1,
                maxProcessingTime: 60.0
            )
        }
    }
    
    enum OCRScenario {
        case quickPreview
        case standardMenu
        case detailedMenu
        case lowQualityImage
    }
}


// MARK: - OCR Result Extensions

extension OCRResult {
    /// Get all recognized text as a single string
    var fullText: String {
        recognizedText
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY } // Sort by vertical position
            .map { $0.text }
            .joined(separator: "\n")
    }
    
    /// Get text blocks with confidence above threshold
    func textBlocks(withMinConfidence threshold: Float) -> [TextBlock] {
        recognizedText.filter { $0.confidence >= threshold }
    }
    
    /// Get high-confidence text suitable for dish extraction
    var highConfidenceText: [TextBlock] {
        textBlocks(withMinConfidence: 0.7)
    }
    
    /// Performance metrics summary
    var performanceMetrics: String {
        """
        OCR Performance:
        - Processing time: \(String(format: "%.2f", processingTime))s
        - Confidence: \(String(format: "%.1f", overallConfidence * 100))%
        - Text blocks: \(recognizedText.count)
        - Image size: \(Int(imageSize.width))×\(Int(imageSize.height))
        """
    }
}