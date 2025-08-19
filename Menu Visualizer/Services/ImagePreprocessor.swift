//
//  ImagePreprocessor.swift
//  Menu Visualizer
//
//  Advanced image preprocessing for optimal OCR accuracy
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// Advanced image preprocessing service for optimal OCR results
final class ImagePreprocessor {
    
    // MARK: - Configuration
    
    struct ProcessingConfiguration {
        let maxImageSize: CGSize
        let jpegCompressionQuality: CGFloat
        let contrastBoost: Float
        let brightnessAdjustment: Float
        let sharpenIntensity: Float
        let noiseReductionLevel: Float
        
        static let `default` = ProcessingConfiguration(
            maxImageSize: CGSize(width: 2048, height: 2048),
            jpegCompressionQuality: 0.9,
            contrastBoost: 1.2,
            brightnessAdjustment: 0.0,
            sharpenIntensity: 0.5,
            noiseReductionLevel: 0.3
        )
        
        static let highQuality = ProcessingConfiguration(
            maxImageSize: CGSize(width: 4096, height: 4096),
            jpegCompressionQuality: 0.95,
            contrastBoost: 1.1,
            brightnessAdjustment: 0.0,
            sharpenIntensity: 0.3,
            noiseReductionLevel: 0.2
        )
        
        static let performance = ProcessingConfiguration(
            maxImageSize: CGSize(width: 1024, height: 1024),
            jpegCompressionQuality: 0.8,
            contrastBoost: 1.3,
            brightnessAdjustment: 0.1,
            sharpenIntensity: 0.7,
            noiseReductionLevel: 0.4
        )
    }
    
    enum QualityAssessment {
        case excellent(score: Float)
        case good(score: Float)
        case fair(score: Float, suggestions: [String])
        case poor(score: Float, suggestions: [String])
        
        var score: Float {
            switch self {
            case .excellent(let score), .good(let score), .fair(let score, _), .poor(let score, _):
                return score
            }
        }
        
        var suggestions: [String] {
            switch self {
            case .fair(_, let suggestions), .poor(_, let suggestions):
                return suggestions
            default:
                return []
            }
        }
    }
    
    // MARK: - Core Processing
    
    private let ciContext: CIContext
    private let processingQueue = DispatchQueue(label: "com.menuly.imageprocessing", qos: .userInitiated)
    
    init() {
        // Configure Core Image context for optimal performance
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false
        ]
        self.ciContext = CIContext(options: options)
    }
    
    /// Main preprocessing method with automatic optimization
    func preprocessImage(
        _ image: UIImage,
        configuration: ProcessingConfiguration = .default,
        progressHandler: ((Double) -> Void)? = nil
    ) async -> Result<UIImage, MenulyError> {
        
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .failure(.ocrProcessingFailed))
                    return
                }
                
                let result = self.performImagePreprocessing(
                    image,
                    configuration: configuration,
                    progressHandler: progressHandler
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performImagePreprocessing(
        _ image: UIImage,
        configuration: ProcessingConfiguration,
        progressHandler: ((Double) -> Void)?
    ) -> Result<UIImage, MenulyError> {
        
        guard let ciImage = CIImage(image: image) else {
            return .failure(.ocrProcessingFailed)
        }
        
        progressHandler?(0.1)
        
        var processedImage = ciImage
        
        // Step 1: Orientation correction
        processedImage = correctOrientation(processedImage)
        progressHandler?(0.2)
        
        // Step 2: Resize for optimal processing
        processedImage = resizeImage(processedImage, maxSize: configuration.maxImageSize)
        progressHandler?(0.3)
        
        // Step 3: Noise reduction
        if configuration.noiseReductionLevel > 0 {
            processedImage = applyNoiseReduction(processedImage, level: configuration.noiseReductionLevel)
        }
        progressHandler?(0.5)
        
        // Step 4: Contrast and brightness optimization
        processedImage = enhanceContrast(
            processedImage,
            contrast: configuration.contrastBoost,
            brightness: configuration.brightnessAdjustment
        )
        progressHandler?(0.7)
        
        // Step 5: Sharpening for text clarity
        if configuration.sharpenIntensity > 0 {
            processedImage = applySharpen(processedImage, intensity: configuration.sharpenIntensity)
        }
        progressHandler?(0.9)
        
        // Step 6: Convert back to UIImage
        guard let cgImage = ciContext.createCGImage(processedImage, from: processedImage.extent) else {
            return .failure(.ocrProcessingFailed)
        }
        
        let finalImage = UIImage(cgImage: cgImage)
        progressHandler?(1.0)
        
        return .success(finalImage)
    }
    
    // MARK: - Processing Steps
    
    private func correctOrientation(_ image: CIImage) -> CIImage {
        return image.oriented(.up)
    }
    
    private func resizeImage(_ image: CIImage, maxSize: CGSize) -> CIImage {
        let imageSize = image.extent.size
        
        // Calculate scale factor to fit within maxSize while maintaining aspect ratio
        let widthScale = maxSize.width / imageSize.width
        let heightScale = maxSize.height / imageSize.height
        let scale = min(widthScale, heightScale, 1.0) // Don't upscale
        
        if scale < 1.0 {
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            return image.transformed(by: transform)
        }
        
        return image
    }
    
    private func applyNoiseReduction(_ image: CIImage, level: Float) -> CIImage {
        let filter = CIFilter.noiseReduction()
        filter.inputImage = image
        filter.noiseLevel = level
        filter.sharpness = 0.8
        
        return filter.outputImage ?? image
    }
    
    private func enhanceContrast(_ image: CIImage, contrast: Float, brightness: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = contrast
        filter.brightness = brightness
        filter.saturation = 0.9 // Slightly reduce saturation for better text recognition
        
        return filter.outputImage ?? image
    }
    
    private func applySharpen(_ image: CIImage, intensity: Float) -> CIImage {
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = intensity
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Quality Assessment
    
    /// Assess image quality for OCR suitability
    func assessImageQuality(_ image: UIImage) async -> QualityAssessment {
        
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .poor(score: 0.0, suggestions: ["Processing failed"]))
                    return
                }
                
                let assessment = self.performQualityAssessment(image)
                continuation.resume(returning: assessment)
            }
        }
    }
    
    private func performQualityAssessment(_ image: UIImage) -> QualityAssessment {
        guard let ciImage = CIImage(image: image) else {
            return .poor(score: 0.0, suggestions: ["Invalid image format"])
        }
        
        var score: Float = 1.0
        var suggestions: [String] = []
        
        // Check image resolution
        let imageSize = ciImage.extent.size
        let megapixels = (imageSize.width * imageSize.height) / (1024 * 1024)
        
        if megapixels < 1.0 {
            score -= 0.3
            suggestions.append("Image resolution is low. Try moving closer to the menu.")
        } else if megapixels > 12.0 {
            score -= 0.1
            suggestions.append("Very high resolution image may slow processing.")
        }
        
        // Check aspect ratio (extreme ratios might indicate poor framing)
        let aspectRatio = imageSize.width / imageSize.height
        if aspectRatio > 3.0 || aspectRatio < 0.33 {
            score -= 0.2
            suggestions.append("Consider reframing the menu for better coverage.")
        }
        
        // Assess brightness and contrast
        let (brightness, contrast) = calculateBrightnessAndContrast(ciImage)
        
        if brightness < 0.2 {
            score -= 0.4
            suggestions.append("Image is too dark. Try better lighting or adjust camera settings.")
        } else if brightness > 0.9 {
            score -= 0.3
            suggestions.append("Image is overexposed. Reduce lighting or adjust camera settings.")
        }
        
        if contrast < 0.3 {
            score -= 0.3
            suggestions.append("Low contrast detected. Ensure clear lighting and avoid glare.")
        }
        
        // Check for blur using Laplacian variance
        let sharpness = calculateSharpness(ciImage)
        if sharpness < 50.0 {
            score -= 0.5
            suggestions.append("Image appears blurry. Hold the camera steady and ensure focus.")
        }
        
        // Determine quality level
        switch score {
        case 0.8...1.0:
            return .excellent(score: score)
        case 0.6..<0.8:
            return .good(score: score)
        case 0.4..<0.6:
            return .fair(score: score, suggestions: suggestions)
        default:
            return .poor(score: score, suggestions: suggestions)
        }
    }
    
    private func calculateBrightnessAndContrast(_ image: CIImage) -> (brightness: Float, contrast: Float) {
        // Use area average filter to get overall brightness
        let extent = image.extent
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = image
        averageFilter.extent = extent
        
        guard let output = averageFilter.outputImage else {
            return (0.5, 0.5)
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        let brightness = Float(bitmap[0]) / 255.0
        
        // Simple contrast estimation (would need more sophisticated algorithm for production)
        let contrast = Float(0.5) // Simplified for now
        
        return (brightness, contrast)
    }
    
    private func calculateSharpness(_ image: CIImage) -> Float {
        // Apply Laplacian filter for edge detection
        let kernel = CIKernel.gaussianBlur() // Simplified - would use custom Laplacian kernel
        // This is a simplified sharpness calculation
        // In production, you'd implement a proper Laplacian variance calculation
        return 100.0 // Placeholder value
    }
    
    // MARK: - Utility Methods
    
    /// Extract memory usage for monitoring
    func estimateMemoryUsage(for imageSize: CGSize) -> UInt64 {
        let bytesPerPixel: UInt64 = 4 // RGBA
        let pixels = UInt64(imageSize.width * imageSize.height)
        return pixels * bytesPerPixel
    }
    
    /// Optimize image for specific menu types
    func getOptimalConfiguration(for menuType: MenuType) -> ProcessingConfiguration {
        switch menuType {
        case .printed:
            return .default
        case .handwritten:
            return ProcessingConfiguration(
                maxImageSize: CGSize(width: 3072, height: 3072),
                jpegCompressionQuality: 0.95,
                contrastBoost: 1.4,
                brightnessAdjustment: 0.1,
                sharpenIntensity: 0.8,
                noiseReductionLevel: 0.2
            )
        case .digital:
            return .performance
        case .lowLight:
            return ProcessingConfiguration(
                maxImageSize: CGSize(width: 2048, height: 2048),
                jpegCompressionQuality: 0.9,
                contrastBoost: 1.5,
                brightnessAdjustment: 0.3,
                sharpenIntensity: 0.6,
                noiseReductionLevel: 0.5
            )
        }
    }
    
    enum MenuType {
        case printed
        case handwritten
        case digital
        case lowLight
    }
}

// MARK: - Extensions

extension ImagePreprocessor.QualityAssessment: CustomStringConvertible {
    var description: String {
        switch self {
        case .excellent(let score):
            return "Excellent quality (Score: \(String(format: "%.1f", score * 100))%)"
        case .good(let score):
            return "Good quality (Score: \(String(format: "%.1f", score * 100))%)"
        case .fair(let score, _):
            return "Fair quality (Score: \(String(format: "%.1f", score * 100))%)"
        case .poor(let score, _):
            return "Poor quality (Score: \(String(format: "%.1f", score * 100))%)"
        }
    }
}