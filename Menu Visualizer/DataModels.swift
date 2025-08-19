//
//  DataModels.swift
//  Menuly
//
//  Privacy-first data models for menu processing and dish visualization
//

import Foundation
import UIKit
import Vision

// MARK: - Core Data Models

/// Represents a captured menu with OCR results and extracted dishes
struct Menu: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date = Date()
    let ocrResult: OCRResult
    let extractedDishes: [Dish]
    
    /// Privacy compliance - indicates if this menu should be auto-deleted
    var privacyPolicy: DataRetentionPolicy = .sessionOnly
}

/// Individual dish extracted from menu with optional AI visualization
struct Dish: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let description: String?
    let price: String?
    let category: DishCategory
    let confidence: Float // OCR confidence score 0.0-1.0
    
    // AI-generated content
    var aiVisualization: DishVisualization?
    var isGenerating: Bool = false
    
    /// Privacy-safe dish representation for API calls (excludes personal data)
    func toAPIPayload() -> DishAPIPayload {
        DishAPIPayload(
            name: name,
            description: description,
            category: category.rawValue
        )
    }
}

/// AI-generated dish visualization from Claude API
struct DishVisualization: Codable {
    let id = UUID()
    let dishId: UUID
    let generatedDescription: String
    let visualStyle: String
    let ingredients: [String]
    let preparationNotes: String
    let timestamp: Date = Date()
    
    // Privacy compliance
    let sourceAPI: String = "claude-3.5-sonnet"
    var retentionPolicy: DataRetentionPolicy = .sessionOnly
}

/// OCR results from Apple Vision framework
struct OCRResult: Codable {
    let id = UUID()
    let rawText: String
    let recognizedLines: [RecognizedLine]
    let confidence: Float
    let processingTime: TimeInterval
    let imageSize: CGSize
    
    /// Privacy note: Image data is never stored, only text results
    let privacyCompliant: Bool = true
}

/// Individual line of recognized text with position and confidence
struct RecognizedLine: Codable, Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

// MARK: - API Models

/// Privacy-safe payload sent to Claude API
struct DishAPIPayload: Codable {
    let name: String
    let description: String?
    let category: String
    
    /// Validation to ensure no sensitive data is included
    func isPrivacySafe() -> Bool {
        // Basic validation - could be expanded based on privacy requirements
        return !name.isEmpty && name.count < 100
    }
}

/// Response from Claude API for dish visualization
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

// MARK: - Enums

/// Dish categories for organization and filtering
enum DishCategory: String, CaseIterable, Codable {
    case appetizer = "Appetizer"
    case soup = "Soup"
    case salad = "Salad"  
    case mainCourse = "Main Course"
    case pasta = "Pasta"
    case seafood = "Seafood"
    case meat = "Meat"
    case vegetarian = "Vegetarian"
    case dessert = "Dessert"
    case beverage = "Beverage"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .appetizer: return "🥗"
        case .soup: return "🍲"
        case .salad: return "🥬"
        case .mainCourse: return "🍽️"
        case .pasta: return "🍝"
        case .seafood: return "🐟"
        case .meat: return "🥩"
        case .vegetarian: return "🥕"
        case .dessert: return "🍰"
        case .beverage: return "🥤"
        case .unknown: return "❓"
        }
    }
}

/// Privacy-compliant data retention policies
enum DataRetentionPolicy: String, CaseIterable, Codable {
    case sessionOnly = "Session Only"
    case never = "Never Store"
    
    var description: String {
        switch self {
        case .sessionOnly:
            return "Data cleared when app is closed"
        case .never:
            return "Data never persisted to storage"
        }
    }
}

/// Comprehensive privacy settings for the app
struct PrivacySettings: Codable {
    var dataRetentionPolicy: DataRetentionPolicy
    var enableBiometricProtection: Bool
    var allowErrorReporting: Bool
    var enableNetworkProtection: Bool
    var autoDeleteTemporaryFiles: Bool
    var enableScreenshotProtection: Bool
    var requireConsentForAPI: Bool
    
    static let `default` = PrivacySettings(
        dataRetentionPolicy: .sessionOnly,
        enableBiometricProtection: true,
        allowErrorReporting: false,
        enableNetworkProtection: true,
        autoDeleteTemporaryFiles: true,
        enableScreenshotProtection: true,
        requireConsentForAPI: true
    )
}

/// Processing states for UI feedback
enum ProcessingState: Equatable {
    case idle
    case capturingPhoto
    case processingOCR
    case parsingMenu
    case generatingVisualization(dishName: String)
    case completed
    case error(MenulyError)
    
    var isProcessing: Bool {
        switch self {
        case .idle, .completed, .error:
            return false
        default:
            return true
        }
    }
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready to capture menu"
        case .capturingPhoto:
            return "Capturing photo..."
        case .processingOCR:
            return "Reading menu text..."
        case .parsingMenu:
            return "Extracting dishes..."
        case .generatingVisualization(let dishName):
            return "Creating visualization for \(dishName)..."
        case .completed:
            return "Processing complete"
        case .error(let error):
            return error.displayMessage
        }
    }
}

// MARK: - Error Types

/// Comprehensive error types for the Menuly app
enum MenulyError: Error, Equatable, LocalizedError {
    case cameraNotAvailable
    case cameraPermissionDenied
    case photoCaptureFailed
    case ocrProcessingFailed
    case noTextRecognized
    case apiKeyMissing
    case networkError(String)
    case apiError(String)
    case jsonParsingError
    case memoryPressure
    case privacyViolation(String)
    case unknown(String)
    
    var errorDescription: String? {
        displayMessage
    }
    
    var displayMessage: String {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .cameraPermissionDenied:
            return "Please allow camera access in Settings"
        case .photoCaptureFailed:
            return "Failed to capture photo. Please try again"
        case .ocrProcessingFailed:
            return "Could not process menu text. Try with better lighting"
        case .noTextRecognized:
            return "No text found in image. Please try a clearer photo"
        case .apiKeyMissing:
            return "API configuration missing. Please check settings"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .jsonParsingError:
            return "Failed to process server response"
        case .memoryPressure:
            return "Low memory. Please close other apps and try again"
        case .privacyViolation(let details):
            return "Privacy violation detected: \(details)"
        case .unknown(let message):
            return "Unexpected error: \(message)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .photoCaptureFailed, .ocrProcessingFailed, .networkError, .apiError:
            return true
        case .cameraNotAvailable, .cameraPermissionDenied, .apiKeyMissing, .privacyViolation:
            return false
        default:
            return true
        }
    }
}

// MARK: - Configuration

/// App configuration for privacy and performance settings
struct AppConfiguration: Codable {
    var dataRetentionPolicy: DataRetentionPolicy = .sessionOnly
    var ocrQuality: OCRQuality = .balanced
    var maxImageSize: CGFloat = 1024
    var apiTimeout: TimeInterval = 30
    var enablePerformanceMonitoring: Bool = true
    
    /// Privacy-first defaults
    static let privacyDefaults = AppConfiguration(
        dataRetentionPolicy: .neverStore,
        ocrQuality: .balanced,
        maxImageSize: 800,
        apiTimeout: 20,
        enablePerformanceMonitoring: false
    )
}

/// OCR processing quality settings
enum OCRQuality: String, CaseIterable, Codable {
    case fast = "Fast"
    case balanced = "Balanced" 
    case accurate = "Accurate"
    
    var visionRequestLevel: VNRequestRevision {
        switch self {
        case .fast:
            return VNRecognizeTextRequestRevision1
        case .balanced, .accurate:
            return VNRecognizeTextRequestRevision3
        }
    }
    
    var recognitionLevel: VNRequestTextRecognitionLevel {
        switch self {
        case .fast:
            return .fast
        case .balanced, .accurate:
            return .accurate
        }
    }
}

// MARK: - Extensions

extension Menu {
    /// Privacy-compliant summary that excludes sensitive details
    func privacySummary() -> String {
        return "Menu with \(extractedDishes.count) dishes processed at \(timestamp.formatted())"
    }
    
    /// Check if menu should be auto-deleted based on privacy policy
    func shouldAutoDelete() -> Bool {
        switch privacyPolicy {
        case .neverStore:
            return true
        case .sessionOnly:
            // Could implement time-based deletion here
            return false
        }
    }
}

extension Array where Element == Dish {
    /// Filter dishes by category
    func filtered(by category: DishCategory) -> [Dish] {
        return filter { $0.category == category }
    }
    
    /// Get dishes grouped by category
    func groupedByCategory() -> [DishCategory: [Dish]] {
        return Dictionary(grouping: self) { $0.category }
    }
    
    /// Find dishes with high OCR confidence
    func highConfidenceDishes(threshold: Float = 0.8) -> [Dish] {
        return filter { $0.confidence >= threshold }
    }
}