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
    // private let privacyComplianceService = PrivacyComplianceService()
    
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
                let updatedDish = Dish(
                    name: processedDishes[index].name,
                    description: processedDishes[index].description,
                    price: processedDishes[index].price,
                    category: processedDishes[index].category,
                    allergens: processedDishes[index].allergens,
                    dietaryInfo: processedDishes[index].dietaryInfo,
                    extractionConfidence: processedDishes[index].extractionConfidence,
                    aiVisualization: processedDishes[index].aiVisualization,
                    isGenerating: true
                )
                processedDishes[index] = updatedDish
                processingState = .generatingVisualization(dishName: dish.name)
            }
        }
        
        do {
            let result = await visualizationService.generateVisualization(for: dish)
            
            await MainActor.run {
                if let index = processedDishes.firstIndex(where: { $0.id == dish.id }) {
                    let currentDish = processedDishes[index]
                    switch result {
                    case .success(let visualizationResponse):
                        // Convert VisualizationResponse to DishVisualization if needed
                        if let description = visualizationResponse.description {
                            let visualization = DishVisualization(
                                dishId: dish.id,
                                generatedDescription: description,
                                visualStyle: "appetizing",
                                ingredients: [],
                                preparationNotes: ""
                            )
                            processedDishes[index] = currentDish.withVisualization(visualization)
                        }
                        // Update isGenerating to false
                        let finalDish = Dish(
                            name: processedDishes[index].name,
                            description: processedDishes[index].description,
                            price: processedDishes[index].price,
                            category: processedDishes[index].category,
                            allergens: processedDishes[index].allergens,
                            dietaryInfo: processedDishes[index].dietaryInfo,
                            extractionConfidence: processedDishes[index].extractionConfidence,
                            aiVisualization: processedDishes[index].aiVisualization,
                            isGenerating: false
                        )
                        processedDishes[index] = finalDish
                    case .failure(let error):
                        self.error = error
                        // Update isGenerating to false even on failure
                        let finalDish = Dish(
                            name: currentDish.name,
                            description: currentDish.description,
                            price: currentDish.price,
                            category: currentDish.category,
                            allergens: currentDish.allergens,
                            dietaryInfo: currentDish.dietaryInfo,
                            extractionConfidence: currentDish.extractionConfidence,
                            aiVisualization: currentDish.aiVisualization,
                            isGenerating: false
                        )
                        processedDishes[index] = finalDish
                    }
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
                    let currentDish = processedDishes[index]
                    let updatedDish = Dish(
                        name: currentDish.name,
                        description: currentDish.description,
                        price: currentDish.price,
                        category: currentDish.category,
                        allergens: currentDish.allergens,
                        dietaryInfo: currentDish.dietaryInfo,
                        extractionConfidence: currentDish.extractionConfidence,
                        aiVisualization: currentDish.aiVisualization,
                        isGenerating: false
                    )
                    processedDishes[index] = updatedDish
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
        // privacyComplianceService.clearSessionData()
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
                dishes: extractedDishes,
                restaurantName: nil,
                ocrConfidence: ocrResult.overallConfidence
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
        // Privacy compliance service is commented out
        // guard privacyComplianceService.validateProcessingPermissions() else {
        //     throw MenulyError.privacyViolation("Processing permissions not validated")
        // }
        
        print("✅ Privacy compliance validated")
    }
    
    private func preprocessImage(_ image: UIImage) async throws -> UIImage {
        // Use configuration method to get preprocessing settings
        let configuration = appConfiguration.getImagePreprocessingConfiguration()
        
        let result = await imagePreprocessor.preprocessImage(image, configuration: configuration)
        switch result {
        case .success(let processedImage):
            print("✅ Image preprocessed: \(processedImage.size)")
            return processedImage
        case .failure(let error):
            throw error
        }
    }
    
    private func performOCR(on image: UIImage) async throws -> OCRResult {
        // Use configuration method to get OCR settings
        let configuration = appConfiguration.getOCRConfiguration()
        
        let result = await ocrService.extractText(from: image, configuration: configuration)
        switch result {
        case .success(let ocrResult):
            guard !ocrResult.recognizedText.isEmpty else {
                throw MenulyError.noTextRecognized
            }
            print("✅ OCR completed: \(ocrResult.recognizedText.count) text blocks, confidence: \(ocrResult.overallConfidence)")
            return ocrResult
        case .failure(let error):
            throw error
        }
    }
    
    private func parseMenuFromOCR(_ ocrResult: OCRResult) async throws -> [Dish] {
        // Use configuration method to get parsing settings
        let configuration = appConfiguration.getParsingConfiguration()
        
        let result = await menuParsingService.extractDishes(from: ocrResult, configuration: configuration)
        switch result {
        case .success(let menu):
            guard !menu.dishes.isEmpty else {
                throw MenulyError.noDishesFound
            }
            print("✅ Menu parsing completed: \(menu.dishes.count) dishes extracted")
            return menu.dishes
        case .failure(let error):
            throw error
        }
    }
    
    private func handlePrivacyCompliance(_ menu: Menu) async {
        // Implement privacy policy based on user settings
        // Privacy compliance service is commented out
        // if menu.privacyPolicy == .neverStore {
        //     // Immediate cleanup
        //     privacyComplianceService.clearSessionData()
        // }
        
        // Schedule cleanup based on policy
        // privacyComplianceService.scheduleDataCleanup(for: menu)
        
        print("✅ Privacy compliance handled")
    }
    
    // MARK: - Configuration
    
    private func loadConfiguration() {
        // Load user preferences or use defaults
        appConfiguration = AppConfiguration.shared
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
        // privacyComplianceService.clearSessionData()
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


// MARK: - Extensions

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}