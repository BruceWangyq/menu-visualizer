//
//  AppConfiguration.swift
//  Menu Visualizer
//
//  App-wide configuration settings for AI-powered menu analysis
//

import Foundation
import SwiftUI
import Combine

/// Central configuration for AI-powered menu analysis settings
struct AppConfiguration {
    
    // MARK: - AI Processing Configuration
    
    enum AIProcessingQuality: String, CaseIterable, Identifiable, Codable {
        case fast = "Fast"
        case balanced = "Balanced"
        case highQuality = "HighQuality"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .fast:
                return "Quick AI analysis, good for simple menus"
            case .balanced:
                return "Balanced speed and accuracy"
            case .highQuality:
                return "Maximum accuracy with detailed analysis"
            }
        }
        
        var estimatedProcessingTime: String {
            switch self {
            case .fast:
                return "3-5 seconds"
            case .balanced:
                return "5-8 seconds"
            case .highQuality:
                return "8-12 seconds"
            }
        }
        
        var aiConfiguration: AIMenuAnalysisService.AnalysisConfiguration {
            switch self {
            case .fast:
                return .fast
            case .balanced:
                return .default
            case .highQuality:
                return .highQuality
            }
        }
    }
    
    // MARK: - Processing Configuration
    
    enum ProcessingPriority: String, CaseIterable, Codable {
        case speed = "Speed"
        case quality = "Quality"
        case balanced = "Balanced"
        
        var aiQuality: AIProcessingQuality {
            switch self {
            case .speed: return .fast
            case .quality: return .highQuality
            case .balanced: return .balanced
            }
        }
    }
    
    // MARK: - Language Configuration
    
    enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
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
    
    // AI Processing Settings
    let defaultAIQuality: AIProcessingQuality = .balanced
    let defaultLanguages: [SupportedLanguage] = [.english]
    let enableMultiLanguageDetection: Bool = true
    let enableDetailedAnalysis: Bool = true
    let enableAdvancedPricing: Bool = true
    
    // Performance Settings
    let defaultProcessingPriority: ProcessingPriority = .balanced
    let enableImagePreprocessing: Bool = true
    let enableBackgroundProcessing: Bool = true
    let maxConcurrentOperations: Int = 3
    
    // Quality Thresholds
    let minimumAIConfidence: Float = 0.7
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
    let enableAdvancedDietaryAnalysis: Bool = true
    let enableRestaurantInfoExtraction: Bool = true
    let enableFirebaseAI: Bool = true
    
    // MARK: - Dynamic Configuration
    
    /// Get AI configuration for current app settings
    func getAIConfiguration() -> AIMenuAnalysisService.AnalysisConfiguration {
        return defaultAIQuality.aiConfiguration
    }
    
    /// Get processing configuration based on priority
    func getProcessingConfiguration(priority: ProcessingPriority) -> AIMenuAnalysisService.AnalysisConfiguration {
        return priority.aiQuality.aiConfiguration
    }
    
    private func getMaxProcessingTime() -> TimeInterval {
        switch defaultAIQuality {
        case .fast: return 15.0
        case .balanced: return 30.0
        case .highQuality: return 45.0
        }
    }
}

// MARK: - User Preferences

/// User-configurable settings that can be changed in the app
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    // AI Preferences
    @Published var aiQuality: AppConfiguration.AIProcessingQuality = .balanced
    @Published var selectedLanguages: [AppConfiguration.SupportedLanguage] = [.english]
    @Published var processingPriority: AppConfiguration.ProcessingPriority = .balanced
    
    // Feature Preferences
    @Published var enableDetailedAnalysis: Bool = true
    @Published var enableAdvancedPricing: Bool = true
    @Published var enableDietaryAnalysis: Bool = true
    @Published var enableAutoLanguageDetection: Bool = true
    
    // Privacy Preferences
    @Published var dataRetentionPolicy: PrivacySettings.DataRetentionPolicy = .sessionOnly
    @Published var enableAnalytics: Bool = false
    
    // Performance Preferences
    @Published var enableImagePreprocessing: Bool = true
    @Published var enableBackgroundProcessing: Bool = true
    
    private init() {
        loadUserDefaults()
    }
    
    private func loadUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: "aiQuality"),
           let decoded = try? JSONDecoder().decode(AppConfiguration.AIProcessingQuality.self, from: data) {
            aiQuality = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "selectedLanguages"),
           let decoded = try? JSONDecoder().decode([AppConfiguration.SupportedLanguage].self, from: data) {
            selectedLanguages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "processingPriority"),
           let decoded = try? JSONDecoder().decode(AppConfiguration.ProcessingPriority.self, from: data) {
            processingPriority = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "dataRetentionPolicy"),
           let decoded = try? JSONDecoder().decode(PrivacySettings.DataRetentionPolicy.self, from: data) {
            dataRetentionPolicy = decoded
        }
        
        enableDetailedAnalysis = UserDefaults.standard.bool(forKey: "enableDetailedAnalysis")
        enableAdvancedPricing = UserDefaults.standard.bool(forKey: "enableAdvancedPricing")
        enableDietaryAnalysis = UserDefaults.standard.bool(forKey: "enableDietaryAnalysis")
        enableAutoLanguageDetection = UserDefaults.standard.bool(forKey: "enableAutoLanguageDetection")
        enableAnalytics = UserDefaults.standard.bool(forKey: "enableAnalytics")
        enableImagePreprocessing = UserDefaults.standard.bool(forKey: "enableImagePreprocessing")
        enableBackgroundProcessing = UserDefaults.standard.bool(forKey: "enableBackgroundProcessing")
    }
    
    func saveUserDefaults() {
        if let data = try? JSONEncoder().encode(aiQuality) {
            UserDefaults.standard.set(data, forKey: "aiQuality")
        }
        if let data = try? JSONEncoder().encode(selectedLanguages) {
            UserDefaults.standard.set(data, forKey: "selectedLanguages")
        }
        if let data = try? JSONEncoder().encode(processingPriority) {
            UserDefaults.standard.set(data, forKey: "processingPriority")
        }
        if let data = try? JSONEncoder().encode(dataRetentionPolicy) {
            UserDefaults.standard.set(data, forKey: "dataRetentionPolicy")
        }
        
        UserDefaults.standard.set(enableDetailedAnalysis, forKey: "enableDetailedAnalysis")
        UserDefaults.standard.set(enableAdvancedPricing, forKey: "enableAdvancedPricing")
        UserDefaults.standard.set(enableDietaryAnalysis, forKey: "enableDietaryAnalysis")
        UserDefaults.standard.set(enableAutoLanguageDetection, forKey: "enableAutoLanguageDetection")
        UserDefaults.standard.set(enableAnalytics, forKey: "enableAnalytics")
        UserDefaults.standard.set(enableImagePreprocessing, forKey: "enableImagePreprocessing")
        UserDefaults.standard.set(enableBackgroundProcessing, forKey: "enableBackgroundProcessing")
    }
    
    // MARK: - Configuration Generation
    
    /// Generate AI configuration from user preferences
    func createAIConfiguration() -> AIMenuAnalysisService.AnalysisConfiguration {
        return aiQuality.aiConfiguration
    }
    
    /// Get processing priority-based AI configuration
    func getAIConfigurationForPriority() -> AIMenuAnalysisService.AnalysisConfiguration {
        return processingPriority.aiQuality.aiConfiguration
    }
    
    private func getProcessingTimeout() -> TimeInterval {
        switch processingPriority {
        case .speed: return 15.0
        case .balanced: return 30.0
        case .quality: return 60.0
        }
    }
}

// UserDefault property wrapper removed - using @Published properties with manual UserDefaults persistence