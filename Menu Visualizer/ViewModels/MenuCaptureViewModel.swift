//
//  MenuCaptureViewModel.swift
//  Menu Visualizer
//
//  ViewModel for menu capture functionality
//

import SwiftUI
import UIKit
import AVFoundation
import Combine

// Type alias to avoid conflict with SwiftUI.Menu
typealias MenuModel = Menu

/// ViewModel managing menu capture workflow with privacy-first approach
@MainActor
final class MenuCaptureViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentState: AppState = .idle
    @Published var capturedImage: UIImage?
    @Published var extractedMenu: MenuModel?
    @Published var currentError: MenulyError?
    @Published var isShowingCamera = false
    @Published var processingProgress: Double = 0.0
    @Published var performanceMetrics: PerformanceMetrics?
    
    // MARK: - Services
    
    // Camera service is now accessed through CameraManager.shared
    private let aiService: AIMenuAnalysisService
    var coordinator: AppCoordinator
    
    // MARK: - Configuration
    
    /// Processing quality for menu analysis
    enum ProcessingQuality {
        case fast          // Fast AI analysis with basic optimization
        case balanced      // Balanced speed and accuracy (default)
        case highQuality   // Maximum accuracy with detailed analysis
    }
    
    @Published var processingQuality: ProcessingQuality = .balanced
    @Published var useAIService: Bool = true
    
    // MARK: - Performance Tracking
    
    private var operationStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.aiService = AIMenuAnalysisService()
        
        // Verify AI service is available
        self.useAIService = APIKeyManager.shared.isFirebaseAIConfigured() || APIKeyManager.shared.hasValidGeminiAPIKey()
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe AI service progress
        aiService.$processingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if self?.currentState == .processingOCR || self?.currentState == .extractingDishes {
                    self?.processingProgress = progress
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Camera Actions
    
    func requestCameraPermission() async {
        let granted = await CameraManager.shared.requestPermission()
        
        if !granted {
            currentError = .cameraPermissionDenied
            coordinator.updateState(.error(.cameraPermissionDenied))
        }
    }
    
    func startCameraSession() async {
        guard CameraManager.shared.authorizationStatus == .authorized else {
            await requestCameraPermission()
            return
        }
        
        let success = await CameraManager.shared.configureSession()
        
        if success {
            CameraManager.shared.startSession()
            isShowingCamera = true
            updateState(.capturingPhoto)
        } else {
            currentError = .cameraUnavailable
        }
    }
    
    func setupCamera() async {
        print("🎬 Setting up camera in ViewModel")
        
        let cameraManager = CameraManager.shared
        
        guard cameraManager.authorizationStatus == .authorized else {
            print("❌ Not authorized for camera")
            currentError = .cameraPermissionDenied
            return
        }
        
        let success = await cameraManager.configureSession()
        
        if success {
            print("✅ Camera session setup successful")
            cameraManager.startSession()
            isShowingCamera = true
            updateState(.capturingPhoto)
        } else {
            print("❌ Camera session setup failed")
            handleError(.cameraUnavailable)
        }
    }
    
    func capturePhoto() async {
        guard currentState != .processingOCR && currentState != .extractingDishes else {
            return // Already processing
        }
        
        operationStartTime = Date()
        updateState(.capturingPhoto)
        
        // Use CameraManager for photo capture
        let cameraManager = CameraManager.shared
        let result = await cameraManager.capturePhoto()
        
        switch result {
        case .success(let image):
            print("✅ Photo captured successfully")
            capturedImage = image
            isShowingCamera = false
            await processMenuPhoto(image)
        case .failure(let error):
            print("❌ Photo capture failed: \(error)")
            handleError(.photoCaptureFailed)
        }
    }
    
    // MARK: - Image Processing Pipeline
    
    func processMenuPhoto(_ image: UIImage) async {
        operationStartTime = Date()
        await processWithAI(image)
    }
    
    // MARK: - AI Processing
    
    private func processWithAI(_ image: UIImage) async {
        guard useAIService else {
            handleError(.aiServiceConfigurationError("AI service is not configured. Please check your Firebase configuration or API key."))
            return
        }
        
        print("🤖 Processing menu with Gemini AI...")
        updateState(.processingOCR)
        
        // Configure AI service based on quality setting
        let configuration = getAIConfiguration()
        let aiResult = await aiService.analyzeMenu(from: image, configuration: configuration)
        
        switch aiResult {
        case .success(let menu):
            print("✅ AI analysis successful with \(menu.dishes.count) dishes")
            await completeAIProcessing(menu)
            
        case .failure(let error):
            print("❌ AI analysis failed: \(error.localizedDescription)")
            handleError(convertAIError(error))
        }
    }
    
    private func getAIConfiguration() -> AIMenuAnalysisService.AnalysisConfiguration {
        switch processingQuality {
        case .fast:
            return .fast
        case .balanced:
            return .default
        case .highQuality:
            return .highQuality
        }
    }
    
    private func completeAIProcessing(_ menu: Menu) async {
        // Calculate performance metrics for AI processing
        let endTime = Date()
        
        if let operationStart = operationStartTime {
            let totalTime = endTime.timeIntervalSince(operationStart)
            
            performanceMetrics = PerformanceMetrics(
                ocrProcessingTime: 0, // Not used in AI pipeline
                dishExtractionTime: 0, // Not used in AI pipeline
                apiRequestTime: totalTime, // AI processing time
                totalProcessingTime: totalTime,
                memoryUsage: getMemoryUsage(),
                imageProcessingTime: totalTime
            )
        }
        
        extractedMenu = menu
        processingProgress = 1.0
        updateState(.displayingResults)
        
        print("🎉 Menu analysis completed in \(String(format: "%.2f", performanceMetrics?.totalProcessingTime ?? 0))s")
        print("📊 Processing quality: \(processingQuality)")
        
        // Navigate to results
        coordinator.navigate(to: .dishList(menu: menu))
        
        // Clear processing state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.processingProgress = 0.0
        }
    }
    
    private func convertAIError(_ error: MenulyError) -> MenulyError {
        // AI service now returns specific error types, so we can pass them through directly
        // This provides better user experience with more specific error messages
        return error
    }
    
    
    // MARK: - State Management
    
    private func updateState(_ newState: AppState) {
        currentState = newState
        coordinator.updateState(newState)
        
        // Clear error when transitioning to non-error state
        if case .error = currentState {
            // Keep error state
        } else {
            currentError = nil
        }
    }
    
    func handleError(_ error: MenulyError) {
        currentError = error
        processingProgress = 0.0
        updateState(.error(error))
        coordinator.handleError(error)
    }
    
    // MARK: - Utility Methods
    
    func retryLastOperation() async {
        guard let image = capturedImage else {
            await startCameraSession()
            return
        }
        
        currentError = nil
        await processMenuPhoto(image)
    }
    
    func resetCapture() {
        capturedImage = nil
        extractedMenu = nil
        currentError = nil
        processingProgress = 0.0
        performanceMetrics = nil
        updateState(.idle)
        
        // Clear camera service
        CameraManager.shared.capturedImage = nil
    }
    
    func cancelCurrentOperation() {
        aiService.cancelProcessing()
        processingProgress = 0.0
        updateState(.idle)
    }
    
    // MARK: - AI Service Management
    
    /// Update processing quality based on user preference
    func updateProcessingQuality(_ quality: ProcessingQuality) {
        processingQuality = quality
        print("📈 Processing quality updated to: \(quality)")
    }
    
    /// Check if AI service is available and properly configured
    func validateAIServiceAvailability() -> Bool {
        return APIKeyManager.shared.isFirebaseAIConfigured() || APIKeyManager.shared.hasValidGeminiAPIKey()
    }
    
    /// Get recommended processing quality based on current conditions
    func getRecommendedQuality() -> ProcessingQuality {
        return .balanced // Always recommend balanced for best user experience
    }
    
    /// Estimate processing time based on current quality setting
    func estimateProcessingTime(for imageSize: CGSize) -> TimeInterval {
        guard validateAIServiceAvailability() else {
            return 0 // No processing possible without AI service
        }
        
        let config = getAIConfiguration()
        return aiService.estimateProcessingTime(for: imageSize, configuration: config)
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    // MARK: - Privacy Compliance
    
    func clearAllData() {
        resetCapture()
        
        CameraManager.shared.stopSession()
        
        // Clear any cached data in services
        // Note: Services are designed to not persist data beyond session
    }
    
    // MARK: - Computed Properties
    
    var isProcessing: Bool {
        switch currentState {
        case .processingOCR, .extractingDishes:
            return true
        default:
            return false
        }
    }
    
    var canCapture: Bool {
        let cameraManager = CameraManager.shared
        return cameraManager.authorizationStatus == .authorized && !isProcessing
    }
    
    var processingStatusText: String {
        switch currentState {
        case .capturingPhoto:
            return "Capturing photo..."
        case .processingOCR:
            return aiService.currentStage.rawValue
        case .extractingDishes:
            return aiService.currentStage.rawValue
        case .displayingResults:
            return "Complete!"
        case .error(let error):
            return error.localizedDescription
        default:
            return ""
        }
    }
    
    var currentProcessingMethod: String {
        return "Gemini AI (\(processingQuality.displayName))"
    }
}

// MARK: - Processing Quality Extension

extension MenuCaptureViewModel.ProcessingQuality {
    var displayName: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .highQuality:
            return "High Quality"
        }
    }
    
    var description: String {
        switch self {
        case .fast:
            return "Quick analysis with basic optimization"
        case .balanced:
            return "Balanced speed and accuracy"
        case .highQuality:
            return "Maximum accuracy with detailed analysis"
        }
    }
}

