//
//  CameraPermissionManager.swift
//  Menu Visualizer
//
//  Privacy-compliant camera permission management with user guidance
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

/// Comprehensive camera permission manager with privacy compliance
@MainActor
final class CameraPermissionManager: ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var showingPermissionAlert = false
    @Published var showingSettingsAlert = false
    @Published var permissionDeniedReason: PermissionDeniedReason?
    
    // MARK: - Permission States
    
    enum PermissionDeniedReason {
        case userDenied
        case restrictedByPolicy
        case hardwareUnavailable
        case unknown
        
        var localizedDescription: String {
            switch self {
            case .userDenied:
                return "Camera access was denied. You can enable it in Settings."
            case .restrictedByPolicy:
                return "Camera access is restricted by device policies."
            case .hardwareUnavailable:
                return "Camera is not available on this device."
            case .unknown:
                return "Camera access is unavailable for an unknown reason."
            }
        }
        
        var canOpenSettings: Bool {
            switch self {
            case .userDenied:
                return true
            case .restrictedByPolicy, .hardwareUnavailable, .unknown:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        updateAuthorizationStatus()
        setupNotificationObserver()
    }
    
    // MARK: - Permission Management
    
    /// Request camera permission with proper privacy messaging
    func requestCameraPermission() async -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch currentStatus {
        case .authorized:
            authorizationStatus = .authorized
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                updateAuthorizationStatus()
                if !granted {
                    permissionDeniedReason = .userDenied
                    showingPermissionAlert = true
                }
            }
            return granted
            
        case .denied:
            authorizationStatus = .denied
            permissionDeniedReason = .userDenied
            showingSettingsAlert = true
            return false
            
        case .restricted:
            authorizationStatus = .restricted
            permissionDeniedReason = .restrictedByPolicy
            showingPermissionAlert = true
            return false
            
        @unknown default:
            authorizationStatus = currentStatus
            permissionDeniedReason = .unknown
            showingPermissionAlert = true
            return false
        }
    }
    
    /// Check if camera is currently available
    func isCameraAvailable() -> Bool {
        guard authorizationStatus == .authorized else { return false }
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    /// Present appropriate permission guidance to user
    func presentPermissionGuidance() {
        switch authorizationStatus {
        case .notDetermined:
            Task {
                await requestCameraPermission()
            }
        case .denied:
            permissionDeniedReason = .userDenied
            showingSettingsAlert = true
        case .restricted:
            permissionDeniedReason = .restrictedByPolicy
            showingPermissionAlert = true
        case .authorized:
            break
        @unknown default:
            permissionDeniedReason = .unknown
            showingPermissionAlert = true
        }
    }
    
    // MARK: - Settings Navigation
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Privacy Compliance
    
    /// Generate privacy-compliant permission explanation
    func privacyExplanation() -> String {
        return """
        Menuly needs camera access to capture photos of menus for text recognition and dish visualization.
        
        • Photos are processed locally on your device
        • No images are stored or transmitted
        • Data is cleared when you close the app
        • Processing happens entirely offline for privacy
        """
    }
    
    /// Check if app meets privacy compliance standards
    func validatePrivacyCompliance() -> Bool {
        // Ensure we have proper usage description in Info.plist
        guard let cameraUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
              !cameraUsageDescription.isEmpty else {
            return false
        }
        
        // Validate usage description mentions privacy-first approach
        let privacyKeywords = ["privacy", "local", "device", "not stored", "offline"]
        let hasPrivacyMention = privacyKeywords.contains { keyword in
            cameraUsageDescription.lowercased().contains(keyword)
        }
        
        return hasPrivacyMention
    }
    
    // MARK: - Private Helpers
    
    private func updateAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAuthorizationStatus()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SwiftUI Integration

extension CameraPermissionManager {
    /// SwiftUI view modifier for camera permission alerts
    func permissionAlerts() -> some View {
        Group {
            EmptyView()
                .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
                    if permissionDeniedReason?.canOpenSettings == true {
                        Button("Open Settings") {
                            openAppSettings()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        permissionDeniedReason = nil
                    }
                } message: {
                    Text(permissionDeniedReason?.localizedDescription ?? "Camera access is required to capture menu photos.")
                }
                .alert("Camera Access Needed", isPresented: $showingSettingsAlert) {
                    Button("Open Settings") {
                        openAppSettings()
                    }
                    Button("Cancel", role: .cancel) {
                        permissionDeniedReason = nil
                    }
                } message: {
                    Text("Please enable camera access in Settings to capture menu photos.")
                }
        }
    }
}

// MARK: - Permission Status Helpers

extension AVAuthorizationStatus {
    var displayName: String {
        switch self {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    var isAuthorized: Bool {
        return self == .authorized
    }
    
    var needsUserAction: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .authorized, .notDetermined:
            return false
        @unknown default:
            return true
        }
    }
}

// MARK: - Privacy Compliance Validation

extension CameraPermissionManager {
    /// Validate that the app follows Apple's privacy guidelines
    static func validateAppPrivacyCompliance() -> PrivacyComplianceResult {
        var issues: [PrivacyIssue] = []
        
        // Check Info.plist camera usage description
        guard let cameraUsage = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
              !cameraUsage.isEmpty else {
            issues.append(.missingCameraUsageDescription)
            return PrivacyComplianceResult(isCompliant: false, issues: issues)
        }
        
        // Validate usage description quality
        if cameraUsage.count < 30 {
            issues.append(.inadequateCameraUsageDescription)
        }
        
        // Check for privacy-first language
        let privacyKeywords = ["privacy", "local", "device", "not stored", "temporary"]
        let hasPrivacyLanguage = privacyKeywords.contains { keyword in
            cameraUsage.lowercased().contains(keyword)
        }
        
        if !hasPrivacyLanguage {
            issues.append(.missingPrivacyLanguage)
        }
        
        return PrivacyComplianceResult(
            isCompliant: issues.isEmpty,
            issues: issues
        )
    }
}

// MARK: - Privacy Compliance Types

struct PrivacyComplianceResult {
    let isCompliant: Bool
    let issues: [PrivacyIssue]
    
    var description: String {
        if isCompliant {
            return "✅ App is privacy compliant"
        } else {
            let issueDescriptions = issues.map { $0.description }.joined(separator: "\n")
            return "❌ Privacy issues found:\n\(issueDescriptions)"
        }
    }
}

enum PrivacyIssue {
    case missingCameraUsageDescription
    case inadequateCameraUsageDescription
    case missingPrivacyLanguage
    
    var description: String {
        switch self {
        case .missingCameraUsageDescription:
            return "Missing NSCameraUsageDescription in Info.plist"
        case .inadequateCameraUsageDescription:
            return "Camera usage description is too brief"
        case .missingPrivacyLanguage:
            return "Usage description should mention privacy-first approach"
        }
    }
}