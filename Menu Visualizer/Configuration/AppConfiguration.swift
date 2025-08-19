//
//  AppConfiguration.swift
//  Menu Visualizer
//
//  App-wide configuration settings for Menuly
//

import Foundation
import SwiftUI

/// Central configuration for app settings and preferences
struct AppConfiguration {
    
    // MARK: - OCR Configuration
    
    enum OCRQuality: String, CaseIterable, Identifiable {
        case fast = "Fast"
        case balanced = "Balanced"
        case accurate = "Accurate"
        case maximum = "Maximum"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .fast:
                return "Quick processing, good for previews"
            case .balanced:
                return "Good balance of speed and accuracy"
            case .accurate:
                return "High accuracy, slower processing"
            case .maximum:
                return "Maximum accuracy, slowest processing"
            }
        }
        
        var estimatedProcessingTime: String {
            switch self {
            case .fast:
                return "1-2 seconds"
            case .balanced:
                return "2-4 seconds"
            case .accurate:
                return "4-6 seconds"
            case .maximum:
                return "6-10 seconds"
            }
        }
    }
    
    // MARK: - Processing Configuration
    
    enum ProcessingPriority: String, CaseIterable {
        case speed = "Speed"
        case quality = "Quality"
        case balanced = "Balanced"
        
        var ocrQuality: OCRQuality {
            switch self {
            case .speed: return .fast
            case .quality: return .maximum
            case .balanced: return .balanced
            }
        }
        
        var parsingConfiguration: MenuParsingService.ParsingConfiguration {
            switch self {
            case .speed: return .fast
            case .quality: return .comprehensive
            case .balanced: return .default
            }
        }
    }
    
    // MARK: - Language Configuration
    
    enum SupportedLanguage: String, CaseIterable, Identifiable {
        case english = "en-US"
        case spanish = "es-ES"
        case french = "fr-FR"
        case german = "de-DE"
        case italian = "it-IT"
        case japanese = "ja-JP"
        case chinese = "zh-CN"
        case portuguese = "pt-PT"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            case .italian: return "Italiano"
            case .japanese: return "日本語"
            case .chinese: return "中文"
            case .portuguese: return "Português"
            }
        }
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .spanish: return "🇪🇸"
            case .french: return "🇫🇷"
            case .german: return "🇩🇪"
            case .italian: return "🇮🇹"
            case .japanese: return "🇯🇵"
            case .chinese: return "🇨🇳"
            case .portuguese: return "🇵🇹"
            }
        }
    }
    
    // MARK: - Default Settings
    
    static let shared = AppConfiguration()
    
    // OCR Settings
    let defaultOCRQuality: OCRQuality = .balanced
    let defaultLanguages: [SupportedLanguage] = [.english]
    let enableMultiLanguageDetection: Bool = true
    let enableLayoutAnalysis: Bool = true
    let enableAdvancedPricing: Bool = true
    
    // Performance Settings
    let defaultProcessingPriority: ProcessingPriority = .balanced
    let enableImagePreprocessing: Bool = true
    let enableBackgroundProcessing: Bool = true
    let maxConcurrentOperations: Int = 3
    
    // Quality Thresholds
    let minimumOCRConfidence: Float = 0.3
    let minimumDishConfidence: Float = 0.4
    let imageQualityThreshold: Float = 0.6
    let enableQualityValidation: Bool = true
    
    // Memory Management
    let maxImageSize: CGSize = CGSize(width: 2048, height: 2048)
    let enableMemoryOptimization: Bool = true
    let enableResultCaching: Bool = true
    let cacheMaxAge: TimeInterval = 3600 // 1 hour
    
    // Privacy Settings
    let dataRetentionPolicy: PrivacySettings.DataRetentionPolicy = .sessionOnly
    let enableAnalytics: Bool = false
    let enableCrashReporting: Bool = false
    let enableImageMetadataStripping: Bool = true
    
    // Feature Flags
    let enableExperimentalFeatures: Bool = false
    let enableBetaOCRFeatures: Bool = false
    let enableAdvancedDietaryAnalysis: Bool = true
    let enableRestaurantInfoExtraction: Bool = true
    
    // MARK: - Dynamic Configuration
    
    /// Get OCR configuration for current app settings
    func getOCRConfiguration() -> OCRService.OCRConfiguration {
        return OCRService.OCRConfiguration(
            quality: defaultOCRQuality,
            languages: defaultLanguages.map { $0.rawValue },
            enableLayoutAnalysis: enableLayoutAnalysis,
            enableRegionDetection: true,
            minimumConfidence: minimumOCRConfidence,
            maxProcessingTime: getMaxProcessingTime()
        )
    }
    
    /// Get parsing configuration for current app settings
    func getParsingConfiguration() -> MenuParsingService.ParsingConfiguration {
        return MenuParsingService.ParsingConfiguration(
            enableAdvancedPricing: enableAdvancedPricing,
            enableCategoryDetection: true,
            enableDietaryAnalysis: enableAdvancedDietaryAnalysis,
            minimumDishConfidence: minimumDishConfidence,
            mergeSimilarDishes: true,
            enableLayoutAwareness: enableLayoutAnalysis
        )
    }
    
    /// Get image preprocessing configuration
    func getImagePreprocessingConfiguration() -> ImagePreprocessor.ProcessingConfiguration {
        switch defaultProcessingPriority {
        case .speed:
            return .performance
        case .quality:
            return .highQuality
        case .balanced:
            return .default
        }
    }
    
    private func getMaxProcessingTime() -> TimeInterval {
        switch defaultOCRQuality {
        case .fast: return 15.0
        case .balanced: return 30.0
        case .accurate: return 45.0
        case .maximum: return 60.0
        }
    }
}

// MARK: - User Preferences

/// User-configurable settings that can be changed in the app
@Observable
class UserPreferences {
    static let shared = UserPreferences()
    
    // OCR Preferences
    @UserDefault("ocrQuality", defaultValue: AppConfiguration.OCRQuality.balanced)
    var ocrQuality: AppConfiguration.OCRQuality
    
    @UserDefault("selectedLanguages", defaultValue: [AppConfiguration.SupportedLanguage.english])
    var selectedLanguages: [AppConfiguration.SupportedLanguage]
    
    @UserDefault("processingPriority", defaultValue: AppConfiguration.ProcessingPriority.balanced)
    var processingPriority: AppConfiguration.ProcessingPriority
    
    // Feature Preferences
    @UserDefault("enableLayoutAnalysis", defaultValue: true)
    var enableLayoutAnalysis: Bool
    
    @UserDefault("enableAdvancedPricing", defaultValue: true)
    var enableAdvancedPricing: Bool
    
    @UserDefault("enableDietaryAnalysis", defaultValue: true)
    var enableDietaryAnalysis: Bool
    
    @UserDefault("enableAutoLanguageDetection", defaultValue: true)
    var enableAutoLanguageDetection: Bool
    
    // Privacy Preferences
    @UserDefault("dataRetentionPolicy", defaultValue: PrivacySettings.DataRetentionPolicy.sessionOnly)
    var dataRetentionPolicy: PrivacySettings.DataRetentionPolicy
    
    @UserDefault("enableAnalytics", defaultValue: false)
    var enableAnalytics: Bool
    
    // Performance Preferences
    @UserDefault("enableImagePreprocessing", defaultValue: true)
    var enableImagePreprocessing: Bool
    
    @UserDefault("enableBackgroundProcessing", defaultValue: true)
    var enableBackgroundProcessing: Bool
    
    private init() {}
    
    // MARK: - Configuration Generation
    
    /// Generate OCR configuration from user preferences
    func createOCRConfiguration() -> OCRService.OCRConfiguration {
        return OCRService.OCRConfiguration(
            quality: ocrQuality,
            languages: selectedLanguages.map { $0.rawValue },
            enableLayoutAnalysis: enableLayoutAnalysis,
            enableRegionDetection: true,
            minimumConfidence: AppConfiguration.shared.minimumOCRConfidence,
            maxProcessingTime: getProcessingTimeout()
        )
    }
    
    /// Generate parsing configuration from user preferences
    func createParsingConfiguration() -> MenuParsingService.ParsingConfiguration {
        return MenuParsingService.ParsingConfiguration(
            enableAdvancedPricing: enableAdvancedPricing,
            enableCategoryDetection: true,
            enableDietaryAnalysis: enableDietaryAnalysis,
            minimumDishConfidence: AppConfiguration.shared.minimumDishConfidence,
            mergeSimilarDishes: true,
            enableLayoutAwareness: enableLayoutAnalysis
        )
    }
    
    private func getProcessingTimeout() -> TimeInterval {
        switch processingPriority {
        case .speed: return 15.0
        case .balanced: return 30.0
        case .quality: return 60.0
        }
    }
}

// MARK: - UserDefault Property Wrapper

@propertyWrapper
struct UserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return defaultValue
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Failed to decode UserDefault for key '\(key)': \(error)")
                return defaultValue
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                UserDefaults.standard.set(data, forKey: key)
            } catch {
                print("Failed to encode UserDefault for key '\(key)': \(error)")
            }
        }
    }
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
}