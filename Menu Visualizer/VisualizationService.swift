//
//  VisualizationService.swift
//  Menuly
//
//  Core service for Claude API integration with comprehensive state management
//  Orchestrates secure API communication and data processing pipeline
//

import Foundation
import Combine

/// Main service orchestrating dish visualization generation with Claude API
/// Implements privacy-first design, comprehensive error handling, and state management
@MainActor
class VisualizationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var processingState: ProcessingState = .idle
    @Published var generationProgress: [UUID: Float] = [:]
    @Published var isOnline: Bool = true
    
    // MARK: - Private Properties
    
    private let apiClient: ClaudeAPIClient
    private let networkManager: NetworkSecurityManager
    private let apiKeyManager: APIKeyManager
    private let configuration: AppConfiguration
    
    // Cache for generated visualizations (session-only)
    private var visualizationCache: [String: DishVisualization] = [:]
    
    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.menuly.visualization", qos: .userInitiated)
    
    // Cancellables for Combine publishers
    private var cancellables = Set<AnyCancellable>()
    
    // Performance metrics
    private var performanceMetrics: VisualizationMetrics = VisualizationMetrics()
    
    // MARK: - Initialization
    
    init(
        apiClient: ClaudeAPIClient = ClaudeAPIClient(),
        networkManager: NetworkSecurityManager = .shared,
        apiKeyManager: APIKeyManager = .shared,
        configuration: AppConfiguration = AppConfiguration()
    ) {
        self.apiClient = apiClient
        self.networkManager = networkManager
        self.apiKeyManager = apiKeyManager
        self.configuration = configuration
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Generate visualization for a single dish
    /// - Parameter dish: The dish to generate visualization for
    /// - Returns: Updated dish with visualization or error
    func generateVisualization(for dish: Dish) async -> Result<Dish, MenulyError> {
        // Update processing state
        processingState = .generatingVisualization(dishName: dish.name)
        generationProgress[dish.id] = 0.0
        
        // Validate prerequisites
        guard validatePrerequisites() else {
            let error = MenulyError.apiKeyMissing
            processingState = .error(error)
            return .failure(error)
        }
        
        // Check cache first (privacy-compliant session cache)
        let cacheKey = createCacheKey(for: dish)
        if let cachedVisualization = visualizationCache[cacheKey],
           configuration.dataRetentionPolicy == .sessionOnly {
            
            var updatedDish = dish
            updatedDish.aiVisualization = cachedVisualization
            updatedDish.isGenerating = false
            
            processingState = .completed
            generationProgress[dish.id] = 1.0
            
            return .success(updatedDish)
        }
        
        // Update progress
        generationProgress[dish.id] = 0.3
        
        // Create privacy-safe payload
        let payload = dish.toAPIPayload()
        
        // Record start time for metrics
        let startTime = Date()
        
        // Generate visualization
        let result = await generateVisualizationInternal(payload: payload, originalDish: dish)
        
        // Record metrics
        recordMetrics(startTime: startTime, result: result)
        
        // Update progress and state
        switch result {
        case .success(let updatedDish):
            generationProgress[dish.id] = 1.0
            processingState = .completed
            
            // Cache result if allowed
            if let visualization = updatedDish.aiVisualization {
                cacheVisualization(visualization, for: cacheKey)
            }
            
            return .success(updatedDish)
            
        case .failure(let error):
            generationProgress.removeValue(forKey: dish.id)
            processingState = .error(error)
            return .failure(error)
        }
    }
    
    /// Generate visualizations for multiple dishes with concurrent processing
    /// - Parameter dishes: Array of dishes to process
    /// - Returns: Array of results for each dish
    func generateVisualizations(for dishes: [Dish]) async -> [Result<Dish, MenulyError>] {
        // Validate prerequisites
        guard validatePrerequisites() else {
            let error = MenulyError.apiKeyMissing
            processingState = .error(error)
            return dishes.map { _ in .failure(error) }
        }
        
        // Process dishes concurrently with rate limiting
        let results = await withTaskGroup(of: (Int, Result<Dish, MenulyError>).self) { group in
            var results: [(Int, Result<Dish, MenulyError>)] = []
            
            for (index, dish) in dishes.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else {
                        return (index, .failure(.unknown("Service unavailable")))
                    }
                    
                    // Add small delay to respect rate limits
                    if index > 0 {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    }
                    
                    let result = await self.generateVisualization(for: dish)
                    return (index, result)
                }
            }
            
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        
        // Sort results by original index and return values only
        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
    
    /// Validate API connectivity and configuration
    /// - Returns: Result indicating validation status
    func validateConfiguration() async -> Result<Bool, MenulyError> {
        processingState = .processingOCR // Reusing state for validation
        
        let result = await apiClient.validateConnectivity()
        
        switch result {
        case .success:
            processingState = .completed
        case .failure(let error):
            processingState = .error(error)
        }
        
        return result
    }
    
    /// Clear session cache and reset state
    func clearSession() {
        visualizationCache.removeAll()
        generationProgress.removeAll()
        processingState = .idle
        performanceMetrics = VisualizationMetrics()
    }
    
    /// Get service status for diagnostics
    /// - Returns: Dictionary with service status information
    func getServiceStatus() -> [String: Any] {
        return [
            "processingState": processingState.displayText,
            "isOnline": isOnline,
            "hasValidAPIKey": apiKeyManager.hasValidAPIKey(),
            "cacheSize": visualizationCache.count,
            "activeGenerations": generationProgress.count,
            "metrics": performanceMetrics.toDictionary(),
            "configuration": [
                "retentionPolicy": configuration.dataRetentionPolicy.rawValue,
                "timeout": configuration.apiTimeout
            ]
        ]
    }
    
    // MARK: - Private Implementation
    
    /// Internal visualization generation with comprehensive error handling
    /// - Parameters:
    ///   - payload: Privacy-safe dish payload
    ///   - originalDish: Original dish for context
    /// - Returns: Updated dish or error
    private func generateVisualizationInternal(payload: DishAPIPayload, originalDish: Dish) async -> Result<Dish, MenulyError> {
        do {
            // Update progress
            generationProgress[originalDish.id] = 0.5
            
            // Generate visualization via API
            let apiResult = await apiClient.generateVisualization(for: payload)
            
            switch apiResult {
            case .success(let response):
                // Update progress
                generationProgress[originalDish.id] = 0.8
                
                // Process successful response
                return processSuccessfulResponse(response, originalDish: originalDish)
                
            case .failure(let error):
                return .failure(error)
            }
            
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }
    
    /// Process successful API response
    /// - Parameters:
    ///   - response: API response
    ///   - originalDish: Original dish for context
    /// - Returns: Updated dish or error
    private func processSuccessfulResponse(_ response: VisualizationAPIResponse, originalDish: Dish) -> Result<Dish, MenulyError> {
        guard response.success, let visualizationData = response.visualization else {
            let errorMessage = response.error ?? "Unknown API error"
            return .failure(.apiError(errorMessage))
        }
        
        // Create DishVisualization from response
        let visualization = DishVisualization(
            dishId: originalDish.id,
            generatedDescription: visualizationData.description,
            visualStyle: visualizationData.visualStyle,
            ingredients: visualizationData.ingredients,
            preparationNotes: visualizationData.preparationNotes,
            retentionPolicy: configuration.dataRetentionPolicy
        )
        
        // Validate visualization content
        guard validateVisualizationContent(visualization) else {
            return .failure(.privacyViolation("Generated content failed validation"))
        }
        
        // Update dish with visualization
        var updatedDish = originalDish
        updatedDish.aiVisualization = visualization
        updatedDish.isGenerating = false
        
        return .success(updatedDish)
    }
    
    /// Validate generated visualization content
    /// - Parameter visualization: Visualization to validate
    /// - Returns: True if content is valid and safe
    private func validateVisualizationContent(_ visualization: DishVisualization) -> Bool {
        // Check content length limits
        guard visualization.generatedDescription.count <= 1000,
              visualization.visualStyle.count <= 500,
              visualization.preparationNotes.count <= 500,
              visualization.ingredients.count <= 20 else {
            return false
        }
        
        // Validate ingredients list
        for ingredient in visualization.ingredients {
            guard ingredient.count <= 50 else { return false }
        }
        
        // Additional content validation could be added here
        
        return true
    }
    
    /// Validate prerequisites for API calls
    /// - Returns: True if all prerequisites are met
    private func validatePrerequisites() -> Bool {
        guard apiKeyManager.hasValidAPIKey() else { return false }
        guard isOnline else { return false }
        
        return true
    }
    
    /// Create cache key for visualization
    /// - Parameter dish: Dish to create key for
    /// - Returns: Cache key string
    private func createCacheKey(for dish: Dish) -> String {
        let content = "\(dish.name)|\(dish.category.rawValue)|\(dish.description ?? "")"
        return content.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
    }
    
    /// Cache visualization (session only)
    /// - Parameters:
    ///   - visualization: Visualization to cache
    ///   - key: Cache key
    private func cacheVisualization(_ visualization: DishVisualization, for key: String) {
        guard configuration.dataRetentionPolicy == .sessionOnly else { return }
        
        // Limit cache size to prevent memory issues
        if visualizationCache.count >= 50 {
            // Remove oldest entries
            let sortedKeys = visualizationCache.keys.sorted { key1, key2 in
                let vis1 = visualizationCache[key1]!
                let vis2 = visualizationCache[key2]!
                return vis1.timestamp < vis2.timestamp
            }
            
            // Remove oldest 20%
            let removeCount = max(1, sortedKeys.count / 5)
            for i in 0..<removeCount {
                visualizationCache.removeValue(forKey: sortedKeys[i])
            }
        }
        
        visualizationCache[key] = visualization
    }
    
    /// Setup network monitoring
    private func setupNetworkMonitoring() {
        // Monitor network connectivity (simplified implementation)
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)
    }
    
    /// Check network status
    private func checkNetworkStatus() {
        // Simplified network check - in production, would use NWPathMonitor
        isOnline = true
    }
    
    /// Record performance metrics
    /// - Parameters:
    ///   - startTime: Request start time
    ///   - result: Request result
    private func recordMetrics(startTime: Date, result: Result<Dish, MenulyError>) {
        let duration = Date().timeIntervalSince(startTime)
        
        performanceMetrics.totalRequests += 1
        performanceMetrics.totalDuration += duration
        
        switch result {
        case .success:
            performanceMetrics.successfulRequests += 1
        case .failure:
            performanceMetrics.failedRequests += 1
        }
        
        performanceMetrics.averageDuration = performanceMetrics.totalDuration / Double(performanceMetrics.totalRequests)
    }
}

// MARK: - Performance Metrics

/// Performance metrics for visualization service
private struct VisualizationMetrics {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var totalDuration: TimeInterval = 0
    var averageDuration: TimeInterval = 0
    
    func toDictionary() -> [String: Any] {
        return [
            "totalRequests": totalRequests,
            "successfulRequests": successfulRequests,
            "failedRequests": failedRequests,
            "averageDuration": averageDuration,
            "successRate": totalRequests > 0 ? Double(successfulRequests) / Double(totalRequests) : 0.0
        ]
    }
}

// MARK: - Privacy Compliance Extensions

extension VisualizationService {
    
    /// Get privacy-compliant service status
    /// - Returns: Privacy-safe status information
    func getPrivacyCompliantStatus() -> [String: Any] {
        return [
            "isConfigured": apiKeyManager.hasValidAPIKey(),
            "isOnline": isOnline,
            "cachePolicy": configuration.dataRetentionPolicy.rawValue,
            "activeProcesses": generationProgress.count,
            "performanceMetrics": [
                "totalRequests": performanceMetrics.totalRequests,
                "successRate": performanceMetrics.totalRequests > 0 ? 
                    Double(performanceMetrics.successfulRequests) / Double(performanceMetrics.totalRequests) : 0.0
            ]
        ]
    }
    
    /// Create audit log entry for service operations
    /// - Parameter operation: The operation performed
    /// - Returns: Privacy-safe audit log entry
    func createAuditLogEntry(for operation: String) -> [String: Any] {
        return [
            "timestamp": Date().timeIntervalSince1970,
            "operation": operation,
            "service": "VisualizationService",
            "configuration": configuration.dataRetentionPolicy.rawValue,
            "version": "1.0"
        ]
    }
}

// MARK: - Testing Support

#if DEBUG
extension VisualizationService {
    
    /// Create test service with mock dependencies
    /// - Returns: Test-configured service
    static func createTestService() -> VisualizationService {
        let testConfig = AppConfiguration.privacyDefaults
        return VisualizationService(configuration: testConfig)
    }
    
    /// Generate test visualization for development
    /// - Parameter dish: Dish to create test visualization for
    /// - Returns: Mock visualization result
    func generateTestVisualization(for dish: Dish) async -> Result<Dish, MenulyError> {
        // Simulate processing delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let testVisualization = DishVisualization(
            dishId: dish.id,
            generatedDescription: "A beautifully crafted \(dish.name) that showcases expert culinary technique and artistic presentation.",
            visualStyle: "Modern plating with vibrant colors and thoughtful garnish placement",
            ingredients: ["premium ingredients", "fresh herbs", "artisanal preparation"],
            preparationNotes: "Prepared with traditional techniques and contemporary flair"
        )
        
        var updatedDish = dish
        updatedDish.aiVisualization = testVisualization
        updatedDish.isGenerating = false
        
        return .success(updatedDish)
    }
    
    /// Get detailed metrics for testing
    /// - Returns: Comprehensive metrics dictionary
    func getDetailedMetrics() -> [String: Any] {
        return [
            "cache": [
                "size": visualizationCache.count,
                "keys": Array(visualizationCache.keys.prefix(5)) // First 5 keys for debugging
            ],
            "processing": [
                "activeGenerations": generationProgress.count,
                "progressValues": generationProgress.values.map { $0 }
            ],
            "performance": performanceMetrics.toDictionary(),
            "state": [
                "current": processingState.displayText,
                "isProcessing": processingState.isProcessing
            ]
        ]
    }
}
#endif