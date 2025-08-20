//
//  MenuCaptureViewModel.swift
//  Menu Visualizer
//
//  ViewModel for menu capture functionality
//

import SwiftUI
import AVFoundation
import Vision
import Combine

/// ViewModel managing menu capture workflow with privacy-first approach
@MainActor
final class MenuCaptureViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentState: AppState = .idle
    @Published var capturedImage: UIImage?
    @Published var extractedMenu: Menu?
    @Published var currentError: MenulyError?
    @Published var isShowingCamera = false
    @Published var processingProgress: Double = 0.0
    @Published var performanceMetrics: PerformanceMetrics?
    
    // MARK: - Services
    
    let cameraService: CameraService
    private let ocrService: OCRService
    private let parsingService: MenuParsingService
    var coordinator: AppCoordinator
    
    // MARK: - Performance Tracking
    
    private var operationStartTime: Date?
    private var ocrStartTime: Date?
    private var parsingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.cameraService = CameraService()
        self.ocrService = OCRService()
        self.parsingService = MenuParsingService()
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Observe OCR service progress
        ocrService.$processingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if self?.currentState == .processingOCR {
                    self?.processingProgress = progress * 0.5 // OCR is first half
                }
            }
            .store(in: &cancellables)
        
        // Observe parsing service progress
        parsingService.$processingProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if self?.currentState == .extractingDishes {
                    self?.processingProgress = 0.5 + (progress * 0.5) // Parsing is second half
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Camera Actions
    
    func requestCameraPermission() async {
        let granted = await cameraService.requestCameraPermission()
        
        if !granted {
            currentError = .cameraPermissionDenied
            coordinator.updateState(.error(.cameraPermissionDenied))
        }
    }
    
    func startCameraSession() async {
        guard cameraService.isAuthorized else {
            await requestCameraPermission()
            return
        }
        
        let result = cameraService.setupCaptureSession()
        
        switch result {
        case .success:
            cameraService.startSession()
            isShowingCamera = true
            updateState(.capturingPhoto)
        case .failure(let error):
            handleError(error)
        }
    }
    
    func capturePhoto() async {
        guard currentState != .processingOCR && currentState != .extractingDishes else {
            return // Already processing
        }
        
        operationStartTime = Date()
        updateState(.capturingPhoto)
        
        let result = await cameraService.capturePhoto()
        
        switch result {
        case .success(let image):
            capturedImage = image
            isShowingCamera = false
            await processMenuPhoto(image)
            
        case .failure(let error):
            isShowingCamera = false
            handleError(error)
        }
    }
    
    // MARK: - Image Processing Pipeline
    
    func processMenuPhoto(_ image: UIImage) async {
        // Step 1: OCR Processing
        ocrStartTime = Date()
        updateState(.processingOCR)
        
        let ocrResult = await ocrService.extractText(from: image)
        
        switch ocrResult {
        case .success(let result):
            await processDishExtraction(result)
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func processDishExtraction(_ ocrResult: OCRResult) async {
        // Step 2: Dish Extraction
        parsingStartTime = Date()
        updateState(.extractingDishes)
        
        let parsingResult = await parsingService.extractDishes(from: ocrResult)
        
        switch parsingResult {
        case .success(let menu):
            await completeProcessing(menu, ocrResult)
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func completeProcessing(_ menu: Menu, _ ocrResult: OCRResult) async {
        // Calculate performance metrics
        let endTime = Date()
        
        if let operationStart = operationStartTime,
           let ocrStart = ocrStartTime,
           let parsingStart = parsingStartTime {
            
            let ocrTime = parsingStart.timeIntervalSince(ocrStart)
            let parsingTime = endTime.timeIntervalSince(parsingStart)
            let totalTime = endTime.timeIntervalSince(operationStart)
            
            performanceMetrics = PerformanceMetrics(
                ocrProcessingTime: ocrTime,
                dishExtractionTime: parsingTime,
                apiRequestTime: 0, // Not used in this phase
                totalProcessingTime: totalTime,
                memoryUsage: getMemoryUsage(),
                imageProcessingTime: ocrResult.processingTime
            )
        }
        
        extractedMenu = menu
        processingProgress = 1.0
        updateState(.displayingResults)
        
        // Navigate to results
        coordinator.navigate(to: .dishList(menu: menu))
        
        // Clear processing state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.processingProgress = 0.0
        }
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
        cameraService.clearCapturedImage()
    }
    
    func cancelCurrentOperation() {
        ocrService.cancelProcessing()
        processingProgress = 0.0
        updateState(.idle)
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
        
        cameraService.stopSession()
        
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
        return cameraService.isAuthorized && 
               cameraService.isCameraAvailable && 
               !isProcessing
    }
    
    var processingStatusText: String {
        switch currentState {
        case .capturingPhoto:
            return "Capturing photo..."
        case .processingOCR:
            return "Reading menu text..."
        case .extractingDishes:
            return "Finding dishes..."
        case .displayingResults:
            return "Complete!"
        case .error(let error):
            return error.localizedDescription
        default:
            return ""
        }
    }
}

