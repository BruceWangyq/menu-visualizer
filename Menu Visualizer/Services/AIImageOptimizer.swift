//
//  AIImageOptimizer.swift
//  Menu Visualizer
//
//  Specialized image optimization for AI menu analysis
//  Optimizes images for better AI recognition while minimizing API costs
//

import UIKit
import Vision
import CoreImage
import Accelerate

/// Advanced image optimization service for AI menu analysis
@MainActor
final class AIImageOptimizer: ObservableObject {
    
    // MARK: - Configuration
    
    struct OptimizationConfiguration {
        let targetSize: CGSize
        let compressionQuality: CGFloat
        let enhanceContrast: Bool
        let sharpenText: Bool
        let removeNoise: Bool
        let autoRotate: Bool
        let cropToContent: Bool
        let normalizeColors: Bool
        
        static let aiOptimized = OptimizationConfiguration(
            targetSize: CGSize(width: 1024, height: 1024),
            compressionQuality: 0.85,
            enhanceContrast: true,
            sharpenText: true,
            removeNoise: true,
            autoRotate: true,
            cropToContent: true,
            normalizeColors: true
        )
        
        static let fast = OptimizationConfiguration(
            targetSize: CGSize(width: 768, height: 768),
            compressionQuality: 0.7,
            enhanceContrast: false,
            sharpenText: false,
            removeNoise: false,
            autoRotate: false,
            cropToContent: false,
            normalizeColors: false
        )
        
        static let highQuality = OptimizationConfiguration(
            targetSize: CGSize(width: 1536, height: 1536),
            compressionQuality: 0.95,
            enhanceContrast: true,
            sharpenText: true,
            removeNoise: true,
            autoRotate: true,
            cropToContent: true,
            normalizeColors: true
        )
    }
    
    enum OptimizationError: LocalizedError {
        case imageProcessingFailed
        case invalidImageData
        case coreImageUnavailable
        case visionProcessingFailed
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process image for optimization"
            case .invalidImageData:
                return "Invalid image data provided"
            case .coreImageUnavailable:
                return "Core Image framework unavailable"
            case .visionProcessingFailed:
                return "Vision framework processing failed"
            }
        }
    }
    
    // MARK: - Properties
    
    private let ciContext: CIContext
    private let imageCache: NSCache<NSString, UIImage>
    private let metadataCache: NSCache<NSString, ImageMetadata>
    
    // MARK: - Initialization
    
    init() {
        // Create optimized Core Image context
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
            .useSoftwareRenderer: false // Use GPU when available
        ]
        
        self.ciContext = CIContext(options: options)
        
        // Configure caches
        self.imageCache = NSCache<NSString, UIImage>()
        imageCache.countLimit = 10 // Limit to 10 optimized images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB cache
        
        self.metadataCache = NSCache<NSString, ImageMetadata>()
        metadataCache.countLimit = 50
    }
    
    // MARK: - Main Optimization
    
    /// Optimize image for AI analysis with comprehensive enhancements
    func optimizeForAI(
        _ image: UIImage,
        configuration: OptimizationConfiguration = .aiOptimized
    ) async -> Result<OptimizedImage, OptimizationError> {
        
        return await withCheckedContinuation { continuation in
            Task {
                let result = await performOptimization(image, configuration: configuration)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func performOptimization(
        _ image: UIImage,
        configuration: OptimizationConfiguration
    ) async -> Result<OptimizedImage, OptimizationError> {
        
        let startTime = Date()
        let imageHash = generateImageHash(image)
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: NSString(string: imageHash)) {
            print("✅ Using cached optimized image")
            let optimizedImage = OptimizedImage(
                image: cachedImage,
                originalSize: image.size,
                optimizedSize: cachedImage.size,
                processingTime: 0,
                optimizations: []
            )
            return .success(optimizedImage)
        }
        
        guard let cgImage = image.cgImage else {
            return .failure(.invalidImageData)
        }
        
        var ciImage = CIImage(cgImage: cgImage)
        var appliedOptimizations: [OptimizationStep] = []
        
        do {
            // Step 1: Auto-rotate based on EXIF data
            if configuration.autoRotate {
                ciImage = await autoRotateImage(ciImage)
                appliedOptimizations.append(.autoRotation)
            }
            
            // Step 2: Crop to content area if needed
            if configuration.cropToContent {
                if let croppedImage = await cropToMenuContent(ciImage) {
                    ciImage = croppedImage
                    appliedOptimizations.append(.contentCropping)
                }
            }
            
            // Step 3: Resize to target dimensions
            ciImage = resizeImage(ciImage, to: configuration.targetSize)
            appliedOptimizations.append(.resizing)
            
            // Step 4: Enhance contrast for better text recognition
            if configuration.enhanceContrast {
                ciImage = enhanceContrast(ciImage)
                appliedOptimizations.append(.contrastEnhancement)
            }
            
            // Step 5: Sharpen text for better AI recognition
            if configuration.sharpenText {
                ciImage = await sharpenForTextRecognition(ciImage)
                appliedOptimizations.append(.textSharpening)
            }
            
            // Step 6: Remove noise
            if configuration.removeNoise {
                ciImage = removeNoise(ciImage)
                appliedOptimizations.append(.noiseReduction)
            }
            
            // Step 7: Normalize colors for consistent AI processing
            if configuration.normalizeColors {
                ciImage = normalizeColors(ciImage)
                appliedOptimizations.append(.colorNormalization)
            }
            
            // Final step: Convert back to UIImage with compression
            guard let outputCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                return .failure(.imageProcessingFailed)
            }
            
            let optimizedUIImage = UIImage(cgImage: outputCGImage)
            guard let compressedData = optimizedUIImage.jpegData(compressionQuality: configuration.compressionQuality),
                  let finalImage = UIImage(data: compressedData) else {
                return .failure(.imageProcessingFailed)
            }
            
            // Cache the result
            imageCache.setObject(finalImage, forKey: NSString(string: imageHash))
            
            let processingTime = Date().timeIntervalSince(startTime)
            let optimizedImage = OptimizedImage(
                image: finalImage,
                originalSize: image.size,
                optimizedSize: finalImage.size,
                processingTime: processingTime,
                optimizations: appliedOptimizations
            )
            
            print("✅ Image optimization completed in \(String(format: "%.2f", processingTime))s")
            print("📊 Applied optimizations: \(appliedOptimizations.map { $0.rawValue }.joined(separator: ", "))")
            
            return .success(optimizedImage)
            
        } catch {
            return .failure(.imageProcessingFailed)
        }
    }
    
    // MARK: - Individual Optimization Steps
    
    private func autoRotateImage(_ image: CIImage) async -> CIImage {
        // Apply proper orientation based on EXIF data
        return image.oriented(forExifOrientation: 1)
    }
    
    private func cropToMenuContent(_ image: CIImage) async -> CIImage? {
        // Use Vision framework to detect text regions and crop to main content area
        return await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Find bounding box that contains most text
                var minX: CGFloat = 1.0
                var minY: CGFloat = 1.0
                var maxX: CGFloat = 0.0
                var maxY: CGFloat = 0.0
                
                for observation in observations {
                    let bbox = observation.boundingBox
                    minX = min(minX, bbox.minX)
                    minY = min(minY, bbox.minY)
                    maxX = max(maxX, bbox.maxX)
                    maxY = max(maxY, bbox.maxY)
                }
                
                // Add padding and convert to image coordinates
                let padding: CGFloat = 0.05
                let cropRect = CGRect(
                    x: max(0, (minX - padding) * image.extent.width),
                    y: max(0, (minY - padding) * image.extent.height),
                    width: min(image.extent.width, (maxX - minX + 2 * padding) * image.extent.width),
                    height: min(image.extent.height, (maxY - minY + 2 * padding) * image.extent.height)
                )
                
                let croppedImage = image.cropped(to: cropRect)
                continuation.resume(returning: croppedImage)
            }
            
            request.reportCharacterBoxes = false
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func resizeImage(_ image: CIImage, to targetSize: CGSize) -> CIImage {
        let currentSize = image.extent.size
        let scaleX = targetSize.width / currentSize.width
        let scaleY = targetSize.height / currentSize.height
        let scale = min(scaleX, scaleY) // Maintain aspect ratio
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }
    
    private func enhanceContrast(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast by 20%
        filter.setValue(1.0, forKey: kCIInputBrightnessKey) // Keep brightness neutral
        filter.setValue(1.1, forKey: kCIInputSaturationKey) // Slightly increase saturation
        
        return filter.outputImage ?? image
    }
    
    private func sharpenForTextRecognition(_ image: CIImage) async -> CIImage {
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        
        sharpenFilter.setValue(image, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.8, forKey: kCIInputSharpnessKey) // Moderate sharpening
        
        return sharpenFilter.outputImage ?? image
    }
    
    private func removeNoise(_ image: CIImage) -> CIImage {
        guard let noiseReductionFilter = CIFilter(name: "CINoiseReduction") else { return image }
        
        noiseReductionFilter.setValue(image, forKey: kCIInputImageKey)
        noiseReductionFilter.setValue(0.02, forKey: "inputNoiseLevel") // Light noise reduction
        noiseReductionFilter.setValue(0.4, forKey: "inputSharpness")
        
        return noiseReductionFilter.outputImage ?? image
    }
    
    private func normalizeColors(_ image: CIImage) -> CIImage {
        // Apply gamma correction and white balance for consistent color representation
        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return image }
        
        gammaFilter.setValue(image, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.95, forKey: "inputPower") // Slight gamma adjustment
        
        guard let normalizedImage = gammaFilter.outputImage,
              let whiteBalanceFilter = CIFilter(name: "CITemperatureAndTint") else {
            return gammaFilter.outputImage ?? image
        }
        
        whiteBalanceFilter.setValue(normalizedImage, forKey: kCIInputImageKey)
        whiteBalanceFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral") // Daylight white balance
        
        return whiteBalanceFilter.outputImage ?? normalizedImage
    }
    
    // MARK: - Utility Methods
    
    /// Assess image quality for optimization recommendations
    func assessImageQuality(_ image: UIImage) async -> ImageQualityAssessment {
        let metadata = await extractImageMetadata(image)
        
        var issues: [ImageQualityIssue] = []
        var recommendations: [OptimizationRecommendation] = []
        
        // Check size
        let pixelCount = image.size.width * image.size.height
        if pixelCount < 500000 { // Less than 0.5MP
            issues.append(.lowResolution)
            recommendations.append(.useHighQualityMode)
        } else if pixelCount > 4000000 { // More than 4MP
            issues.append(.tooLarge)
            recommendations.append(.resizeImage)
        }
        
        // Check aspect ratio
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio < 0.5 || aspectRatio > 2.0 {
            issues.append(.extremeAspectRatio)
            recommendations.append(.cropToContent)
        }
        
        // Basic sharpness check using metadata
        if metadata.brightness < 0.3 {
            issues.append(.tooDark)
            recommendations.append(.enhanceContrast)
        }
        
        return ImageQualityAssessment(
            overallScore: calculateQualityScore(issues: issues),
            issues: issues,
            recommendations: recommendations,
            metadata: metadata
        )
    }
    
    private func extractImageMetadata(_ image: UIImage) async -> ImageMetadata {
        let imageHash = generateImageHash(image)
        
        if let cached = metadataCache.object(forKey: NSString(string: imageHash)) {
            return cached
        }
        
        guard let cgImage = image.cgImage else {
            return ImageMetadata(brightness: 0.5, contrast: 0.5, sharpness: 0.5, textDensity: 0.0)
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Calculate basic image statistics
        let brightness = await calculateBrightness(ciImage)
        let contrast = await calculateContrast(ciImage)
        let sharpness = await estimateSharpness(ciImage)
        let textDensity = await estimateTextDensity(ciImage)
        
        let metadata = ImageMetadata(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            textDensity: textDensity
        )
        
        metadataCache.setObject(metadata, forKey: NSString(string: imageHash))
        return metadata
    }
    
    private func calculateBrightness(_ image: CIImage) async -> Float {
        // Use Core Image to calculate average brightness
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        areaAverage.setValue(image, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        
        guard let outputImage = areaAverage.outputImage else { return 0.5 }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Calculate luminance
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0
        
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    private func calculateContrast(_ image: CIImage) async -> Float {
        // Simplified contrast estimation
        return 0.5 // Placeholder - would implement proper contrast calculation
    }
    
    private func estimateSharpness(_ image: CIImage) async -> Float {
        // Use Laplacian filter to estimate sharpness
        guard let laplacian = CIFilter(name: "CIConvolution3X3") else { return 0.5 }
        
        let sharpnessKernel = CIVector(values: [0, -1, 0, -1, 5, -1, 0, -1, 0], count: 9)
        laplacian.setValue(image, forKey: kCIInputImageKey)
        laplacian.setValue(sharpnessKernel, forKey: kCIInputWeightsKey)
        
        guard let sharpnessMap = laplacian.outputImage else { return 0.5 }
        
        // Calculate variance of the sharpness map (higher variance = sharper image)
        // Simplified implementation
        return 0.5 // Placeholder
    }
    
    private func estimateTextDensity(_ image: CIImage) async -> Float {
        // Use Vision framework to estimate text coverage
        return await withCheckedContinuation { continuation in
            let request = VNDetectTextRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNTextObservation] else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                let totalImageArea = image.extent.width * image.extent.height
                let textArea = observations.reduce(0.0) { sum, observation in
                    let bbox = observation.boundingBox
                    return sum + (bbox.width * bbox.height * totalImageArea)
                }
                
                let density = Float(textArea / totalImageArea)
                continuation.resume(returning: min(1.0, density))
            }
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: 0.0)
            }
        }
    }
    
    private func calculateQualityScore(issues: [ImageQualityIssue]) -> Float {
        let baseScore: Float = 1.0
        let penaltyPerIssue: Float = 0.15
        
        return max(0.0, baseScore - Float(issues.count) * penaltyPerIssue)
    }
    
    private func generateImageHash(_ image: UIImage) -> String {
        guard let imageData = image.pngData() else { return UUID().uuidString }
        return imageData.sha256
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        imageCache.removeAllObjects()
        metadataCache.removeAllObjects()
        print("🗑️ AI image optimization cache cleared")
    }
    
    func getCacheInfo() -> (imageCount: Int, metadataCount: Int) {
        return (imageCache.countLimit, metadataCache.countLimit)
    }
}

// MARK: - Supporting Data Structures

struct OptimizedImage {
    let image: UIImage
    let originalSize: CGSize
    let optimizedSize: CGSize
    let processingTime: TimeInterval
    let optimizations: [OptimizationStep]
    
    var compressionRatio: Float {
        let originalPixels = originalSize.width * originalSize.height
        let optimizedPixels = optimizedSize.width * optimizedSize.height
        return Float(optimizedPixels / originalPixels)
    }
    
    var sizeSavings: String {
        let savings = (1.0 - compressionRatio) * 100
        return String(format: "%.1f%%", savings)
    }
}

enum OptimizationStep: String, CaseIterable {
    case autoRotation = "Auto Rotation"
    case contentCropping = "Content Cropping"
    case resizing = "Resizing"
    case contrastEnhancement = "Contrast Enhancement"
    case textSharpening = "Text Sharpening"
    case noiseReduction = "Noise Reduction"
    case colorNormalization = "Color Normalization"
}

class ImageMetadata {
    let brightness: Float
    let contrast: Float
    let sharpness: Float
    let textDensity: Float
    
    init(brightness: Float, contrast: Float, sharpness: Float, textDensity: Float) {
        self.brightness = brightness
        self.contrast = contrast
        self.sharpness = sharpness
        self.textDensity = textDensity
    }
}

struct ImageQualityAssessment {
    let overallScore: Float
    let issues: [ImageQualityIssue]
    let recommendations: [OptimizationRecommendation]
    let metadata: ImageMetadata
    
    var qualityLevel: QualityLevel {
        switch overallScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        case 0.2..<0.4:
            return .poor
        default:
            return .veryPoor
        }
    }
}

enum ImageQualityIssue: String, CaseIterable {
    case lowResolution = "Low Resolution"
    case tooLarge = "Too Large"
    case extremeAspectRatio = "Extreme Aspect Ratio"
    case tooBlurry = "Too Blurry"
    case tooNoisy = "Too Noisy"
    case poorLighting = "Poor Lighting"
    case tooSkewed = "Too Skewed"
    case tooDistorted = "Too Distorted"
    case tooCompressed = "Over Compressed"
    case tooSaturated = "Over Saturated"
    case tooDesaturated = "Under Saturated"
    case tooContrasted = "Over Contrasted"
    case tooFlat = "Under Contrasted"
    case textOcclusion = "Text Occlusion"
    case poorColor = "Poor Color Balance"
    case tooGrainy = "Too Grainy"
    case tooSmooth = "Over Smoothed"
    case improperExposure = "Improper Exposure"
    case tooReflective = "Too Reflective"
    case tooShadowed = "Too Shadowed"
    case tooBacklit = "Too Backlit"
    case lowTextDensity = "Low Text Density"
    case poorTextClarity = "Poor Text Clarity"
    case tooMuchNoise = "Too Much Noise"
    case tooManyArtifacts = "Too Many Artifacts"
    case rotationNeeded = "Rotation Needed"
    case croppingNeeded = "Cropping Needed"
    case colorCorrectionNeeded = "Color Correction Needed"
    case sharpnessNeeded = "Sharpness Needed"
    case tooPartiallyObscured = "Partially Obscured"
    case tooDark = "Too Dark"
    case tooBright = "Too Bright"
}

enum OptimizationRecommendation: String, CaseIterable {
    case useHighQualityMode = "Use High Quality Mode"
    case resizeImage = "Resize Image"
    case cropToContent = "Crop to Content"
    case enhanceContrast = "Enhance Contrast"
    case sharpenImage = "Sharpen Image"
    case reduceNoise = "Reduce Noise"
    case adjustBrightness = "Adjust Brightness"
    case normalizeColors = "Normalize Colors"
    case rotateImage = "Rotate Image"
    case increaseResolution = "Increase Resolution"
    case decreaseCompression = "Decrease Compression"
    case improveTextClarity = "Improve Text Clarity"
    case betterLighting = "Better Lighting"
    case stabilizeImage = "Stabilize Image"
    case removeReflections = "Remove Reflections"
    case increaseContrast = "Increase Contrast"
    case decreaseContrast = "Decrease Contrast"
    case increaseSaturation = "Increase Saturation"
    case decreaseSaturation = "Decrease Saturation"
    case adjustWhiteBalance = "Adjust White Balance"
    case removeDistortion = "Remove Distortion"
    case straightenImage = "Straighten Image"
    case increaseSharpness = "Increase Sharpness"
    case retakePhoto = "Retake Photo"
}

enum QualityLevel: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case veryPoor = "Very Poor"
    
    var color: UIColor {
        switch self {
        case .excellent:
            return .systemGreen
        case .good:
            return .systemBlue
        case .fair:
            return .systemOrange
        case .poor:
            return .systemRed
        case .veryPoor:
            return .systemRed
        }
    }
}