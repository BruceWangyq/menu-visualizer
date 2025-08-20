//
//  CameraDiagnosticService.swift
//  Menu Visualizer
//
//  Comprehensive camera system diagnostics and debugging
//

import SwiftUI
import AVFoundation
import UIKit

/// Comprehensive camera diagnostic service for debugging camera issues
@MainActor
final class CameraDiagnosticService: ObservableObject {
    @Published var diagnosticReport: CameraDiagnosticReport?
    @Published var isRunningDiagnostics = false
    
    // MARK: - Diagnostic Execution
    
    func runComprehensiveDiagnostics() async -> CameraDiagnosticReport {
        print("🔍 STARTING COMPREHENSIVE CAMERA DIAGNOSTICS")
        isRunningDiagnostics = true
        
        var report = CameraDiagnosticReport()
        
        // 1. Environment Detection
        report.environment = detectEnvironment()
        print("📱 Environment: \(report.environment)")
        
        // 2. Hardware Availability
        report.hardwareAvailable = checkHardwareAvailability()
        print("🔧 Hardware Available: \(report.hardwareAvailable)")
        
        // 3. Permission Status
        report.permissionStatus = getCurrentPermissionStatus()
        print("🔐 Permission Status: \(report.permissionStatus.displayName)")
        
        // 4. Info.plist Validation
        report.infoPlistValid = validateInfoPlist()
        print("📄 Info.plist Valid: \(report.infoPlistValid)")
        
        // 5. Camera Device Enumeration
        report.availableDevices = enumerateCameraDevices()
        print("📹 Available Devices: \(report.availableDevices.count)")
        
        // 6. Session Creation Test
        report.sessionCreationResult = await testSessionCreation()
        print("🎬 Session Creation: \(report.sessionCreationResult)")
        
        // 7. Permission Request Test
        if report.permissionStatus == .notDetermined {
            report.permissionRequestResult = await testPermissionRequest()
            print("🙋 Permission Request: \(report.permissionRequestResult)")
        }
        
        // 8. Generate Recommendations
        report.recommendations = generateRecommendations(for: report)
        
        // 9. Critical Issues
        report.criticalIssues = identifyCriticalIssues(from: report)
        
        self.diagnosticReport = report
        isRunningDiagnostics = false
        
        print("✅ DIAGNOSTIC COMPLETE")
        print("🚨 Critical Issues: \(report.criticalIssues.count)")
        print("💡 Recommendations: \(report.recommendations.count)")
        
        return report
    }
    
    // MARK: - Individual Diagnostic Functions
    
    private func detectEnvironment() -> CameraEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            return .simulator
        }
        return .device
        #endif
    }
    
    private func checkHardwareAvailability() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    private func getCurrentPermissionStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func validateInfoPlist() -> Bool {
        guard let cameraUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
              !cameraUsageDescription.isEmpty else {
            return false
        }
        return true
    }
    
    private func enumerateCameraDevices() -> [CameraDeviceInfo] {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        
        return devices.map { device in
            CameraDeviceInfo(
                localizedName: device.localizedName,
                position: device.position,
                deviceType: device.deviceType,
                isConnected: device.isConnected
            )
        }
    }
    
    private func testSessionCreation() async -> SessionCreationResult {
        do {
            let session = AVCaptureSession()
            session.beginConfiguration()
            
            // Try to add camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                session.commitConfiguration()
                return .failure("No back camera available")
            }
            
            let input = try AVCaptureDeviceInput(device: camera)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return .failure("Cannot add camera input to session")
            }
            session.addInput(input)
            
            // Try to add photo output
            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return .failure("Cannot add photo output to session")
            }
            session.addOutput(output)
            
            session.commitConfiguration()
            return .success("Session created successfully")
            
        } catch {
            return .failure("Session creation failed: \(error.localizedDescription)")
        }
    }
    
    private func testPermissionRequest() async -> PermissionRequestResult {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }
    
    private func generateRecommendations(for report: CameraDiagnosticReport) -> [DiagnosticRecommendation] {
        var recommendations: [DiagnosticRecommendation] = []
        
        // Environment-based recommendations
        if report.environment == .simulator {
            recommendations.append(.testOnRealDevice)
        }
        
        // Hardware recommendations
        if !report.hardwareAvailable {
            recommendations.append(.checkHardware)
        }
        
        // Permission recommendations
        switch report.permissionStatus {
        case .denied:
            recommendations.append(.enableCameraInSettings)
        case .restricted:
            recommendations.append(.checkRestrictions)
        case .notDetermined:
            recommendations.append(.requestPermission)
        case .authorized:
            break
        @unknown default:
            recommendations.append(.checkPermissionState)
        }
        
        // Info.plist recommendations
        if !report.infoPlistValid {
            recommendations.append(.addCameraUsageDescription)
        }
        
        // Session creation recommendations
        if case .failure = report.sessionCreationResult {
            recommendations.append(.debugSessionCreation)
        }
        
        return recommendations
    }
    
    private func identifyCriticalIssues(from report: CameraDiagnosticReport) -> [CriticalIssue] {
        var issues: [CriticalIssue] = []
        
        if report.environment == .simulator {
            issues.append(.simulatorLimitation)
        }
        
        if !report.hardwareAvailable {
            issues.append(.noHardware)
        }
        
        if !report.infoPlistValid {
            issues.append(.missingPermissionDescription)
        }
        
        if report.permissionStatus == .denied || report.permissionStatus == .restricted {
            issues.append(.permissionBlocked)
        }
        
        if case .failure = report.sessionCreationResult {
            issues.append(.sessionCreationFailed)
        }
        
        return issues
    }
}

// MARK: - Diagnostic Data Models

struct CameraDiagnosticReport {
    var environment: CameraEnvironment = .unknown
    var hardwareAvailable: Bool = false
    var permissionStatus: AVAuthorizationStatus = .notDetermined
    var infoPlistValid: Bool = false
    var availableDevices: [CameraDeviceInfo] = []
    var sessionCreationResult: SessionCreationResult = .failure("Not tested")
    var permissionRequestResult: PermissionRequestResult = .notTested
    var recommendations: [DiagnosticRecommendation] = []
    var criticalIssues: [CriticalIssue] = []
    
    var summary: String {
        let issueCount = criticalIssues.count
        let recCount = recommendations.count
        
        if issueCount == 0 {
            return "✅ Camera system healthy - \(recCount) optimizations available"
        } else {
            return "⚠️ \(issueCount) critical issues found - \(recCount) actions recommended"
        }
    }
}

enum CameraEnvironment {
    case simulator
    case device
    case unknown
    
    var description: String {
        switch self {
        case .simulator: return "iOS Simulator"
        case .device: return "Physical Device"
        case .unknown: return "Unknown Environment"
        }
    }
}

struct CameraDeviceInfo {
    let localizedName: String
    let position: AVCaptureDevice.Position
    let deviceType: AVCaptureDevice.DeviceType
    let isConnected: Bool
}

enum SessionCreationResult {
    case success(String)
    case failure(String)
    
    var description: String {
        switch self {
        case .success(let message): return "✅ \(message)"
        case .failure(let message): return "❌ \(message)"
        }
    }
}

enum PermissionRequestResult {
    case granted
    case denied
    case notTested
    
    var description: String {
        switch self {
        case .granted: return "✅ Permission Granted"
        case .denied: return "❌ Permission Denied"
        case .notTested: return "➖ Not Tested"
        }
    }
}

enum DiagnosticRecommendation {
    case testOnRealDevice
    case checkHardware
    case enableCameraInSettings
    case checkRestrictions
    case requestPermission
    case checkPermissionState
    case addCameraUsageDescription
    case debugSessionCreation
    
    var title: String {
        switch self {
        case .testOnRealDevice: return "Test on Real Device"
        case .checkHardware: return "Check Camera Hardware"
        case .enableCameraInSettings: return "Enable Camera in Settings"
        case .checkRestrictions: return "Check Device Restrictions"
        case .requestPermission: return "Request Camera Permission"
        case .checkPermissionState: return "Debug Permission State"
        case .addCameraUsageDescription: return "Add Camera Usage Description"
        case .debugSessionCreation: return "Debug Session Creation"
        }
    }
    
    var description: String {
        switch self {
        case .testOnRealDevice:
            return "Camera functionality requires testing on a physical device with camera hardware."
        case .checkHardware:
            return "Ensure device has functional camera hardware and is not damaged."
        case .enableCameraInSettings:
            return "Go to Settings > Privacy & Security > Camera and enable access for this app."
        case .checkRestrictions:
            return "Camera access may be restricted by device management policies."
        case .requestPermission:
            return "App needs to request camera permission from the user."
        case .checkPermissionState:
            return "Permission state is unclear and needs debugging."
        case .addCameraUsageDescription:
            return "Add NSCameraUsageDescription key to Info.plist with privacy explanation."
        case .debugSessionCreation:
            return "Camera session creation is failing and needs investigation."
        }
    }
}

enum CriticalIssue {
    case simulatorLimitation
    case noHardware
    case missingPermissionDescription
    case permissionBlocked
    case sessionCreationFailed
    
    var title: String {
        switch self {
        case .simulatorLimitation: return "🟡 Simulator Limitation"
        case .noHardware: return "🔴 No Camera Hardware"
        case .missingPermissionDescription: return "🔴 Missing Permission Description"
        case .permissionBlocked: return "🔴 Permission Blocked"
        case .sessionCreationFailed: return "🔴 Session Creation Failed"
        }
    }
    
    var severity: IssueSeverity {
        switch self {
        case .simulatorLimitation: return .warning
        case .noHardware, .missingPermissionDescription, .permissionBlocked, .sessionCreationFailed: return .critical
        }
    }
}

enum IssueSeverity {
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .warning: return .orange
        case .critical: return .red
        }
    }
}