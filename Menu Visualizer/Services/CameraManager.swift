//
//  CameraManager.swift
//  Menu Visualizer
//
//  Robust camera implementation following iOS best practices
//  Consolidates all camera functionality into a single, reliable manager
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

/// Camera manager that follows iOS best practices for real device deployment
@MainActor
final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CameraManager()
    
    // Private init to ensure singleton usage
    private override init() {
        super.init()
        setupBindings()
        checkInitialAuthorizationStatus()
    }
    
    // MARK: - Published State
    
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published @objc dynamic var isSessionRunning = false
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    @Published var currentError: CameraError?
    @Published var focusPoint: CGPoint?
    @Published var zoomFactor: CGFloat = 1.0
    @Published var devicePosition: AVCaptureDevice.Position = .back
    
    // MARK: - Camera Components
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentDevice: AVCaptureDevice?
    
    // MARK: - Capture Handling
    
    private var photoCompletionHandler: ((Result<UIImage, CameraError>) -> Void)?
    private var sessionSetupResult: SessionSetupResult = .success
    
    // MARK: - Lifecycle Management
    
    private var keyValueObservations = [NSKeyValueObservation]()
    private var cancellables = Set<AnyCancellable>()
    
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkInitialAuthorizationStatus()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pauseSession()
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        guard await isHardwareAvailable() else {
            await MainActor.run {
                currentError = .hardwareUnavailable
            }
            return false
        }
        
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch currentStatus {
        case .authorized:
            await MainActor.run {
                authorizationStatus = .authorized
            }
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if !granted {
                    currentError = .permissionDenied
                }
            }
            return granted
            
        case .denied, .restricted:
            await MainActor.run {
                authorizationStatus = currentStatus
                currentError = .permissionDenied
            }
            return false
            
        @unknown default:
            await MainActor.run {
                authorizationStatus = currentStatus
                currentError = .permissionDenied
            }
            return false
        }
    }
    
    // MARK: - Session Management
    
    func configureSession() async -> Bool {
        if authorizationStatus != .authorized {
            let granted = await requestPermission()
            guard granted else { return false }
        }
        
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.configureSessionInternal { success in
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    private func configureSessionInternal(completion: @escaping (Bool) -> Void) {
        guard authorizationStatus == .authorized else {
            DispatchQueue.main.async {
                self.sessionSetupResult = .configurationFailed
                self.currentError = .permissionDenied
            }
            completion(false)
            return
        }
        
        let session = AVCaptureSession()
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        do {
            // Add video input
            let defaultVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                            for: .video, 
                                                            position: devicePosition)
            
            guard let videoDevice = defaultVideoDevice else {
                DispatchQueue.main.async {
                    self.sessionSetupResult = .configurationFailed
                    self.currentError = .deviceNotFound
                }
                session.commitConfiguration()
                completion(false)
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                self.currentDevice = videoDevice
                
                // Setup device observers
                DispatchQueue.main.async {
                    self.setupDeviceObservers(for: videoDevice)
                }
            } else {
                DispatchQueue.main.async {
                    self.sessionSetupResult = .configurationFailed
                    self.currentError = .configurationFailed
                }
                session.commitConfiguration()
                completion(false)
                return
            }
            
            // Add photo output
            let photoOutput = AVCapturePhotoOutput()
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
                
                // Configure photo output
                if #available(iOS 16.0, *) {
                    photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
                } else {
                    photoOutput.isHighResolutionCaptureEnabled = true
                }
                photoOutput.maxPhotoQualityPrioritization = .quality
                
            } else {
                DispatchQueue.main.async {
                    self.sessionSetupResult = .configurationFailed
                    self.currentError = .configurationFailed
                }
                session.commitConfiguration()
                completion(false)
                return
            }
            
            session.commitConfiguration()
            self.captureSession = session
            
            DispatchQueue.main.async {
                self.sessionSetupResult = .success
                self.currentError = nil
            }
            
            completion(true)
            
        } catch {
            DispatchQueue.main.async {
                self.sessionSetupResult = .configurationFailed
                self.currentError = .configurationFailed
            }
            session.commitConfiguration()
            completion(false)
        }
    }
    
    func startSession() {
        guard authorizationStatus == .authorized else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  !session.isRunning else { return }
            
            session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = session.isRunning
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  session.isRunning else { return }
            
            session.stopRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    private func pauseSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  session.isRunning else { return }
            
            session.stopRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() async -> Result<UIImage, CameraError> {
        guard !isCapturing else {
            return .failure(.captureInProgress)
        }
        
        guard let photoOutput = photoOutput else {
            return .failure(.outputNotAvailable)
        }
        
        await MainActor.run {
            isCapturing = true
        }
        
        return await withCheckedContinuation { continuation in
            photoCompletionHandler = { result in
                continuation.resume(returning: result)
            }
            
            sessionQueue.async {
                let photoSettings = AVCapturePhotoSettings()
                
                // Configure settings for optimal OCR
                if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    photoSettings.photoQualityPrioritization = .quality
                }
                
                // Configure flash based on lighting conditions
                if photoOutput.supportedFlashModes.contains(.auto) {
                    photoSettings.flashMode = .auto
                }
                
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
    }
    
    // MARK: - Camera Controls
    
    func switchCamera() async -> Bool {
        let newPosition: AVCaptureDevice.Position = devicePosition == .back ? .front : .back
        
        return await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self,
                      let session = self.captureSession else {
                    continuation.resume(returning: false)
                    return
                }
                
                session.beginConfiguration()
                
                // Remove existing input
                if let currentInput = self.videoDeviceInput {
                    session.removeInput(currentInput)
                }
                
                // Add new input
                guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                            for: .video,
                                                            position: newPosition) else {
                    session.commitConfiguration()
                    continuation.resume(returning: false)
                    return
                }
                
                do {
                    let newInput = try AVCaptureDeviceInput(device: newDevice)
                    
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        self.videoDeviceInput = newInput
                        self.currentDevice = newDevice
                        
                        DispatchQueue.main.async {
                            self.devicePosition = newPosition
                            self.setupDeviceObservers(for: newDevice)
                        }
                        
                        session.commitConfiguration()
                        continuation.resume(returning: true)
                    } else {
                        session.commitConfiguration()
                        continuation.resume(returning: false)
                    }
                } catch {
                    session.commitConfiguration()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func setFocus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let device = self?.currentDevice else { return }
            
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
                
                DispatchQueue.main.async {
                    self?.focusPoint = point
                    
                    // Clear focus indicator after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self?.focusPoint = nil
                    }
                }
                
            } catch {
                print("Focus setting failed: \(error)")
            }
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let device = self?.currentDevice else { return }
            
            do {
                try device.lockForConfiguration()
                
                let clampedFactor = max(device.minAvailableVideoZoomFactor,
                                      min(factor, device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = clampedFactor
                
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self?.zoomFactor = clampedFactor
                }
                
            } catch {
                print("Zoom setting failed: \(error)")
            }
        }
    }
    
    // MARK: - Device Observers
    
    private func setupDeviceObservers(for device: AVCaptureDevice) {
        // Clear previous observers
        keyValueObservations.removeAll()
        
        // Observe device properties
        let sessionRunningObservation = observe(\.isSessionRunning, options: .new) { _, change in
            guard change.newValue != nil else { return }
            
            DispatchQueue.main.async {
                // Handle session state changes
            }
        }
        keyValueObservations.append(sessionRunningObservation)
    }
    
    // MARK: - Utility
    
    private func isHardwareAvailable() async -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopSession()
        
        keyValueObservations.removeAll()
        cancellables.removeAll()
        
        capturedImage = nil
        focusPoint = nil
        currentError = nil
        photoCompletionHandler = nil
    }
    
    deinit {
        // The arrays will be automatically deallocated when the instance is destroyed
        // No explicit cleanup needed in deinit for memory safety
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            Task { @MainActor in
                self.isCapturing = false
                self.currentError = .captureError(error.localizedDescription)
                self.photoCompletionHandler?(.failure(.captureError(error.localizedDescription)))
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                self.isCapturing = false
                self.currentError = .imageProcessingFailed
                self.photoCompletionHandler?(.failure(.imageProcessingFailed))
            }
            return
        }
        
        // Optimize image for OCR
        let optimizedImage = Self.optimizeImageForOCR(image)
        
        Task { @MainActor in
            self.isCapturing = false
            self.capturedImage = optimizedImage
            self.currentError = nil
            self.photoCompletionHandler?(.success(optimizedImage))
        }
    }
    
    // MARK: - Image Optimization
    
    nonisolated private static func optimizeImageForOCR(_ image: UIImage) -> UIImage {
        // Fix orientation for proper OCR processing
        let orientedImage = image.fixedOrientation()
        
        // Resize if needed (balance quality vs performance)
        let maxDimension: CGFloat = 2048
        let resizedImage = orientedImage.resized(maxDimension: maxDimension)
        
        return resizedImage
    }
}

// MARK: - Supporting Types

enum CameraError: LocalizedError, Equatable {
    case permissionDenied
    case hardwareUnavailable
    case deviceNotFound
    case configurationFailed
    case captureInProgress
    case outputNotAvailable
    case captureError(String)
    case imageProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission is required to capture photos"
        case .hardwareUnavailable:
            return "Camera hardware is not available"
        case .deviceNotFound:
            return "Camera device not found"
        case .configurationFailed:
            return "Failed to configure camera session"
        case .captureInProgress:
            return "Photo capture already in progress"
        case .outputNotAvailable:
            return "Photo output not available"
        case .captureError(let message):
            return "Capture failed: \(message)"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        }
    }
    
    static func == (lhs: CameraError, rhs: CameraError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.hardwareUnavailable, .hardwareUnavailable),
             (.deviceNotFound, .deviceNotFound),
             (.configurationFailed, .configurationFailed),
             (.captureInProgress, .captureInProgress),
             (.outputNotAvailable, .outputNotAvailable),
             (.imageProcessingFailed, .imageProcessingFailed):
            return true
        case (.captureError(let lhsMessage), .captureError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum SessionSetupResult {
    case success
    case configurationFailed
}

// MARK: - UIImage Extensions

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