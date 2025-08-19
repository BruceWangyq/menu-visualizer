//
//  MockServices.swift
//  Menu VisualizerTests
//
//  Mock implementations of all services for offline testing
//  Enables comprehensive testing without external dependencies
//

import Foundation
import UIKit
import Vision
import Combine
@testable import Menu_Visualizer

// MARK: - Mock OCR Service

final class MockOCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentStage: OCRService.ProcessingStage = .idle
    
    // Test configuration
    var mockSuccessRate: Float = 1.0
    var mockProcessingDelay: TimeInterval = 0.1
    var mockTextBlocks: [OCRResult.TextBlock] = []
    var shouldFailOCR: Bool = false
    var mockError: MenulyError?
    
    func extractText(
        from image: UIImage,
        configuration: OCRService.OCRConfiguration = .menuOptimized
    ) async -> Result<OCRResult, MenulyError> {
        
        isProcessing = true
        currentStage = .preprocessing
        processingProgress = 0.0
        
        // Simulate processing stages
        await simulateProcessingStages()
        
        if let error = mockError {
            isProcessing = false
            processingProgress = 0.0
            currentStage = .idle
            return .failure(error)
        }
        
        if shouldFailOCR || Float.random(in: 0...1) > mockSuccessRate {
            let error = MenulyError.ocrProcessingFailed
            isProcessing = false
            processingProgress = 0.0
            currentStage = .idle
            return .failure(error)
        }
        
        let result = createMockOCRResult(for: image, configuration: configuration)
        
        isProcessing = false
        processingProgress = 1.0
        currentStage = .completed
        
        return .success(result)
    }
    
    func assessImageQuality(_ image: UIImage) async -> ImagePreprocessor.QualityAssessment {
        return ImagePreprocessor.QualityAssessment(
            sharpness: 0.85,
            brightness: 0.75,
            contrast: 0.80,
            overallQuality: 0.80,
            recommendedPreprocessing: [.enhanceContrast, .sharpen]
        )
    }
    
    func estimateProcessingTime(for imageSize: CGSize, quality: OCRService.OCRQuality = .balanced) -> TimeInterval {
        return mockProcessingDelay
    }
    
    func cancelProcessing() {
        isProcessing = false
        processingProgress = 0.0
        currentStage = .idle
    }
    
    private func simulateProcessingStages() async {
        let stages: [(OCRService.ProcessingStage, Double)] = [
            (.preprocessing, 0.2),
            (.textRecognition, 0.6),
            (.layoutAnalysis, 0.8),
            (.postprocessing, 0.95),
            (.completed, 1.0)
        ]
        
        for (stage, progress) in stages {
            currentStage = stage
            processingProgress = progress
            try? await Task.sleep(nanoseconds: UInt64(mockProcessingDelay * 200_000_000)) // 20% of delay per stage
        }
    }
    
    private func createMockOCRResult(for image: UIImage, configuration: OCRService.OCRConfiguration) -> OCRResult {
        let textBlocks = mockTextBlocks.isEmpty ? createDefaultTextBlocks() : mockTextBlocks
        let overallConfidence = textBlocks.reduce(0.0) { $0 + $1.confidence } / Float(textBlocks.count)
        
        return OCRResult(
            recognizedText: textBlocks,
            processingTime: mockProcessingDelay,
            overallConfidence: overallConfidence,
            imageSize: image.size,
            detectedLanguages: configuration.languages,
            layoutAnalysis: createMockLayoutAnalysis()
        )
    }
    
    private func createDefaultTextBlocks() -> [OCRResult.TextBlock] {
        return [
            OCRResult.TextBlock(
                text: "APPETIZERS",
                boundingBox: CGRect(x: 0.1, y: 0.9, width: 0.8, height: 0.05),
                confidence: 0.95,
                recognitionLevel: .accurate,
                alternatives: [],
                textType: .sectionHeader
            ),
            OCRResult.TextBlock(
                text: "Caesar Salad",
                boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.6, height: 0.04),
                confidence: 0.92,
                recognitionLevel: .accurate,
                alternatives: ["Caeser Salad"],
                textType: .dishName
            ),
            OCRResult.TextBlock(
                text: "$12.99",
                boundingBox: CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.04),
                confidence: 0.97,
                recognitionLevel: .accurate,
                alternatives: [],
                textType: .price
            )
        ]
    }
    
    private func createMockLayoutAnalysis() -> LayoutAnalysisResult {
        return LayoutAnalysisResult(
            detectedColumns: 1,
            menuSections: [
                MenuSection(
                    header: "APPETIZERS",
                    boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.3),
                    textBlocks: []
                )
            ],
            averageLineSpacing: 0.03,
            textAlignment: .left
        )
    }
}

// MARK: - Mock Menu Parsing Service

final class MockMenuParsingService {
    var mockExtractedDishes: [Dish] = []
    var mockProcessingDelay: TimeInterval = 0.1
    var shouldFailParsing: Bool = false
    var mockError: MenulyError?
    
    func extractDishes(from ocrResult: OCRResult) async throws -> [Dish] {
        try await Task.sleep(nanoseconds: UInt64(mockProcessingDelay * 1_000_000_000))
        
        if let error = mockError {
            throw error
        }
        
        if shouldFailParsing {
            throw MenulyError.ocrProcessingFailed
        }
        
        if !mockExtractedDishes.isEmpty {
            return mockExtractedDishes
        }
        
        // Create dishes from OCR result
        var dishes: [Dish] = []
        var currentDishName: String?
        var currentDescription: String?
        var currentPrice: String?
        
        for textBlock in ocrResult.recognizedText {
            switch textBlock.textType {
            case .dishName:
                // Save previous dish if exists
                if let dishName = currentDishName {
                    dishes.append(createDish(name: dishName, description: currentDescription, price: currentPrice, confidence: textBlock.confidence))
                }
                currentDishName = textBlock.text
                currentDescription = nil
                currentPrice = nil
                
            case .description:
                currentDescription = textBlock.text
                
            case .price:
                currentPrice = textBlock.text
                
            default:
                break
            }
        }
        
        // Don't forget the last dish
        if let dishName = currentDishName {
            dishes.append(createDish(name: dishName, description: currentDescription, price: currentPrice))
        }
        
        return dishes
    }
    
    private func createDish(name: String, description: String?, price: String?, confidence: Float = 0.9) -> Dish {
        let category = classifyDishCategory(name: name, description: description)
        return Dish(name: name, description: description, price: price, category: category, confidence: confidence)
    }
    
    private func classifyDishCategory(name: String, description: String?) -> DishCategory {
        let text = (name + " " + (description ?? "")).lowercased()
        
        if text.contains("appetizer") || text.contains("starter") || text.contains("salad") {
            return .appetizer
        } else if text.contains("soup") {
            return .soup
        } else if text.contains("pasta") {
            return .pasta
        } else if text.contains("seafood") || text.contains("fish") || text.contains("salmon") {
            return .seafood
        } else if text.contains("beef") || text.contains("steak") || text.contains("chicken") {
            return .meat
        } else if text.contains("vegetarian") || text.contains("veggie") {
            return .vegetarian
        } else if text.contains("dessert") || text.contains("cake") || text.contains("ice cream") {
            return .dessert
        } else if text.contains("coffee") || text.contains("tea") || text.contains("drink") {
            return .beverage
        } else {
            return .mainCourse
        }
    }
}

// MARK: - Mock Claude API Client

final class MockClaudeAPIClient {
    var mockResponses: [String: DishVisualization] = [:]
    var mockNetworkDelay: TimeInterval = 0.5
    var mockSuccessRate: Float = 1.0
    var shouldFailAuthentication: Bool = false
    var shouldSimulateRateLimit: Bool = false
    var mockError: ClaudeAPIError?
    
    private var requestCount: Int = 0
    private let maxRequestsPerMinute: Int = 10
    private var lastRequestTime: Date = Date()
    
    func generateDishVisualization(for dish: Dish) async -> Result<DishVisualization, ClaudeAPIError> {
        requestCount += 1
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: UInt64(mockNetworkDelay * 1_000_000_000))
        
        // Check for authentication failure
        if shouldFailAuthentication {
            return .failure(.authenticationFailed)
        }
        
        // Check for rate limiting
        if shouldSimulateRateLimit && requestCount > maxRequestsPerMinute {
            return .failure(.rateLimitExceeded)
        }
        
        // Check for mock error
        if let error = mockError {
            return .failure(error)
        }
        
        // Check success rate
        if Float.random(in: 0...1) > mockSuccessRate {
            return .failure(.networkError("Mock network failure"))
        }
        
        // Check for pre-configured response
        if let mockVisualization = mockResponses[dish.name] {
            return .success(mockVisualization)
        }
        
        // Generate default visualization
        let visualization = createMockVisualization(for: dish)
        return .success(visualization)
    }
    
    func validateAPIKey() -> Bool {
        return !shouldFailAuthentication
    }
    
    func setTestMode(enabled: Bool) {
        // Test mode configuration
    }
    
    func setPrivacyMode(enabled: Bool) {
        // Privacy mode configuration
    }
    
    func isIntegrationTestEnabled() -> Bool {
        return false // Always false for unit tests
    }
    
    private func createMockVisualization(for dish: Dish) -> DishVisualization {
        let ingredients = generateMockIngredients(for: dish)
        let description = generateMockDescription(for: dish)
        let preparationNotes = generateMockPreparationNotes(for: dish)
        
        return DishVisualization(
            dishId: dish.id,
            generatedDescription: description,
            visualStyle: "elegant restaurant presentation",
            ingredients: ingredients,
            preparationNotes: preparationNotes
        )
    }
    
    private func generateMockIngredients(for dish: Dish) -> [String] {
        let baseIngredients = ["main ingredient", "herbs", "seasoning"]
        
        switch dish.category {
        case .seafood:
            return ["fresh fish", "lemon", "herbs", "olive oil"]
        case .meat:
            return ["premium meat", "garlic", "rosemary", "black pepper"]
        case .vegetarian:
            return ["fresh vegetables", "herbs", "olive oil", "spices"]
        case .pasta:
            return ["pasta", "tomatoes", "basil", "parmesan"]
        case .dessert:
            return ["flour", "sugar", "eggs", "vanilla"]
        default:
            return baseIngredients
        }
    }
    
    private func generateMockDescription(for dish: Dish) -> String {
        let templates = [
            "A beautifully prepared \(dish.name.lowercased()) with excellent presentation and rich flavors.",
            "This \(dish.name.lowercased()) features fresh ingredients and careful preparation for an exceptional dining experience.",
            "An expertly crafted \(dish.name.lowercased()) that showcases culinary artistry and attention to detail."
        ]
        
        return templates.randomElement() ?? templates[0]
    }
    
    private func generateMockPreparationNotes(for dish: Dish) -> String {
        switch dish.category {
        case .seafood:
            return "Carefully grilled to preserve natural flavors, served with complementary accompaniments."
        case .meat:
            return "Expertly seasoned and cooked to desired doneness, rested for optimal texture."
        case .vegetarian:
            return "Fresh ingredients combined with traditional techniques for maximum flavor."
        default:
            return "Prepared with attention to detail using time-honored culinary methods."
        }
    }
    
    // Test configuration methods
    func setMockResponse(for dishName: String, visualization: DishVisualization) {
        mockResponses[dishName] = visualization
    }
    
    func resetMockState() {
        mockResponses.removeAll()
        requestCount = 0
        mockError = nil
        shouldFailAuthentication = false
        shouldSimulateRateLimit = false
        mockSuccessRate = 1.0
    }
}

// MARK: - Mock Camera Service

final class MockCameraService: ObservableObject {
    @Published var isAvailable = true
    @Published var authorizationStatus: CameraPermissionManager.AuthorizationStatus = .authorized
    @Published var isCapturing = false
    
    var mockCapturedImage: UIImage?
    var mockCaptureDelay: TimeInterval = 0.5
    var shouldFailCapture: Bool = false
    var mockError: MenulyError?
    
    func capturePhoto() async -> Result<UIImage, MenulyError> {
        isCapturing = true
        
        // Simulate capture delay
        try? await Task.sleep(nanoseconds: UInt64(mockCaptureDelay * 1_000_000_000))
        
        isCapturing = false
        
        if let error = mockError {
            return .failure(error)
        }
        
        if shouldFailCapture {
            return .failure(.photoCaptureFailed)
        }
        
        guard authorizationStatus == .authorized else {
            return .failure(.cameraPermissionDenied)
        }
        
        guard isAvailable else {
            return .failure(.cameraNotAvailable)
        }
        
        let image = mockCapturedImage ?? createMockCapturedImage()
        return .success(image)
    }
    
    func requestPermission() async -> CameraPermissionManager.AuthorizationStatus {
        // Simulate permission request delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // For testing, return the current status
        return authorizationStatus
    }
    
    private func createMockCapturedImage() -> UIImage {
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add mock menu text
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            
            let menuText = """
            RESTAURANT MENU
            
            Grilled Salmon - $24.99
            Caesar Salad - $12.99
            Chocolate Cake - $8.99
            """
            
            let attributedText = NSAttributedString(string: menuText, attributes: textAttributes)
            let textRect = CGRect(x: 50, y: 200, width: size.width - 100, height: 400)
            attributedText.draw(in: textRect)
        }
    }
}

// MARK: - Mock Privacy Services

final class MockPrivacyComplianceService {
    var privacySettings = PrivacySettings.default
    var dataRetentionStatus = DataRetentionStatus()
    var privacyViolations: [PrivacyViolation] = []
    var complianceScore: Float = 1.0
    var isPrivacyManifestValid = true
    var lastDataClearTime: Date?
    
    func trackImageCapture() {
        dataRetentionStatus.hasTemporaryImages = true
    }
    
    func trackOCRProcessing() {
        dataRetentionStatus.hasProcessingData = true
    }
    
    func trackAPICall() {
        dataRetentionStatus.hasAPIData = true
    }
    
    func calculateComplianceScore() async {
        // Simulate calculation
        complianceScore = max(0.0, 1.0 - (Float(privacyViolations.count) * 0.1))
    }
    
    func auditDataRetention() async {
        if privacySettings.dataRetentionPolicy == .never && dataRetentionStatus.hasAnyData {
            recordPrivacyViolation(.dataRetentionViolation, details: "Data retained with never policy")
        }
    }
    
    func recordPrivacyViolation(_ type: PrivacyViolationType, details: String) {
        privacyViolations.append(PrivacyViolation(type: type, details: details))
    }
    
    func clearAllDataImmediately() {
        dataRetentionStatus = DataRetentionStatus()
        lastDataClearTime = Date()
    }
    
    func handleAppWillTerminate() {
        if privacySettings.dataRetentionPolicy == .sessionOnly {
            clearAllDataImmediately()
        }
    }
    
    func handleAppDidEnterBackground() {
        if privacySettings.dataRetentionPolicy == .never {
            clearAllDataImmediately()
        }
    }
    
    func validatePrivacyManifest() async {
        // Simulate validation
        isPrivacyManifestValid = privacyViolations.isEmpty
    }
}

final class MockConsentManager {
    private var consents: [ConsentCategory: Bool] = [:]
    var consentStatus: ConsentStatus = .unknown
    
    func updateConsent(for category: ConsentCategory, granted: Bool) {
        consents[category] = granted
        updateConsentStatus()
    }
    
    func isConsentGranted(for category: ConsentCategory) -> Bool {
        return consents[category] ?? false
    }
    
    func isEssentialConsentGranted() -> Bool {
        return isConsentGranted(for: .dataProcessing) && isConsentGranted(for: .apiCommunication)
    }
    
    func canProcessData() -> Bool {
        return isConsentGranted(for: .dataProcessing)
    }
    
    func canMakeAPICalls() -> Bool {
        return isConsentGranted(for: .apiCommunication)
    }
    
    func withdrawAllConsent() {
        for category in ConsentCategory.allCases {
            consents[category] = false
        }
        consentStatus = .denied
    }
    
    func generatePrivacyManifest() -> PrivacyManifest {
        return PrivacyManifest(
            trackingEnabled: false,
            dataLinkedToUser: false,
            dataUsedForTracking: false,
            trackingDomains: [],
            privacyPolicyURL: "https://menuly.com/privacy"
        )
    }
    
    private func updateConsentStatus() {
        if isEssentialConsentGranted() {
            consentStatus = .granted
        } else if consents.values.contains(false) {
            consentStatus = .denied
        } else {
            consentStatus = .unknown
        }
    }
}

final class MockAPIPrivacyLayer {
    private var dataRetentionPolicy: DataRetentionPolicy = .sessionOnly
    private var storedVisualizations: [UUID: DishVisualization] = [:]
    private var privacyViolationCount: Int = 0
    private var recentViolations: [PrivacyViolation] = []
    
    func containsSensitiveData(_ text: String) -> Bool {
        let sensitivePatterns = [
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, // Email
            #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#, // Phone
            #"\b\d{3}-\d{2}-\d{4}\b"#, // SSN
            #"www\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, // URLs
            #"https?://[^\s]+"# // HTTP URLs
        ]
        
        for pattern in sensitivePatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                privacyViolationCount += 1
                recordViolation(.sensitiveDataDetected, details: "Sensitive data pattern detected")
                return true
            }
        }
        
        return false
    }
    
    func sanitizeDishPayload(_ dish: Dish) -> DishAPIPayload {
        let sanitizedName = sanitizeText(dish.name)
        let sanitizedDescription = dish.description.map { sanitizeText($0) }
        
        return DishAPIPayload(
            name: sanitizedName,
            description: sanitizedDescription,
            category: dish.category.rawValue
        )
    }
    
    func validateRequestSecurity(_ request: URLRequest) throws {
        guard let url = request.url else {
            throw APIPrivacyError.invalidRequest("No URL")
        }
        
        guard url.scheme == "https" else {
            throw APIPrivacyError.insecureProtocol
        }
        
        let trustedHosts = ["api.anthropic.com", "api.claude.ai"]
        guard let host = url.host, trustedHosts.contains(host) else {
            throw APIPrivacyError.untrustedHost
        }
    }
    
    func validatePayloadSize(_ dish: Dish) throws {
        let payload = sanitizeDishPayload(dish)
        let data = try JSONEncoder().encode(payload)
        
        if data.count > 10240 { // 10KB limit
            throw APIPrivacyError.payloadTooLarge
        }
    }
    
    func getPrivacyHeaders() -> [String: String] {
        return [
            "DNT": "1",
            "X-Privacy-Policy": "privacy-first",
            "User-Agent": "MenulyApp/1.0 Privacy-First",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY"
        ]
    }
    
    func sanitizeAPIResponse(_ data: Data) -> String {
        guard let responseString = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        // Remove metadata that could compromise privacy
        let metadataPatterns = [
            #"\"internal_id\":\s*\"[^\"]*\""#,
            #"\"server_location\":\s*\"[^\"]*\""#,
            #"\"request_id\":\s*\"[^\"]*\""#,
            #"\"processing_server\":\s*\"[^\"]*\""#
        ]
        
        var sanitized = responseString
        for pattern in metadataPatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return sanitized
    }
    
    func setDataRetentionPolicy(_ policy: DataRetentionPolicy) {
        dataRetentionPolicy = policy
    }
    
    func storeVisualization(_ visualization: DishVisualization) throws {
        if dataRetentionPolicy == .never {
            throw APIPrivacyError.dataRetentionViolation
        }
        
        storedVisualizations[visualization.id] = visualization
    }
    
    func getStoredVisualization(_ id: UUID) -> DishVisualization? {
        return storedVisualizations[id]
    }
    
    func handleAppTermination() {
        if dataRetentionPolicy == .sessionOnly {
            storedVisualizations.removeAll()
        }
    }
    
    func getPrivacyViolationCount() -> Int {
        return privacyViolationCount
    }
    
    func getRecentPrivacyViolations(limit: Int) -> [PrivacyViolation] {
        return Array(recentViolations.suffix(limit))
    }
    
    func calculatePrivacyScore() -> Float {
        return max(0.0, 1.0 - (Float(privacyViolationCount) * 0.1))
    }
    
    func createMinimalPayload(for dish: Dish) -> DishAPIPayload {
        let limitedDescription = dish.description?.prefix(200).description
        return DishAPIPayload(
            name: dish.name,
            description: limitedDescription,
            category: dish.category.rawValue
        )
    }
    
    func performGDPRComplianceAudit() -> GDPRCompliance {
        return GDPRCompliance(
            dataMinimization: true,
            purposeLimitation: true,
            rightToErasure: true,
            rightToPortability: true,
            hasLawfulBasis: true,
            technicalMeasures: true,
            organizationalMeasures: true
        )
    }
    
    func performCCPAComplianceAudit() -> CCPACompliance {
        return CCPACompliance(
            rightToKnow: true,
            rightToDelete: true,
            rightToOptOut: true,
            nonDiscrimination: true,
            serviceProviderCompliance: true
        )
    }
    
    func setPrivacyChecksEnabled(_ enabled: Bool) {
        // Configuration for performance testing
    }
    
    private func sanitizeText(_ text: String) -> String {
        var sanitized = text
        
        // Remove or replace sensitive patterns
        let replacements = [
            (#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, "[EMAIL_REMOVED]"),
            (#"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#, "[PHONE_REMOVED]"),
            (#"<[^>]+>"#, ""), // Remove HTML tags
            (#"[&<>\"']"#, "") // Remove potentially dangerous characters
        ]
        
        for (pattern, replacement) in replacements {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        
        return sanitized
    }
    
    private func recordViolation(_ type: PrivacyViolationType, details: String) {
        let violation = PrivacyViolation(type: type, details: details)
        recentViolations.append(violation)
        
        // Keep only recent violations
        if recentViolations.count > 100 {
            recentViolations.removeFirst()
        }
    }
}

// MARK: - Supporting Mock Types

enum ConsentStatus {
    case unknown, granted, denied
}

enum ConsentCategory: CaseIterable {
    case dataProcessing, apiCommunication, analytics, marketing
}

struct DataRetentionStatus {
    var hasTemporaryImages = false
    var hasProcessingData = false
    var hasAPIData = false
    
    var hasAnyData: Bool {
        return hasTemporaryImages || hasProcessingData || hasAPIData
    }
}

struct PrivacyManifest {
    let trackingEnabled: Bool
    let dataLinkedToUser: Bool
    let dataUsedForTracking: Bool
    let trackingDomains: [String]
    let privacyPolicyURL: String
}

enum PrivacyViolationType {
    case dataRetentionViolation
    case sensitiveDataDetected
    case unauthorizedTransmission
    case consentViolation
}

struct PrivacyViolation {
    let id = UUID()
    let timestamp = Date()
    let type: PrivacyViolationType
    let details: String
}

enum ClaudeAPIError: Error, Equatable {
    case authenticationFailed
    case rateLimitExceeded
    case networkError(String)
    case invalidRequest(String)
    case serverError(String)
    case jsonParsingError
    case emptyResponse
    case networkTimeout
    case noInternetConnection
    case privacyViolation(String)
    case consentRequired
    case consentWithdrawn
    case maxRetriesExceeded
}

// MARK: - Image Preprocessor Mock Types

extension ImagePreprocessor {
    struct QualityAssessment {
        let sharpness: Float
        let brightness: Float
        let contrast: Float
        let overallQuality: Float
        let recommendedPreprocessing: [Enhancement]
    }
    
    enum Enhancement {
        case enhanceContrast
        case adjustBrightness
        case sharpen
        case deNoise
        case straighten
    }
}