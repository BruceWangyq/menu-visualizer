//
//  CameraService.swift
//  Menu Visualizer
//
//  Privacy-first camera service with AVFoundation integration
//

import SwiftUI
import AVFoundation
import UIKit

/// Camera service for menu photo capture with privacy compliance
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraAvailable = false
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var memoryPressure = false
    @Published var focusPoint: CGPoint?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var currentCaptureCompletion: ((Result<UIImage, MenulyError>) -> Void)?
    private var memoryObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        checkCameraAvailability()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Camera Authorization
    
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
            return granted
        case .denied, .restricted:
            isAuthorized = false
            return false
        @unknown default:
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Camera Setup
    
    private func checkCameraAvailability() {
        isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func setupCaptureSession() -> Result<AVCaptureSession, MenulyError> {
        guard isCameraAvailable else {
            return .failure(.cameraUnavailable)
        }
        
        guard isAuthorized else {
            return .failure(.cameraPermissionDenied)
        }
        
        let session = AVCaptureSession()
        
        do {
            // Configure session for high quality photo capture
            session.sessionPreset = .photo
            
            // Add camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return .failure(.cameraUnavailable)
            }
            
            // Configure camera for optimal OCR capture
            try configureCameraDevice(camera)
            
            let input = try AVCaptureDeviceInput(device: camera)
            self.currentDevice = camera
            guard session.canAddInput(input) else {
                return .failure(.cameraUnavailable)
            }
            session.addInput(input)
            
            // Add photo output
            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                return .failure(.cameraUnavailable)
            }
            session.addOutput(output)
            
            // Configure output for optimal OCR processing
            output.isHighResolutionCaptureEnabled = true
            output.maxPhotoQualityPrioritization = .quality
            
            self.captureSession = session
            self.photoOutput = output
            
            return .success(session)
            
        } catch {
            return .failure(.photoCaptureFailed)
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() async -> Result<UIImage, MenulyError> {
        guard !isCapturing else {
            return .failure(.photoCaptureFailed)
        }
        
        guard let photoOutput = photoOutput else {
            return .failure(.cameraUnavailable)
        }
        
        isCapturing = true
        
        return await withCheckedContinuation { continuation in
            currentCaptureCompletion = { result in
                continuation.resume(returning: result)
            }
            
            // Configure photo settings for OCR optimization
            let settings: AVCapturePhotoSettings
            
            // Use JPEG format for optimal file size/quality balance
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            
            // Enable high resolution for better OCR accuracy
            settings.isHighResolutionPhotoEnabled = photoOutput.isHighResolutionCaptureEnabled
            
            // Optimize for menu reading conditions
            if photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard let session = captureSession else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    func stopSession() {
        guard let session = captureSession else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    // MARK: - Focus and Exposure
    
    func setFocusPoint(_ point: CGPoint) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            focusPoint = point
            
        } catch {
            print("Failed to set focus point: \(error)")
        }
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() {
        memoryPressure = true
        clearCapturedImage()
        
        // Temporarily reduce session quality
        captureSession?.sessionPreset = .medium
        
        // Reset quality after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.memoryPressure = false
            self.captureSession?.sessionPreset = .photo
        }
    }
    
    private func configureCameraDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        // Set auto-focus for text
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        
        // Set exposure for documents
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        // Set white balance for indoor/artificial lighting
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        
        // Set torch if available for low light
        if device.hasTorch && device.isTorchModeSupported(.auto) {
            device.torchMode = .auto
        }
    }
    
    // MARK: - Cleanup (Privacy Compliance)
    
    func clearCapturedImage() {
        capturedImage = nil
        focusPoint = nil
    }
    
    deinit {
        if let observer = memoryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Stop session synchronously in deinit
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
        captureSession = nil
        photoOutput = nil
        currentDevice = nil
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            Task { @MainActor in
                isCapturing = false
                currentCaptureCompletion?(.failure(.photoCaptureFailed))
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                isCapturing = false
                currentCaptureCompletion?(.failure(.photoCaptureFailed))
            }
            return
        }
        
        // Optimize image for OCR processing
        let optimizedImage = optimizeImageForOCR(image)
        
        Task { @MainActor in
            isCapturing = false
            capturedImage = optimizedImage
            currentCaptureCompletion?(.success(optimizedImage))
        }
    }
    
    // MARK: - Image Optimization
    
    nonisolated private func optimizeImageForOCR(_ image: UIImage) -> UIImage {
        // Ensure image is right-side up for OCR
        let orientedImage = image.fixedOrientation()
        
        // Resize if too large (balance between quality and performance)
        let maxDimension: CGFloat = 2048
        let resizedImage = orientedImage.resized(maxDimension: maxDimension)
        
        return resizedImage
    }
}

// MARK: - UIImage Extensions for OCR Optimization

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    func resized(maxDimension: CGFloat) -> UIImage {
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        if ratio >= 1 { return self }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
}