//
//  PerformanceOptimizationService.swift
//  Menu Visualizer
//
//  Performance optimization and memory management service
//

import Foundation
import SwiftUI
import UIKit
import OSLog

/// Service managing performance optimization and memory efficiency
@MainActor
final class PerformanceOptimizationService: ObservableObject {
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var performanceMetrics: PerformanceMetrics?
    @Published var optimizationLevel: OptimizationLevel = .balanced
    
    private let logger = Logger(subsystem: "com.menuly.performance", category: "Optimization")
    private var memoryTimer: Timer?
    private var performanceHistory: [PerformanceSnapshot] = []
    
    // MARK: - Performance Configuration
    
    enum OptimizationLevel: String, CaseIterable {
        case conservative = "Conservative"
        case balanced = "Balanced"
        case aggressive = "Aggressive"
        
        var description: String {
            switch self {
            case .conservative:
                return "Prioritizes stability and compatibility"
            case .balanced:
                return "Balanced performance and resource usage"
            case .aggressive:
                return "Maximum performance, higher resource usage"
            }
        }
        
        var imageCompressionQuality: CGFloat {
            switch self {
            case .conservative: return 0.9
            case .balanced: return 0.8
            case .aggressive: return 0.7
            }
        }
        
        var maxImageDimension: CGFloat {
            switch self {
            case .conservative: return 1024
            case .balanced: return 1536
            case .aggressive: return 2048
            }
        }
        
        var ocrAccuracyLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .conservative: return .fast
            case .balanced: return .accurate
            case .aggressive: return .accurate
            }
        }
    }
    
    // MARK: - Performance Snapshot
    
    struct PerformanceSnapshot {
        let timestamp: Date
        let memoryUsage: UInt64
        let cpuUsage: Double
        let operation: String
        let duration: TimeInterval
        
        var memoryUsageMB: Double {
            return Double(memoryUsage) / (1024 * 1024)
        }
    }
    
    // MARK: - Memory Thresholds
    
    private enum MemoryThresholds {
        static let warning: UInt64 = 150 * 1024 * 1024  // 150MB
        static let critical: UInt64 = 200 * 1024 * 1024 // 200MB
        static let emergency: UInt64 = 250 * 1024 * 1024 // 250MB
    }
    
    // MARK: - Initialization
    
    init() {
        startMemoryMonitoring()
        setupMemoryPressureNotifications()
        logger.info("Performance optimization service initialized")
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() {
        self.currentMemoryUsage = self.getCurrentMemoryUsage()
        
        // Check memory pressure
        if self.currentMemoryUsage > MemoryThresholds.critical {
            self.logger.warning("High memory usage detected: \(self.currentMemoryUsage / (1024*1024))MB")
            self.handleHighMemoryUsage()
        }
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    // MARK: - Memory Pressure Handling
    
    private func setupMemoryPressureNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackgrounded()
        }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received - initiating cleanup")
        
        // Aggressive memory cleanup
        NotificationCenter.default.post(name: .memoryPressureCleanup, object: nil)
        
        // Force garbage collection
        autoreleasepool {
            // Clear caches and temporary data
        }
        
        // Update optimization level if needed
        if optimizationLevel != .conservative {
            logger.info("Switching to conservative optimization due to memory pressure")
            optimizationLevel = .conservative
        }
    }
    
    private func handleHighMemoryUsage() {
        guard currentMemoryUsage > MemoryThresholds.warning else { return }
        
        logger.info("High memory usage - initiating proactive cleanup")
        
        // Proactive cleanup
        NotificationCenter.default.post(name: .proactiveMemoryCleanup, object: nil)
        
        // Adjust optimization settings
        if currentMemoryUsage > MemoryThresholds.critical {
            optimizationLevel = .conservative
        }
    }
    
    private func handleAppBackgrounded() {
        logger.debug("App backgrounded - optimizing memory usage")
        
        // Clear non-essential caches
        NotificationCenter.default.post(name: .backgroundMemoryOptimization, object: nil)
        
        // Record memory state
        recordPerformanceSnapshot(operation: "App Backgrounded", duration: 0)
    }
    
    // MARK: - Image Optimization
    
    func optimizeImageForOCR(_ image: UIImage) -> UIImage {
        let startTime = Date()
        
        // Resize based on optimization level
        let maxDimension = optimizationLevel.maxImageDimension
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        
        // Optimize for OCR processing
        let optimizedImage = enhanceImageForOCR(resizedImage)
        
        let processingTime = Date().timeIntervalSince(startTime)
        recordPerformanceSnapshot(operation: "Image Optimization", duration: processingTime)
        
        logger.debug("Image optimized in \(processingTime)s - size: \(optimizedImage.size.width)x\(optimizedImage.size.height)")
        
        return optimizedImage
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        guard ratio < 1.0 else { return image }
        
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func enhanceImageForOCR(_ image: UIImage) -> UIImage {
        // Apply image processing optimizations for OCR
        guard let cgImage = image.cgImage else { return image }
        
        // For now, return the image as-is
        // In a full implementation, you could apply contrast enhancement,
        // noise reduction, and other OCR-specific optimizations
        return image
    }
    
    // MARK: - OCR Optimization
    
    func getOptimalOCRSettings() -> OCRSettings {
        return OCRSettings(
            recognitionLevel: optimizationLevel.ocrAccuracyLevel,
            languageCorrection: optimizationLevel != .aggressive,
            minimumTextHeight: optimizationLevel == .aggressive ? 0.01 : 0.02,
            usesLanguageCorrection: optimizationLevel != .conservative
        )
    }
    
    struct OCRSettings {
        let recognitionLevel: VNRequestTextRecognitionLevel
        let languageCorrection: Bool
        let minimumTextHeight: Float
        let usesLanguageCorrection: Bool
    }
    
    // MARK: - Performance Tracking
    
    func recordPerformanceMetrics(_ metrics: PerformanceMetrics) {
        performanceMetrics = metrics
        
        recordPerformanceSnapshot(
            operation: "Full Processing",
            duration: metrics.totalProcessingTime
        )
        
        logger.info("Performance metrics recorded - total: \(metrics.totalProcessingTime)s")
    }
    
    private func recordPerformanceSnapshot(operation: String, duration: TimeInterval) {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            memoryUsage: currentMemoryUsage,
            cpuUsage: getCPUUsage(),
            operation: operation,
            duration: duration
        )
        
        performanceHistory.append(snapshot)
        
        // Keep only recent history
        if performanceHistory.count > 50 {
            performanceHistory.removeFirst(performanceHistory.count - 50)
        }
    }
    
    private func getCPUUsage() -> Double {
        var info: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpuInfoU: natural_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCpuInfoU,
            &info,
            &numCpuInfo
        )
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        // Simplified CPU usage calculation
        return 0.0 // Placeholder - would need more complex implementation
    }
    
    // MARK: - Cache Management
    
    func optimizeCacheUsage() {
        logger.debug("Optimizing cache usage")
        
        // Clear URL cache if memory is high
        if currentMemoryUsage > MemoryThresholds.warning {
            URLSession.shared.configuration.urlCache?.removeAllCachedResponses()
            logger.debug("URL cache cleared due to memory pressure")
        }
        
        // Optimize image cache
        NotificationCenter.default.post(name: .optimizeImageCache, object: nil)
    }
    
    // MARK: - Performance Reporting
    
    func getPerformanceReport() -> PerformanceReport {
        let recentSnapshots = performanceHistory.suffix(10)
        let averageMemory = recentSnapshots.map { $0.memoryUsage }.reduce(0, +) / UInt64(max(recentSnapshots.count, 1))
        let averageDuration = recentSnapshots.map { $0.duration }.reduce(0, +) / Double(max(recentSnapshots.count, 1))
        
        return PerformanceReport(
            currentMemoryUsage: currentMemoryUsage,
            averageMemoryUsage: averageMemory,
            averageProcessingTime: averageDuration,
            optimizationLevel: optimizationLevel,
            recentOperations: Array(recentSnapshots),
            memoryPressureLevel: getMemoryPressureLevel()
        )
    }
    
    private func getMemoryPressureLevel() -> MemoryPressureLevel {
        switch currentMemoryUsage {
        case 0..<MemoryThresholds.warning:
            return .normal
        case MemoryThresholds.warning..<MemoryThresholds.critical:
            return .elevated
        case MemoryThresholds.critical..<MemoryThresholds.emergency:
            return .critical
        default:
            return .emergency
        }
    }
    
    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "Normal"
        case elevated = "Elevated"
        case critical = "Critical"
        case emergency = "Emergency"
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .yellow
            case .critical: return .orange
            case .emergency: return .red
            }
        }
    }
    
    struct PerformanceReport {
        let currentMemoryUsage: UInt64
        let averageMemoryUsage: UInt64
        let averageProcessingTime: TimeInterval
        let optimizationLevel: OptimizationLevel
        let recentOperations: [PerformanceSnapshot]
        let memoryPressureLevel: MemoryPressureLevel
        
        var currentMemoryMB: Double {
            Double(currentMemoryUsage) / (1024 * 1024)
        }
        
        var averageMemoryMB: Double {
            Double(averageMemoryUsage) / (1024 * 1024)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        memoryTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let memoryPressureCleanup = Notification.Name("memoryPressureCleanup")
    static let proactiveMemoryCleanup = Notification.Name("proactiveMemoryCleanup")
    static let backgroundMemoryOptimization = Notification.Name("backgroundMemoryOptimization")
    static let optimizeImageCache = Notification.Name("optimizeImageCache")
}

// MARK: - Vision Framework Integration

import Vision

extension PerformanceOptimizationService {
    func createOptimizedTextRecognitionRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        let settings = getOptimalOCRSettings()
        
        request.recognitionLevel = settings.recognitionLevel
        request.usesLanguageCorrection = settings.usesLanguageCorrection
        request.minimumTextHeight = settings.minimumTextHeight
        
        // Set language preferences based on optimization level
        if optimizationLevel != .conservative {
            request.recognitionLanguages = ["en-US", "en-GB"]
        } else {
            request.recognitionLanguages = ["en-US"]
        }
        
        return request
    }
}