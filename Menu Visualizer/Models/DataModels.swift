//
//  DataModels.swift
//  Menu Visualizer
//
//  Privacy-first data models for Menuly app
//

import Foundation
import SwiftUI
import Vision

// MARK: - Core Data Models

/// Represents extracted menu information with privacy compliance
struct Menu: Identifiable, Codable, Hashable {
    let id = UUID()
    let timestamp: Date
    let extractedDishes: [Dish]
    let restaurantName: String?
    let ocrResult: OCRResult
    
    var ocrConfidence: Float {
        return ocrResult.overallConfidence
    }
    
    // Legacy compatibility
    var dishes: [Dish] {
        return extractedDishes
    }
    
    init(dishes: [Dish], restaurantName: String? = nil, ocrConfidence: Float = 0.0) {
        self.timestamp = Date()
        self.extractedDishes = dishes
        self.restaurantName = restaurantName
        // Create a minimal OCR result for backward compatibility
        self.ocrResult = OCRResult(
            recognizedText: [],
            processingTime: 0.0,
            overallConfidence: ocrConfidence,
            imageSize: CGSize.zero
        )
    }
    
    init(extractedDishes: [Dish], ocrResult: OCRResult, restaurantName: String? = nil) {
        self.timestamp = Date()
        self.extractedDishes = extractedDishes
        self.ocrResult = ocrResult
        self.restaurantName = restaurantName
    }
}

/// Individual dish information extracted from menu
struct Dish: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let description: String?
    let price: String?
    let category: DishCategory?
    let allergens: [String]
    let dietaryInfo: [DietaryInfo]
    let extractionConfidence: Float
    
    var confidence: Float {
        return extractionConfidence
    }
    
    // AI-generated content
    var aiVisualization: DishVisualization?
    var isGenerating: Bool
    
    enum DishCategory: String, CaseIterable, Codable {
        case appetizer = "Appetizer"
        case mainCourse = "Main Course"
        case dessert = "Dessert"
        case beverage = "Beverage"
        case special = "Special"
        case unknown = "Unknown"
        
        // Legacy support
        case vegetarian = "Vegetarian"
        case salad = "Salad"
        case seafood = "Seafood"
        
        // Missing categories
        case soup = "Soup"
        case pasta = "Pasta"
        case meat = "Meat"
        
        var icon: String {
            switch self {
            case .appetizer: return "🥗"
            case .mainCourse: return "🍽️"
            case .dessert: return "🍰"
            case .beverage: return "🥤"
            case .special: return "⭐"
            case .vegetarian: return "🌱"
            case .salad: return "🥬"
            case .seafood: return "🐟"
            case .soup: return "🍲"
            case .pasta: return "🍝"
            case .meat: return "🥩"
            case .unknown: return "❓"
            }
        }
    }
    
    enum DietaryInfo: String, CaseIterable, Codable {
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case glutenFree = "Gluten Free"
        case dairyFree = "Dairy Free"
        case spicy = "Spicy"
        case healthy = "Healthy"
    }
    
    init(name: String, description: String? = nil, price: String? = nil, 
         category: DishCategory? = nil, allergens: [String] = [], 
         dietaryInfo: [DietaryInfo] = [], extractionConfidence: Float = 0.0,
         aiVisualization: DishVisualization? = nil, isGenerating: Bool = false) {
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.allergens = allergens
        self.dietaryInfo = dietaryInfo
        self.extractionConfidence = extractionConfidence
        self.aiVisualization = aiVisualization
        self.isGenerating = isGenerating
    }
    
    /// Privacy-safe dish representation for API calls (excludes personal data)
    func toAPIPayload() -> DishAPIPayload {
        DishAPIPayload(
            name: name,
            description: description,
            category: category?.rawValue ?? "Unknown"
        )
    }
    
    /// Create a copy of the dish with an AI visualization
    func withVisualization(_ visualization: DishVisualization) -> Dish {
        return Dish(
            name: self.name,
            description: self.description,
            price: self.price,
            category: self.category,
            allergens: self.allergens,
            dietaryInfo: self.dietaryInfo,
            extractionConfidence: self.extractionConfidence,
            aiVisualization: visualization,
            isGenerating: self.isGenerating
        )
    }
}

/// AI-generated dish visualization from Claude API
struct DishVisualization: Codable, Hashable {
    let id: UUID
    let dishId: UUID
    let generatedDescription: String
    let visualStyle: String
    let ingredients: [String]
    let preparationNotes: String
    let timestamp: Date
    let retentionPolicy: PrivacySettings.DataRetentionPolicy
    
    init(dishId: UUID, generatedDescription: String, visualStyle: String, 
         ingredients: [String], preparationNotes: String, 
         retentionPolicy: PrivacySettings.DataRetentionPolicy = .sessionOnly) {
        self.id = UUID()
        self.dishId = dishId
        self.generatedDescription = generatedDescription
        self.visualStyle = visualStyle
        self.ingredients = ingredients
        self.preparationNotes = preparationNotes
        self.timestamp = Date()
        self.retentionPolicy = retentionPolicy
    }
}

/// Privacy-safe API payload for dish visualization requests
struct DishAPIPayload: Codable {
    let name: String
    let description: String?
    let category: String
    
    var isPrivacySafe: Bool {
        // Check that the payload doesn't contain sensitive information
        let sensitivePatterns = ["credit card", "ssn", "social security", "phone", "address"]
        let combinedText = "\(name) \(description ?? "")".lowercased()
        return !sensitivePatterns.contains { combinedText.contains($0) }
    }
}

// MARK: - OCR Result Models

/// Contains OCR processing results with confidence metrics and layout analysis
struct OCRResult: Codable, Hashable, Equatable {
    let id = UUID()
    let recognizedText: [TextBlock]
    let processingTime: TimeInterval
    let overallConfidence: Float
    let imageSize: CGSize
    let detectedLanguages: [String]?
    let layoutAnalysis: LayoutAnalysisResult?
    
    init(recognizedText: [TextBlock], processingTime: TimeInterval, overallConfidence: Float, imageSize: CGSize, detectedLanguages: [String]? = nil, layoutAnalysis: LayoutAnalysisResult? = nil) {
        self.recognizedText = recognizedText
        self.processingTime = processingTime
        self.overallConfidence = overallConfidence
        self.imageSize = imageSize
        self.detectedLanguages = detectedLanguages
        self.layoutAnalysis = layoutAnalysis
    }
    
    struct TextBlock: Codable, Hashable, Equatable {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        let recognitionLevel: VNRequestTextRecognitionLevel
        let alternatives: [String]
        let textType: TextType?
        
        init(text: String, boundingBox: CGRect, confidence: Float, recognitionLevel: VNRequestTextRecognitionLevel, alternatives: [String] = [], textType: TextType? = nil) {
            self.text = text
            self.boundingBox = boundingBox
            self.confidence = confidence
            self.recognitionLevel = recognitionLevel
            self.alternatives = alternatives
            self.textType = textType
        }
        
        // Custom Codable implementation
        enum CodingKeys: String, CodingKey {
            case text, boundingBox, confidence, recognitionLevel, alternatives, textType
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encode(boundingBox, forKey: .boundingBox)
            try container.encode(confidence, forKey: .confidence)
            try container.encode(recognitionLevel.rawValue, forKey: .recognitionLevel)
            try container.encode(alternatives, forKey: .alternatives)
            try container.encode(textType, forKey: .textType)
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            boundingBox = try container.decode(CGRect.self, forKey: .boundingBox)
            confidence = try container.decode(Float.self, forKey: .confidence)
            let recognitionLevelValue = try container.decode(Int.self, forKey: .recognitionLevel)
            recognitionLevel = VNRequestTextRecognitionLevel(rawValue: recognitionLevelValue) ?? .fast
            alternatives = try container.decode([String].self, forKey: .alternatives)
            textType = try container.decodeIfPresent(TextType.self, forKey: .textType)
        }
        
        // Custom Hashable and Equatable implementation
        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(boundingBox)
            hasher.combine(confidence)
            hasher.combine(recognitionLevel.rawValue)
            hasher.combine(alternatives)
            hasher.combine(textType)
        }
        
        static func == (lhs: TextBlock, rhs: TextBlock) -> Bool {
            return lhs.text == rhs.text &&
                   lhs.boundingBox == rhs.boundingBox &&
                   lhs.confidence == rhs.confidence &&
                   lhs.recognitionLevel.rawValue == rhs.recognitionLevel.rawValue &&
                   lhs.alternatives == rhs.alternatives &&
                   lhs.textType == rhs.textType
        }
    }
}

// MARK: - OCR Supporting Types

enum TextType: String, CaseIterable, Codable {
    case dishName = "dish_name"
    case price = "price"
    case description = "description"
    case sectionHeader = "section_header"
    case other = "other"
}

enum TextAlignment: String, CaseIterable, Codable {
    case left = "left"
    case center = "center"
    case right = "right"
    case mixed = "mixed"
}

struct LayoutAnalysisResult: Codable, Hashable, Equatable {
    let detectedColumns: Int
    let menuSections: [MenuSection]
    let averageLineSpacing: CGFloat
    let textAlignment: TextAlignment
}

struct MenuSection: Codable, Hashable, Equatable {
    let header: String
    let boundingBox: CGRect
    var textBlocks: [OCRResult.TextBlock]
}

// MARK: - API Models

/// Request payload for Claude API (minimal data transfer)
struct VisualizationRequest: Codable {
    let dishName: String
    let description: String?
    let dietaryInfo: [String]
    let style: VisualizationStyle
    let requestId: String
    
    enum VisualizationStyle: String, Codable, CaseIterable {
        case realistic = "realistic"
        case artistic = "artistic"
        case minimalist = "minimalist"
        case appetizing = "appetizing"
    }
    
    init(dish: Dish, style: VisualizationStyle = .appetizing) {
        self.dishName = dish.name
        self.description = dish.description
        self.dietaryInfo = dish.dietaryInfo.map { $0.rawValue }
        self.style = style
        self.requestId = UUID().uuidString
    }
}

/// API response from Claude service
struct VisualizationResponse: Codable {
    let requestId: String
    let imageUrl: URL?
    let imageData: Data?
    let description: String?
    let processingTime: TimeInterval?
    let success: Bool
    let error: APIError?
    
    struct APIError: Codable, LocalizedError {
        let code: String
        let message: String
        let retryable: Bool
        
        var errorDescription: String? {
            return message
        }
    }
}

// MARK: - App State Models

/// Represents current app processing state
enum AppState: Equatable {
    case idle
    case onboarding
    case capturingPhoto
    case processing
    case processingOCR
    case extractingDishes
    case generatingVisualization(dishName: String)
    case displayingResults
    case viewing
    case error(MenulyError)
}

/// Processing state for pipeline operations
enum ProcessingState: Equatable {
    case idle
    case capturingPhoto
    case processingOCR
    case extractingDishes
    case parsingMenu
    case generatingVisualization(dishName: String)
    case completed
    case error(MenulyError)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .capturingPhoto:
            return "Capturing Photo"
        case .processingOCR:
            return "Processing Text"
        case .extractingDishes:
            return "Extracting Dishes"
        case .parsingMenu:
            return "Parsing Menu"
        case .generatingVisualization(let dishName):
            return "Generating visualization for \(dishName)"
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }
    
    var isProcessing: Bool {
        switch self {
        case .idle, .completed, .error:
            return false
        case .capturingPhoto, .processingOCR, .extractingDishes, .parsingMenu, .generatingVisualization:
            return true
        }
    }
}

/// Comprehensive error handling for all app operations
enum MenulyError: LocalizedError, Equatable, Hashable {
    // Camera Errors
    case cameraPermissionDenied
    case cameraUnavailable
    case photoCaptureFailed
    
    // OCR Errors
    case ocrProcessingFailed
    case noTextRecognized
    case lowConfidenceOCR(Float)
    
    // Parsing Errors
    case dishExtractionFailed
    case noDishesFound
    case invalidMenuFormat
    
    // API Errors
    case networkUnavailable
    case apiRequestFailed(String)
    case invalidAPIResponse
    case apiRateLimited
    case authenticationFailed
    case apiKeyMissing
    case apiError(String)
    case privacyViolation(String)
    
    // System Errors
    case insufficientMemory
    case processingTimeout
    case unknownError(String)
    case unknown(String)
    
    // Legacy error support
    case networkError(String)
    case jsonParsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera permission required to capture menu photos"
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .photoCaptureFailed:
            return "Failed to capture photo. Please try again"
        case .ocrProcessingFailed:
            return "Failed to process text from image"
        case .noTextRecognized:
            return "No text found in the image. Please ensure the menu is clearly visible"
        case .lowConfidenceOCR(let confidence):
            return "Low text recognition confidence (\(Int(confidence * 100))%). Please try a clearer photo"
        case .dishExtractionFailed:
            return "Failed to extract dish information from menu"
        case .noDishesFound:
            return "No dishes found in the menu. Please try a different photo"
        case .invalidMenuFormat:
            return "Menu format not recognized. Please try a different photo"
        case .networkUnavailable:
            return "Network connection required for visualization generation"
        case .apiRequestFailed(let message):
            return "Visualization service error: \(message)"
        case .invalidAPIResponse:
            return "Invalid response from visualization service"
        case .apiRateLimited:
            return "Too many requests. Please wait a moment and try again"
        case .authenticationFailed:
            return "Authentication failed. Please check your API configuration"
        case .apiKeyMissing:
            return "API key not configured. Please check your settings"
        case .apiError(let message):
            return "API error: \(message)"
        case .privacyViolation(let message):
            return "Privacy policy violation: \(message)"
        case .insufficientMemory:
            return "Insufficient memory. Please close other apps and try again"
        case .processingTimeout:
            return "Processing took too long. Please try again"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .jsonParsingError(let message):
            return "JSON parsing error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Enable camera access in Settings > Privacy & Security > Camera"
        case .noTextRecognized, .lowConfidenceOCR:
            return "Ensure good lighting and the menu text is clearly visible"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .apiRateLimited:
            return "Wait a few moments before trying again"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .cameraPermissionDenied, .cameraUnavailable:
            return false
        case .networkUnavailable, .apiRateLimited:
            return true
        case .noTextRecognized, .lowConfidenceOCR:
            return true
        case .authenticationFailed, .apiKeyMissing:
            return false
        default:
            return true
        }
    }
}

// MARK: - Privacy Compliance Models

/// Privacy settings and compliance tracking
struct PrivacySettings: Codable {
    var dataRetentionPolicy: DataRetentionPolicy
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    var enableBiometricProtection: Bool
    var enableScreenshotProtection: Bool
    var enableNetworkProtection: Bool
    var autoDeleteTemporaryFiles: Bool
    var requireConsentForAPI: Bool
    
    enum DataRetentionPolicy: String, CaseIterable, Codable {
        case sessionOnly = "Session Only"
        case never = "Never Store"
        
        var description: String {
            switch self {
            case .sessionOnly:
                return "Data is cleared when app closes"
            case .never:
                return "No data is stored on device"
            }
        }
    }
    
    static let `default` = PrivacySettings(
        dataRetentionPolicy: .sessionOnly,
        analyticsEnabled: false,
        crashReportingEnabled: false,
        enableBiometricProtection: false,
        enableScreenshotProtection: false,
        enableNetworkProtection: false,
        autoDeleteTemporaryFiles: true,
        requireConsentForAPI: true
    )
}

/// Consent categories for data processing
enum ConsentCategory: String, CaseIterable, Codable {
    case dataProcessing = "data_processing"
    case apiCommunication = "api_communication"
    case errorReporting = "error_reporting"
    case analytics = "analytics"
    case marketing = "marketing"
    case tracking = "tracking"
    
    var isEssential: Bool {
        switch self {
        case .dataProcessing, .apiCommunication:
            return true
        case .errorReporting, .analytics, .marketing, .tracking:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .dataProcessing:
            return "Menu Processing"
        case .apiCommunication:
            return "AI Visualization"
        case .errorReporting:
            return "Error Reporting"
        case .analytics:
            return "Analytics"
        case .marketing:
            return "Marketing"
        case .tracking:
            return "Tracking"
        }
    }
    
    var description: String {
        switch self {
        case .dataProcessing:
            return "Allow processing of menu photos to generate dish visualizations"
        case .apiCommunication:
            return "Allow communication with AI service to create visualizations"
        case .errorReporting:
            return "Allow anonymous error reporting to improve the app"
        case .analytics:
            return "Allow anonymous usage analytics (Not implemented in Menuly)"
        case .marketing:
            return "Allow marketing communications (Not applicable to Menuly)"
        case .tracking:
            return "Allow tracking across apps and websites (Not applicable to Menuly)"
        }
    }
}

// MARK: - Performance Monitoring

/// Performance metrics for optimization
struct PerformanceMetrics {
    let ocrProcessingTime: TimeInterval
    let dishExtractionTime: TimeInterval
    let apiRequestTime: TimeInterval
    let totalProcessingTime: TimeInterval
    let memoryUsage: UInt64
    let imageProcessingTime: TimeInterval
    
    var averageResponseTime: TimeInterval {
        return (ocrProcessingTime + dishExtractionTime + apiRequestTime) / 3
    }
}

// MARK: - Legacy Type Aliases

/// Legacy type alias for compatibility
typealias DishCategory = Dish.DishCategory

/// API response containing visualization data
struct VisualizationAPIResponse: Codable {
    let success: Bool
    let visualization: VisualizationData?
    let error: String?
    
    struct VisualizationData: Codable {
        let description: String
        let visualStyle: String
        let ingredients: [String]
        let preparationNotes: String
    }
}