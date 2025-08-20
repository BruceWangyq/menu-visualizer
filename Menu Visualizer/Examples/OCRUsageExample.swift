//
//  OCRUsageExample.swift
//  Menu Visualizer
//
//  Example implementation showing how to use the comprehensive OCR system
//

import Foundation
import SwiftUI
import UIKit

/// Example implementation demonstrating the comprehensive OCR system usage
@MainActor
class OCRUsageExample: ObservableObject {
    
    // MARK: - Services
    
    private let ocrService = OCRService()
    private let menuParsingService = MenuParsingService()
    private let imagePreprocessor = ImagePreprocessor()
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var currentStage = ""
    @Published var processingProgress: Double = 0.0
    @Published var extractedMenu: Menu?
    @Published var processingResults: ProcessingResults?
    @Published var errorMessage: String?
    
    // MARK: - Processing Results
    
    struct ProcessingResults {
        let ocrResult: OCRResult
        let menu: Menu
        let imageQuality: ImagePreprocessor.QualityAssessment
        let processingTime: TimeInterval
        let performanceMetrics: PerformanceMetrics
    }
    
    struct PerformanceMetrics {
        let imagePreprocessingTime: TimeInterval
        let ocrTime: TimeInterval
        let parsingTime: TimeInterval
        let totalTime: TimeInterval
        let memoryUsage: UInt64
        let confidenceScore: Float
    }
    
    // MARK: - Main Processing Method
    
    /// Process a menu image with comprehensive OCR analysis
    func processMenuImage(_ image: UIImage, scenario: ProcessingScenario = .standard) async {
        await MainActor.run {
            isProcessing = true
            currentStage = "Starting processing..."
            processingProgress = 0.0
            errorMessage = nil
            extractedMenu = nil
            processingResults = nil
        }
        
        let startTime = Date()
        
        do {
            // Step 1: Quality Assessment
            await updateStage("Assessing image quality...", progress: 0.1)
            let imageQuality = await imagePreprocessor.assessImageQuality(image)
            
            guard imageQuality.score >= 0.3 else {
                await handleError(.lowConfidenceOCR(imageQuality.score))
                return
            }
            
            // Step 2: Get optimal configurations
            let ocrConfig = getOCRConfiguration(for: scenario, imageQuality: imageQuality)
            let parsingConfig = getParsingConfiguration(for: scenario)
            
            // Step 3: OCR Processing
            await updateStage("Extracting text from image...", progress: 0.2)
            let ocrStartTime = Date()
            
            let ocrResult = await ocrService.extractText(from: image, configuration: ocrConfig)
            let ocrTime = Date().timeIntervalSince(ocrStartTime)
            
            switch ocrResult {
            case .success(let result):
                // Step 4: Menu Parsing
                await updateStage("Parsing menu structure...", progress: 0.6)
                let parsingStartTime = Date()
                
                let menuResult = await menuParsingService.extractDishes(from: result, configuration: parsingConfig)
                let parsingTime = Date().timeIntervalSince(parsingStartTime)
                
                switch menuResult {
                case .success(let menu):
                    // Step 5: Create results
                    let totalTime = Date().timeIntervalSince(startTime)
                    
                    let performanceMetrics = PerformanceMetrics(
                        imagePreprocessingTime: 0.0, // Would be tracked in preprocessing
                        ocrTime: ocrTime,
                        parsingTime: parsingTime,
                        totalTime: totalTime,
                        memoryUsage: estimateMemoryUsage(for: image),
                        confidenceScore: menu.ocrConfidence
                    )
                    
                    let results = ProcessingResults(
                        ocrResult: result,
                        menu: menu,
                        imageQuality: imageQuality,
                        processingTime: totalTime,
                        performanceMetrics: performanceMetrics
                    )
                    
                    await MainActor.run {
                        self.extractedMenu = menu
                        self.processingResults = results
                        self.currentStage = "Processing completed successfully!"
                        self.processingProgress = 1.0
                    }
                    
                case .failure(let error):
                    await handleError(error)
                }
                
            case .failure(let error):
                await handleError(error)
            }
            
        } catch {
            await handleError(.unknownError(error.localizedDescription))
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    // MARK: - Configuration Methods
    
    private func getOCRConfiguration(for scenario: ProcessingScenario, imageQuality: ImagePreprocessor.QualityAssessment) -> OCRService.OCRConfiguration {
        
        switch scenario {
        case .quickPreview:
            return .performance
            
        case .standard:
            return .default
            
        case .highAccuracy:
            return .menuOptimized
            
        case .lowQualityImage:
            return OCRService.OCRConfiguration(
                quality: .maximum,
                languages: ["en-US", "es-ES", "fr-FR"],
                enableLayoutAnalysis: true,
                enableRegionDetection: true,
                minimumConfidence: 0.1,
                maxProcessingTime: 60.0
            )
            
        case .multiLanguage:
            return OCRService.OCRConfiguration(
                quality: .accurate,
                languages: ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT"],
                enableLayoutAnalysis: true,
                enableRegionDetection: true,
                minimumConfidence: 0.2,
                maxProcessingTime: 45.0
            )
        }
    }
    
    private func getParsingConfiguration(for scenario: ProcessingScenario) -> MenuParsingService.ParsingConfiguration {
        
        switch scenario {
        case .quickPreview:
            return .fast
            
        case .standard:
            return .default
            
        case .highAccuracy, .lowQualityImage, .multiLanguage:
            return .comprehensive
        }
    }
    
    // MARK: - Processing Scenarios
    
    enum ProcessingScenario {
        case quickPreview      // Fast processing for live preview
        case standard          // Balanced processing for normal use
        case highAccuracy      // Maximum accuracy for detailed analysis
        case lowQualityImage   // Enhanced processing for poor quality images
        case multiLanguage     // Multi-language menu processing
    }
    
    // MARK: - Helper Methods
    
    private func updateStage(_ stage: String, progress: Double) async {
        await MainActor.run {
            self.currentStage = stage
            self.processingProgress = progress
        }
    }
    
    private func handleError(_ error: MenulyError) async {
        await MainActor.run {
            self.errorMessage = error.localizedDescription
            self.currentStage = "Processing failed"
            self.isProcessing = false
        }
    }
    
    private func estimateMemoryUsage(for image: UIImage) -> UInt64 {
        let imageSize = image.size
        let bytesPerPixel: UInt64 = 4 // RGBA
        let scale = image.scale
        let pixels = UInt64(imageSize.width * scale * imageSize.height * scale)
        return pixels * bytesPerPixel
    }
    
    // MARK: - Quality Assessment Methods
    
    /// Perform comprehensive quality assessment of an image
    func assessImageQuality(_ image: UIImage) async -> ImagePreprocessor.QualityAssessment {
        return await imagePreprocessor.assessImageQuality(image)
    }
    
    /// Get processing time estimate for given image and configuration
    func estimateProcessingTime(for image: UIImage, scenario: ProcessingScenario) -> TimeInterval {
        let imageQuality = scenario == .lowQualityImage ? OCRService.OCRQuality.maximum : .balanced
        return ocrService.estimateProcessingTime(for: image.size, quality: imageQuality)
    }
    
    // MARK: - Advanced Features
    
    /// Process image with custom configurations
    func processWithCustomConfiguration(
        image: UIImage,
        ocrConfig: OCRService.OCRConfiguration,
        parsingConfig: MenuParsingService.ParsingConfiguration
    ) async -> Result<Menu, MenulyError> {
        
        let ocrResult = await ocrService.extractText(from: image, configuration: ocrConfig)
        
        switch ocrResult {
        case .success(let ocrData):
            return await menuParsingService.extractDishes(from: ocrData, configuration: parsingConfig)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// Extract only OCR text without menu parsing
    func extractTextOnly(from image: UIImage) async -> Result<OCRResult, MenulyError> {
        return await ocrService.extractText(from: image, configuration: .default)
    }
    
    /// Cancel ongoing processing
    func cancelProcessing() {
        ocrService.cancelProcessing()
        menuParsingService.cancelProcessing()
        
        Task { @MainActor in
            self.isProcessing = false
            self.currentStage = "Processing cancelled"
            self.processingProgress = 0.0
        }
    }
}

// MARK: - SwiftUI Integration Example

struct OCRDemoView: View {
    @StateObject private var ocrExample = OCRUsageExample()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedScenario: OCRUsageExample.ProcessingScenario = .standard
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image Selection
                Button("Select Menu Image") {
                    showingImagePicker = true
                }
                .buttonStyle(.borderedProminent)
                
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipped()
                        .cornerRadius(10)
                }
                
                // Processing Scenario Selection
                Picker("Processing Mode", selection: $selectedScenario) {
                    Text("Quick Preview").tag(OCRUsageExample.ProcessingScenario.quickPreview)
                    Text("Standard").tag(OCRUsageExample.ProcessingScenario.standard)
                    Text("High Accuracy").tag(OCRUsageExample.ProcessingScenario.highAccuracy)
                    Text("Low Quality Image").tag(OCRUsageExample.ProcessingScenario.lowQualityImage)
                    Text("Multi-Language").tag(OCRUsageExample.ProcessingScenario.multiLanguage)
                }
                .pickerStyle(.segmented)
                
                // Processing Button
                Button("Process Menu") {
                    if let image = selectedImage {
                        Task {
                            await ocrExample.processMenuImage(image, scenario: selectedScenario)
                        }
                    }
                }
                .disabled(selectedImage == nil || ocrExample.isProcessing)
                .buttonStyle(.borderedProminent)
                
                // Progress Information
                if ocrExample.isProcessing {
                    VStack {
                        ProgressView(value: ocrExample.processingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text(ocrExample.currentStage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Results
                if let menu = ocrExample.extractedMenu {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Extracted \(menu.dishes.count) dishes")
                            .font(.headline)
                        
                        Text("Confidence: \(Int(menu.ocrConfidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let restaurant = menu.restaurantName {
                            Text("Restaurant: \(restaurant)")
                                .font(.caption)
                        }
                    }
                }
                
                // Error Display
                if let error = ocrExample.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("OCR Demo")
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

// MARK: - Image Picker (Simplified)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}