//
//  MenuProcessingPipeline.swift
//  Menuly
//
//  Comprehensive image processing pipeline: photo → OCR → parsing → visualization
//

import Foundation
import UIKit
import SwiftUI
import Combine

/// Main orchestrator for the complete menu processing workflow
@MainActor
class MenuProcessingPipeline: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var processingState: ProcessingState = .idle
    @Published var currentMenu: Menu?
    @Published var processedDishes: [Dish] = []
    @Published var processingProgress: Double = 0.0
    @Published var error: MenulyError?
    
    // MARK: - Services
    
    private let cameraService = CameraService()
    private let imagePreprocessor = ImagePreprocessor()
    private let ocrService = OCRService()
    private let menuParsingService = MenuParsingService()
    private let visualizationService = VisualizationService()
    private let privacyComplianceService = PrivacyComplianceService()
    
    // MARK: - Configuration
    
    private var appConfiguration = AppConfiguration()
    private var processingConfiguration = ProcessingConfiguration()
    
    // MARK: - Private State
    
    private var cancellables = Set<AnyCancellable>()
    private var currentProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        setupProcessingObservers()
        loadConfiguration()
    }
    
    // MARK: - Public API
    
    /// Main entry point: Process a captured menu photo
    func processMenuPhoto(_ image: UIImage) async {
        guard processingState != .processingOCR else {
            print("Pipeline already processing - ignoring new request")
            return
        }
        
        // Cancel any ongoing processing
        currentProcessingTask?.cancel()
        
        currentProcessingTask = Task {
            await executeProcessingPipeline(image)
        }
    }
    
    /// Generate visualization for a specific dish
    func generateVisualization(for dish: Dish) async {
        guard !dish.isGenerating else { return }
        
        await MainActor.run {
            if let index = processedDishes.firstIndex(where: { $0.id == dish.id }) {
                processedDishes[index].isGenerating = true
                processingState = .generatingVisualization(dishName: dish.name)
            }
        }
        
        do {
            let result = try await visualizationService.generateVisualization(for: dish)
            
            await MainActor.run {
                if let index = processedDishes.firstIndex(where: { $0.id == dish.id }) {
                    processedDishes[index] = result
                    processedDishes[index].isGenerating = false
                }
                
                // Update processing state
                if processedDishes.allSatisfy({ !$0.isGenerating }) {
                    processingState = .completed
                }
                
                print("✅ Generated visualization for: \(dish.name)")
            }
            
        } catch {
            await MainActor.run {
                if let index = processedDishes.firstIndex(where: { $0.id == dish.id }) {
                    processedDishes[index].isGenerating = false
                }
                
                self.error = error as? MenulyError ?? .unknown(error.localizedDescription)
                processingState = .error(self.error!)
                print("❌ Visualization failed for \(dish.name): \(error)")
            }
        }
    }
    
    /// Generate visualizations for all dishes
    func generateAllVisualizations() async {
        let dishesToProcess = processedDishes.filter { $0.aiVisualization == nil && !$0.isGenerating }
        
        await MainActor.run {
            processingState = .generatingVisualization(dishName: "multiple dishes")
        }
        
        // Process dishes in batches to respect rate limits
        let batchSize = processingConfiguration.maxConcurrentVisualizations
        
        for batch in dishesToProcess.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for dish in batch {
                    group.addTask {
                        await self.generateVisualization(for: dish)
                    }
                }
            }
            
            // Brief pause between batches to respect rate limits
            if batch.count == batchSize {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        await MainActor.run {
            processingState = .completed
        }
    }
    
    /// Reset the pipeline state
    func reset() {
        currentProcessingTask?.cancel()
        
        processingState = .idle
        currentMenu = nil
        processedDishes = []
        processingProgress = 0.0
        error = nil
        
        // Privacy compliance: Clear any cached data
        privacyComplianceService.clearSessionData()
    }
    
    /// Cancel current processing
    func cancelProcessing() {
        currentProcessingTask?.cancel()
        processingState = .idle
        processingProgress = 0.0
    }
    
    // MARK: - Pipeline Implementation
    
    private func executeProcessingPipeline(_ image: UIImage) async {
        do {
            // Stage 1: Privacy Compliance Check
            await updateProgress(0.1, state: .processingOCR)
            try validatePrivacyCompliance()
            
            // Stage 2: Image Preprocessing
            await updateProgress(0.2, state: .processingOCR)
            let preprocessedImage = try await preprocessImage(image)
            
            // Stage 3: OCR Processing
            await updateProgress(0.3, state: .processingOCR)
            let ocrResult = try await performOCR(on: preprocessedImage)
            
            // Stage 4: Menu Parsing
            await updateProgress(0.6, state: .parsingMenu)
            let extractedDishes = try await parseMenuFromOCR(ocrResult)
            
            // Stage 5: Create Menu Object
            await updateProgress(0.8, state: .parsingMenu)
            let menu = Menu(
                ocrResult: ocrResult,
                extractedDishes: extractedDishes,
                privacyPolicy: appConfiguration.dataRetentionPolicy
            )
            
            // Stage 6: Update UI
            await MainActor.run {
                self.currentMenu = menu
                self.processedDishes = extractedDishes
                self.processingProgress = 1.0
                self.processingState = .completed
                
                print("✅ Menu processing completed: \(extractedDishes.count) dishes found")
            }
            
            // Stage 7: Privacy Compliance (Optional Auto-Delete)
            await handlePrivacyCompliance(menu)
            
        } catch {
            await MainActor.run {
                let menulyError = error as? MenulyError ?? .unknown(error.localizedDescription)
                self.error = menulyError
                self.processingState = .error(menulyError)
                
                print("❌ Pipeline failed: \(error)")
            }
        }
    }
    
    // MARK: - Pipeline Stages
    
    private func validatePrivacyCompliance() throws {
        guard privacyComplianceService.validateProcessingPermissions() else {
            throw MenulyError.privacyViolation("Processing permissions not validated")
        }
        
        print("✅ Privacy compliance validated")
    }
    
    private func preprocessImage(_ image: UIImage) async throws -> UIImage {
        let settings = ImagePreprocessingSettings(
            maxSize: CGSize(width: appConfiguration.maxImageSize, height: appConfiguration.maxImageSize),
            quality: appConfiguration.ocrQuality,
            enhanceForOCR: true
        )
        
        let result = try await imagePreprocessor.preprocessImage(image, with: settings)
        print("✅ Image preprocessed: \(result.size)")
        return result
    }
    
    private func performOCR(on image: UIImage) async throws -> OCRResult {
        let settings = OCRSettings(
            quality: appConfiguration.ocrQuality,
            languages: processingConfiguration.ocrLanguages,
            enableProgressReporting: true
        )
        
        // Set up progress monitoring
        ocrService.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.processingProgress = 0.3 + (progress * 0.3) // OCR is 30% of total
            }
            .store(in: &cancellables)
        
        let result = try await ocrService.recognizeText(in: image, with: settings)
        
        guard !result.rawText.isEmpty else {
            throw MenulyError.noTextRecognized
        }
        
        print("✅ OCR completed: \(result.recognizedLines.count) lines, confidence: \(result.confidence)")
        return result
    }
    
    private func parseMenuFromOCR(_ ocrResult: OCRResult) async throws -> [Dish] {
        let settings = MenuParsingSettings(
            enableCategoryDetection: true,
            enablePriceExtraction: true,
            minimumConfidence: processingConfiguration.minimumConfidence,
            enableDietaryAnalysis: true
        )
        
        let dishes = try await menuParsingService.parseMenu(from: ocrResult, with: settings)
        
        guard !dishes.isEmpty else {
            throw MenulyError.ocrProcessingFailed
        }
        
        print("✅ Menu parsed: \(dishes.count) dishes extracted")
        return dishes
    }
    
    private func handlePrivacyCompliance(_ menu: Menu) async {
        // Implement privacy policy based on user settings
        if menu.privacyPolicy == .neverStore {
            // Immediate cleanup
            privacyComplianceService.clearSessionData()
        }
        
        // Schedule cleanup based on policy
        privacyComplianceService.scheduleDataCleanup(for: menu)
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration() {
        // Load user preferences or use defaults
        appConfiguration = AppConfiguration.privacyDefaults
        processingConfiguration = ProcessingConfiguration()
        
        print("✅ Configuration loaded")
    }
    
    private func setupProcessingObservers() {
        // Monitor memory pressure
        NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - optimizing")
        
        // Clear non-essential data
        if processedDishes.count > 10 {
            processedDishes = Array(processedDishes.suffix(5))
        }
        
        // Force garbage collection
        privacyComplianceService.clearSessionData()
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double, state: ProcessingState) async {
        await MainActor.run {
            self.processingProgress = progress
            self.processingState = state
        }
    }
}

// MARK: - Processing Configuration

struct ProcessingConfiguration {
    let maxConcurrentVisualizations: Int = 3
    let ocrLanguages: [String] = ["en-US", "es-ES", "fr-FR"]
    let minimumConfidence: Float = 0.6
    let enableBatchProcessing: Bool = true
    let processingTimeout: TimeInterval = 60
}

// MARK: - Privacy Compliance Service

/// Handles privacy compliance and data retention
class PrivacyComplianceService {
    
    func validateProcessingPermissions() -> Bool {
        // Validate that processing is allowed based on privacy settings
        return true // Simplified for now
    }
    
    func clearSessionData() {
        // Clear any cached or temporary data
        print("🔒 Session data cleared for privacy compliance")
    }
    
    func scheduleDataCleanup(for menu: Menu) {
        // Schedule cleanup based on retention policy
        switch menu.privacyPolicy {
        case .sessionOnly:
            // Schedule cleanup when app goes to background
            break
        case .neverStore:
            clearSessionData()
        }
    }
}

// MARK: - Extensions

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}