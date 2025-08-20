//
//  AIMenuAnalysisService.swift
//  Menu Visualizer
//
//  AI-powered menu analysis service using Gemini 1.5 Flash
//  Replaces OCRService + MenuParsingService pipeline for improved accuracy and speed
//

import Foundation
import SwiftUI
import UIKit
import CryptoKit
import FirebaseCore
import FirebaseAI

/// AI-powered menu analysis service that directly extracts structured menu data from images
@MainActor
final class AIMenuAnalysisService: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentStage: ProcessingStage = .idle
    
    // MARK: - Configuration
    
    enum ProcessingStage: String, CaseIterable {
        case idle = "Ready"
        case preparing = "Preparing image"
        case analyzing = "Analyzing menu with AI"
        case extracting = "Extracting dishes"
        case structuring = "Structuring data"
        case validating = "Validating results"
        case completed = "Completed"
    }
    
    enum AIServiceError: LocalizedError {
        case firebaseNotConfigured
        case firebaseInitializationFailed
        case imageProcessingFailed
        case apiRequestFailed(String)
        case invalidResponse
        case parsingFailed
        case lowConfidence(Float)
        case rateLimitExceeded
        case networkError
        case authenticationFailed
        case modelNotFound
        case quotaExceeded
        
        var errorDescription: String? {
            switch self {
            case .firebaseNotConfigured:
                return "Firebase AI Logic not properly configured"
            case .firebaseInitializationFailed:
                return "Failed to initialize Firebase AI services"
            case .imageProcessingFailed:
                return "Failed to process image for AI analysis"
            case .apiRequestFailed(let message):
                return "AI API request failed: \(message)"
            case .invalidResponse:
                return "Invalid response from AI service"
            case .parsingFailed:
                return "Failed to parse AI response"
            case .lowConfidence(let confidence):
                return "AI confidence too low: \(Int(confidence * 100))%"
            case .rateLimitExceeded:
                return "API rate limit exceeded, please try again later"
            case .networkError:
                return "Network connection error"
            case .authenticationFailed:
                return "Authentication failed - check Firebase configuration"
            case .modelNotFound:
                return "Gemini model not available"
            case .quotaExceeded:
                return "API quota exceeded, please check billing settings"
            }
        }
    }
    
    struct AnalysisConfiguration {
        let maxImageSize: CGSize
        let compressionQuality: CGFloat
        let minimumConfidence: Float
        let maxRetries: Int
        let timeoutInterval: TimeInterval
        let enableDetailedAnalysis: Bool
        
        static let `default` = AnalysisConfiguration(
            maxImageSize: CGSize(width: 1024, height: 1024),
            compressionQuality: 0.8,
            minimumConfidence: 0.7,
            maxRetries: 2,
            timeoutInterval: 30.0,
            enableDetailedAnalysis: true
        )
        
        static let fast = AnalysisConfiguration(
            maxImageSize: CGSize(width: 768, height: 768),
            compressionQuality: 0.7,
            minimumConfidence: 0.6,
            maxRetries: 1,
            timeoutInterval: 15.0,
            enableDetailedAnalysis: false
        )
        
        static let highQuality = AnalysisConfiguration(
            maxImageSize: CGSize(width: 1536, height: 1536),
            compressionQuality: 0.9,
            minimumConfidence: 0.8,
            maxRetries: 3,
            timeoutInterval: 45.0,
            enableDetailedAnalysis: true
        )
    }
    
    // MARK: - Properties
    
    private let model: GenerativeModel
    private let firebaseAI: FirebaseAI
    private var currentTask: Task<Void, Never>?
    private let responseCache: NSCache<NSString, CachedMenuResult> = {
        let cache = NSCache<NSString, CachedMenuResult>()
        cache.countLimit = 20
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB cache
        return cache
    }()
    private let imageOptimizer = AIImageOptimizer()
    
    // MARK: - Initialization
    
    init() {
        // Initialize Firebase AI with Gemini Developer API backend
        self.firebaseAI = FirebaseAI.firebaseAI(backend: .googleAI())
        
        // Create the Gemini model instance
        self.model = firebaseAI.generativeModel(modelName: "gemini-2.5-flash")
    }
    
    // MARK: - Main Analysis Method
    
    /// Analyze menu image and extract structured dish information using AI
    func analyzeMenu(
        from image: UIImage,
        configuration: AnalysisConfiguration = .default
    ) async -> Result<Menu, MenulyError> {
        guard !isProcessing else {
            return .failure(.aiServiceConfigurationError("Service is already processing another request"))
        }
        
        // Firebase AI Logic handles authentication through Firebase project configuration
        // No need to check API key explicitly as it's managed by Firebase
        
        // Cancel any existing task
        currentTask?.cancel()
        
        isProcessing = true
        processingProgress = 0.0
        currentStage = .preparing
        
        let startTime = Date()
        let imageHash = generateImageHash(image)
        
        // Check cache first
        if let cachedResult = responseCache.object(forKey: NSString(string: imageHash)) {
            if Date().timeIntervalSince(cachedResult.timestamp) < 300 { // 5 minute cache
                print("✅ Using cached AI menu analysis result")
                await completeProcessing()
                return .success(cachedResult.menu)
            }
        }
        
        return await withTaskCancellationHandler {
            await performAIMenuAnalysis(
                image: image,
                configuration: configuration,
                startTime: startTime,
                imageHash: imageHash
            )
        } onCancel: {
            Task { @MainActor in
                self.isProcessing = false
                self.processingProgress = 0.0
                self.currentStage = .idle
            }
        }
    }
    
    private func performAIMenuAnalysis(
        image: UIImage,
        configuration: AnalysisConfiguration,
        startTime: Date,
        imageHash: String
    ) async -> Result<Menu, MenulyError> {
        
        do {
            // Step 1: Image preprocessing with AI optimizer
            currentStage = .preparing
            processingProgress = 0.1
            
            let optimizerConfig = getOptimizerConfiguration(from: configuration)
            let optimizationResult = await imageOptimizer.optimizeForAI(image, configuration: optimizerConfig)
            
            let processedImage: UIImage
            switch optimizationResult {
            case .success(let optimizedImage):
                processedImage = optimizedImage.image
                print("✅ Image optimization successful: \(optimizedImage.sizeSavings) size reduction")
                print("📊 Applied optimizations: \(optimizedImage.optimizations.map { $0.rawValue }.joined(separator: ", "))")
            case .failure(let error):
                print("⚠️ Image optimization failed: \(error.localizedDescription), using original image")
                processedImage = image
            }
            
            // Step 2: AI Analysis
            currentStage = .analyzing
            processingProgress = 0.2
            
            let prompt = createMenuAnalysisPrompt(detailedAnalysis: configuration.enableDetailedAnalysis)
            
            currentStage = .extracting
            processingProgress = 0.4
            
            // Make AI request with timeout
            let response = try await withTimeout(configuration.timeoutInterval) {
                try await self.model.generateContent(prompt, processedImage)
            }
            
            currentStage = .structuring
            processingProgress = 0.7
            
            // Step 3: Parse response
            guard let responseText = response.text else {
                throw AIServiceError.invalidResponse
            }
            
            let menuResponse = try parseAIResponse(responseText)
            
            // Step 4: Validation
            currentStage = .validating
            processingProgress = 0.9
            
            guard menuResponse.confidence >= configuration.minimumConfidence else {
                throw AIServiceError.lowConfidence(menuResponse.confidence)
            }
            
            // Step 5: Create menu object
            let processingTime = Date().timeIntervalSince(startTime)
            let menu = try createMenuFromResponse(menuResponse, processingTime: processingTime)
            
            // Cache successful result
            let cachedResult = CachedMenuResult(menu: menu, timestamp: Date())
            responseCache.setObject(cachedResult, forKey: NSString(string: imageHash))
            
            await completeProcessing()
            
            print("✅ AI menu analysis completed in \(String(format: "%.2f", processingTime))s")
            print("📊 Extracted \(menu.dishes.count) dishes with \(Int(menuResponse.confidence * 100))% confidence")
            
            return .success(menu)
            
        } catch let error as AIServiceError {
            await handleError(error)
            return .failure(mapAIServiceError(error))
        } catch {
            await handleError(.apiRequestFailed(error.localizedDescription))
            return .failure(mapGenericError(error))
        }
    }
    
    // MARK: - Configuration Mapping
    
    private func getOptimizerConfiguration(from analysisConfig: AnalysisConfiguration) -> AIImageOptimizer.OptimizationConfiguration {
        if analysisConfig.enableDetailedAnalysis {
            return .aiOptimized
        } else {
            return .fast
        }
    }
    
    // MARK: - Prompt Engineering
    
    private func createMenuAnalysisPrompt(detailedAnalysis: Bool) -> String {
        let basePrompt = """
        Analyze this menu image and extract all dishes with their information. You are a restaurant menu analysis expert.
        
        Return ONLY a valid JSON response with this exact structure (no additional text before or after):
        
        {
          "restaurantName": "string or null",
          "dishes": [
            {
              "name": "dish name",
              "description": "description or null",
              "price": "price string with currency symbol or null",
              "category": "appetizer|mainCourse|dessert|beverage|special|unknown",
              "allergens": ["array of detected allergens like gluten, dairy, nuts, etc"],
              "dietaryInfo": ["vegetarian", "vegan", "glutenFree", "dairyFree", "spicy", "healthy"]
            }
          ],
          "confidence": 0.95
        }
        
        IMPORTANT INSTRUCTIONS:
        - Extract ALL dishes, appetizers, mains, desserts, and beverages you can see
        - For prices: include currency symbols ($, €, £, ¥) and exact formatting as shown
        - If price is unclear, use null instead of guessing
        - For descriptions: extract any description text near the dish name
        - Categories: appetizer (starters), mainCourse (entrees/mains), dessert, beverage, special (chef's specials), unknown
        - Allergens: common ones like "gluten", "dairy", "nuts", "eggs", "shellfish", "soy"
        - DietaryInfo: "vegetarian", "vegan", "glutenFree", "dairyFree", "spicy", "healthy"
        - Set confidence based on text clarity and completeness (0.7-0.95 range)
        """
        
        if detailedAnalysis {
            return basePrompt + """
            
            DETAILED ANALYSIS MODE:
            - Pay extra attention to small text and footnotes
            - Look for dietary symbols (V, VG, GF markers)
            - Extract ingredient information when visible
            - Identify seasonal or chef's special items
            - Note any pricing variations (small/large portions)
            - Preserve original formatting and spelling of dish names
            """
        }
        
        return basePrompt
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(_ responseText: String) throws -> AIMenuResponse {
        // Clean the response text
        let cleanedText = responseText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw AIServiceError.parsingFailed
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AIMenuResponse.self, from: data)
        } catch {
            print("❌ JSON Parsing Error: \(error)")
            print("📄 Response Text: \(cleanedText)")
            throw AIServiceError.parsingFailed
        }
    }
    
    private func createMenuFromResponse(_ response: AIMenuResponse, processingTime: TimeInterval) throws -> Menu {
        // Convert AI dishes to app dishes
        let dishes = response.dishes.map { aiDish -> Dish in
            let category = DishCategory.fromAICategory(aiDish.category)
            let dietaryInfo = aiDish.dietaryInfo.compactMap { Dish.DietaryInfo(rawValue: $0) }
            
            return Dish(
                name: aiDish.name,
                description: aiDish.description,
                price: aiDish.price,
                category: category,
                allergens: aiDish.allergens,
                dietaryInfo: dietaryInfo,
                extractionConfidence: response.confidence
            )
        }
        
        // Create synthetic OCR result for compatibility
        let syntheticOCRResult = OCRResult(
            recognizedText: [],
            processingTime: processingTime,
            overallConfidence: response.confidence,
            imageSize: CGSize(width: 1024, height: 1024)
        )
        
        return Menu(
            extractedDishes: dishes,
            ocrResult: syntheticOCRResult,
            restaurantName: response.restaurantName
        )
    }
    
    // MARK: - Utility Methods
    
    private func generateImageHash(_ image: UIImage) -> String {
        guard let imageData = image.pngData() else { return UUID().uuidString }
        return imageData.sha256
    }
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AIServiceError.networkError
            }
            
            guard let result = try await group.next() else {
                throw AIServiceError.networkError
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private func completeProcessing() async {
        currentStage = .completed
        processingProgress = 1.0
        isProcessing = false
        
        // Reset after delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        if currentStage == .completed {
            currentStage = .idle
            processingProgress = 0.0
        }
    }
    
    private func handleError(_ error: AIServiceError) async {
        print("❌ AIMenuAnalysisService error: \(error.localizedDescription)")
        isProcessing = false
        processingProgress = 0.0
        currentStage = .idle
    }
    
    // MARK: - Error Mapping
    
    private func mapAIServiceError(_ error: AIServiceError) -> MenulyError {
        switch error {
        case .firebaseNotConfigured:
            return .aiServiceConfigurationError("Firebase AI Logic not configured")
        case .firebaseInitializationFailed:
            return .aiServiceConfigurationError("Firebase initialization failed")
        case .imageProcessingFailed:
            return .aiImageOptimizationFailed
        case .apiRequestFailed(let message):
            if message.contains("rate limit") || message.contains("quota") {
                return .aiQuotaExceeded
            } else if message.contains("timeout") {
                return .aiAnalysisTimeout
            } else if message.contains("model") {
                return .aiModelNotFound
            } else if message.contains("auth") || message.contains("permission") {
                return .aiServiceConfigurationError("Authentication failed: \(message)")
            } else {
                return .aiServiceConfigurationError(message)
            }
        case .invalidResponse:
            return .aiResponseParsingFailed
        case .parsingFailed:
            return .aiResponseParsingFailed
        case .lowConfidence(let confidence):
            return .aiConfidenceTooLow(confidence)
        case .rateLimitExceeded:
            return .aiQuotaExceeded
        case .networkError:
            return .networkUnavailable
        case .authenticationFailed:
            return .aiServiceConfigurationError("Firebase authentication failed")
        case .modelNotFound:
            return .aiModelNotFound
        case .quotaExceeded:
            return .aiQuotaExceeded
        }
    }
    
    private func mapGenericError(_ error: Error) -> MenulyError {
        let errorMessage = error.localizedDescription
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .networkUnavailable
        } else if errorMessage.contains("timeout") {
            return .aiAnalysisTimeout
        } else if errorMessage.contains("cancelled") {
            return .processingTimeout
        } else if errorMessage.contains("memory") {
            return .insufficientMemory
        } else if errorMessage.contains("firebase") || errorMessage.contains("Firebase") {
            return .aiServiceConfigurationError("Firebase error: \(errorMessage)")
        } else if errorMessage.contains("authentication") || errorMessage.contains("auth") {
            return .aiServiceConfigurationError("Authentication error: \(errorMessage)")
        } else if errorMessage.contains("quota") || errorMessage.contains("billing") {
            return .aiQuotaExceeded
        } else if errorMessage.contains("model") {
            return .aiModelNotFound
        } else {
            return .aiServiceConfigurationError(errorMessage)
        }
    }
    
    // MARK: - Public Utility Methods
    
    func cancelProcessing() {
        currentTask?.cancel()
        Task { @MainActor in
            isProcessing = false
            processingProgress = 0.0
            currentStage = .idle
        }
    }
    
    func clearCache() {
        responseCache.removeAllObjects()
        imageOptimizer.clearCache()
    }
    
    /// Get comprehensive cache information
    func getCacheInfo() -> (responses: Int, images: Int, metadata: Int) {
        let imageInfo = imageOptimizer.getCacheInfo()
        return (responseCache.countLimit, imageInfo.imageCount, imageInfo.metadataCount)
    }
    
    /// Assess image quality before processing
    func assessImageQuality(_ image: UIImage) async -> ImageQualityAssessment {
        return await imageOptimizer.assessImageQuality(image)
    }
    
    func estimateProcessingTime(for imageSize: CGSize, configuration: AnalysisConfiguration = .default) -> TimeInterval {
        let megapixels = (imageSize.width * imageSize.height) / (1024 * 1024)
        let baseTime: TimeInterval = configuration.enableDetailedAnalysis ? 8.0 : 6.0
        let scaleFactor = min(sqrt(megapixels), 2.0) // Cap scaling effect
        return baseTime + (scaleFactor * 1.0)
    }
}

// MARK: - Supporting Data Structures

private struct AIMenuResponse: Codable {
    let restaurantName: String?
    let dishes: [AIDish]
    let confidence: Float
}

private struct AIDish: Codable {
    let name: String
    let description: String?
    let price: String?
    let category: String
    let allergens: [String]
    let dietaryInfo: [String]
}

private class CachedMenuResult {
    let menu: Menu
    let timestamp: Date
    
    init(menu: Menu, timestamp: Date) {
        self.menu = menu
        self.timestamp = timestamp
    }
}

// MARK: - Extensions

extension DishCategory {
    static func fromAICategory(_ aiCategory: String) -> DishCategory {
        switch aiCategory.lowercased() {
        case "appetizer", "starter", "starters":
            return .appetizer
        case "maincourse", "main", "mains", "entree", "entrees":
            return .mainCourse
        case "dessert", "desserts", "sweet", "sweets":
            return .dessert
        case "beverage", "beverages", "drink", "drinks":
            return .beverage
        case "special", "specials", "chef":
            return .special
        default:
            return .unknown
        }
    }
}

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension Data {
    var sha256: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension SHA256Digest {
    var string: String {
        compactMap { String(format: "%02x", $0) }.joined()
    }
}