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
struct Menu: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let dishes: [Dish]
    let restaurantName: String?
    let ocrConfidence: Float
    
    init(dishes: [Dish], restaurantName: String? = nil, ocrConfidence: Float = 0.0) {
        self.timestamp = Date()
        self.dishes = dishes
        self.restaurantName = restaurantName
        self.ocrConfidence = ocrConfidence
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
    
    enum DishCategory: String, CaseIterable, Codable {
        case appetizer = "Appetizer"
        case mainCourse = "Main Course"
        case dessert = "Dessert"
        case beverage = "Beverage"
        case special = "Special"
        case unknown = "Unknown"
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
         dietaryInfo: [DietaryInfo] = [], extractionConfidence: Float = 0.0) {
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.allergens = allergens
        self.dietaryInfo = dietaryInfo
        self.extractionConfidence = extractionConfidence
    }
}

// MARK: - OCR Result Models

/// Contains OCR processing results with confidence metrics and layout analysis
struct OCRResult {
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
    
    struct TextBlock {
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
    }
}

// MARK: - OCR Supporting Types

enum TextType: String, CaseIterable {
    case dishName = "dish_name"
    case price = "price"
    case description = "description"
    case sectionHeader = "section_header"
    case other = "other"
}

enum TextAlignment: String, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
    case mixed = "mixed"
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
    case capturingPhoto
    case processingOCR
    case extractingDishes
    case generatingVisualization(dishName: String)
    case displayingResults
    case error(MenulyError)
}

/// Comprehensive error handling for all app operations
enum MenulyError: LocalizedError, Equatable {
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
    
    // System Errors
    case insufficientMemory
    case processingTimeout
    case unknownError(String)
    
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
        case .insufficientMemory:
            return "Insufficient memory. Please close other apps and try again"
        case .processingTimeout:
            return "Processing took too long. Please try again"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
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
}

// MARK: - Privacy Compliance Models

/// Privacy settings and compliance tracking
struct PrivacySettings {
    var dataRetentionPolicy: DataRetentionPolicy
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    
    enum DataRetentionPolicy: String, CaseIterable {
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
        crashReportingEnabled: false
    )
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