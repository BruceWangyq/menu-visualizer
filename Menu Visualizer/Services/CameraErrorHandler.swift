//
//  CameraErrorHandler.swift
//  Menu Visualizer
//
//  Comprehensive camera error handling and recovery system
//

import SwiftUI
import AVFoundation
import UIKit

/// Comprehensive error handling and recovery system for camera operations
@MainActor
final class CameraErrorHandler: ObservableObject {
    
    @Published var currentError: CameraError?
    @Published var showingErrorAlert = false
    @Published var showingRecoveryOptions = false
    @Published var errorSeverity: ErrorSeverity = .info
    @Published var recoveryActions: [RecoveryAction] = []
    
    // MARK: - Error Analysis
    
    func handleError(_ error: CameraError) {
        currentError = error
        errorSeverity = determineSeverity(for: error)
        recoveryActions = generateRecoveryActions(for: error)
        
        // Determine presentation method based on severity
        switch errorSeverity {
        case .critical:
            showingErrorAlert = true
        case .warning:
            showingRecoveryOptions = true
        case .info:
            // Show temporary notification
            showTemporaryNotification(for: error)
        }
        
        // Log error for debugging
        logError(error)
    }
    
    private func determineSeverity(for error: CameraError) -> ErrorSeverity {
        switch error {
        case .permissionDenied, .hardwareUnavailable:
            return .critical
        case .deviceNotFound, .configurationFailed:
            return .warning
        case .captureInProgress, .outputNotAvailable, .imageProcessingFailed:
            return .info
        case .captureError:
            return .warning
        }
    }
    
    private func generateRecoveryActions(for error: CameraError) -> [RecoveryAction] {
        switch error {
        case .permissionDenied:
            return [
                .openSettings,
                .showPermissionGuide,
                .dismiss
            ]
            
        case .hardwareUnavailable:
            return [
                .checkDevice,
                .runDiagnostics,
                .contactSupport,
                .dismiss
            ]
            
        case .deviceNotFound:
            return [
                .retryConfiguration,
                .switchToFrontCamera,
                .runDiagnostics,
                .dismiss
            ]
            
        case .configurationFailed:
            return [
                .retryConfiguration,
                .resetSession,
                .runDiagnostics,
                .dismiss
            ]
            
        case .captureInProgress:
            return [
                .waitAndRetry,
                .dismiss
            ]
            
        case .outputNotAvailable:
            return [
                .retryConfiguration,
                .resetSession,
                .dismiss
            ]
            
        case .captureError:
            return [
                .retryCapture,
                .checkLighting,
                .runDiagnostics,
                .dismiss
            ]
            
        case .imageProcessingFailed:
            return [
                .retryCapture,
                .resetSession,
                .dismiss
            ]
        }
    }
    
    // MARK: - Recovery Actions
    
    func executeRecoveryAction(_ action: RecoveryAction, with cameraManager: CameraManager) async {
        switch action {
        case .openSettings:
            await openAppSettings()
            
        case .showPermissionGuide:
            // Show detailed permission explanation
            break
            
        case .checkDevice:
            // Show device check instructions
            break
            
        case .runDiagnostics:
            await runDiagnostics()
            
        case .contactSupport:
            // Show support contact options
            break
            
        case .retryConfiguration:
            await retryConfiguration(with: cameraManager)
            
        case .switchToFrontCamera:
            await switchToFrontCamera(with: cameraManager)
            
        case .resetSession:
            await resetSession(with: cameraManager)
            
        case .waitAndRetry:
            await waitAndRetry(with: cameraManager)
            
        case .retryCapture:
            await retryCapture(with: cameraManager)
            
        case .checkLighting:
            // Show lighting improvement tips
            break
            
        case .dismiss:
            dismissError()
        }
    }
    
    // MARK: - Recovery Implementations
    
    private func openAppSettings() async {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            await UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func runDiagnostics() async {
        let diagnosticService = CameraDiagnosticService()
        let report = await diagnosticService.runComprehensiveDiagnostics()
        
        // Present diagnostic results
        print("📊 Diagnostic Report: \(report.summary)")
    }
    
    private func retryConfiguration(with cameraManager: CameraManager) async {
        let success = await cameraManager.configureSession()
        
        if success {
            dismissError()
        } else {
            // Configuration still failed - escalate
            currentError = .configurationFailed
        }
    }
    
    private func switchToFrontCamera(with cameraManager: CameraManager) async {
        let success = await cameraManager.switchCamera()
        
        if success {
            dismissError()
        }
    }
    
    private func resetSession(with cameraManager: CameraManager) async {
        cameraManager.stopSession()
        cameraManager.cleanup()
        
        // Wait a moment before reconfiguring
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let success = await cameraManager.configureSession()
        
        if success {
            cameraManager.startSession()
            dismissError()
        }
    }
    
    private func waitAndRetry(with cameraManager: CameraManager) async {
        // Wait for current operation to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        dismissError()
    }
    
    private func retryCapture(with cameraManager: CameraManager) async {
        let result = await cameraManager.capturePhoto()
        
        switch result {
        case .success:
            dismissError()
        case .failure(let error):
            handleError(error)
        }
    }
    
    private func dismissError() {
        currentError = nil
        showingErrorAlert = false
        showingRecoveryOptions = false
        recoveryActions = []
    }
    
    // MARK: - Notifications
    
    private func showTemporaryNotification(for error: CameraError) {
        // Implementation for temporary notification system
        print("ℹ️ Camera Info: \(error.localizedDescription)")
        
        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.currentError == error {
                self.dismissError()
            }
        }
    }
    
    // MARK: - Logging
    
    private func logError(_ error: CameraError) {
        let timestamp = DateFormatter().string(from: Date())
        print("🚨 [\(timestamp)] Camera Error: \(error)")
        
        // In production, send to analytics service
        // Analytics.logError(error)
    }
    
    // MARK: - User Guidance
    
    func userGuidanceText(for error: CameraError) -> String {
        switch error {
        case .permissionDenied:
            return """
            Camera access is required to capture menu photos.
            
            To enable camera access:
            1. Open Settings
            2. Find 'Menu Visualizer'
            3. Enable Camera permission
            """
            
        case .hardwareUnavailable:
            return """
            Camera hardware is not available.
            
            This could be due to:
            • Device doesn't have a camera
            • Camera is being used by another app
            • Hardware malfunction
            """
            
        case .deviceNotFound:
            return """
            Camera device not found.
            
            Try:
            • Switching to front camera
            • Restarting the app
            • Checking if another app is using the camera
            """
            
        case .configurationFailed:
            return """
            Failed to configure camera.
            
            This might help:
            • Restart the app
            • Check available storage space
            • Ensure camera isn't in use by another app
            """
            
        case .captureInProgress:
            return "Photo capture is already in progress. Please wait for it to complete."
            
        case .outputNotAvailable:
            return "Camera output is not available. Try restarting the camera session."
            
        case .captureError(let message):
            return """
            Photo capture failed: \(message)
            
            Suggestions:
            • Ensure adequate lighting
            • Hold device steady
            • Check available storage space
            """
            
        case .imageProcessingFailed:
            return """
            Failed to process captured image.
            
            This might be due to:
            • Low memory
            • Corrupted image data
            • Insufficient storage space
            """
        }
    }
}

// MARK: - Supporting Types

enum ErrorSeverity {
    case critical  // Blocks core functionality
    case warning   // Impacts functionality but has workarounds
    case info      // Informational, temporary issues
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum RecoveryAction: CaseIterable {
    case openSettings
    case showPermissionGuide
    case checkDevice
    case runDiagnostics
    case contactSupport
    case retryConfiguration
    case switchToFrontCamera
    case resetSession
    case waitAndRetry
    case retryCapture
    case checkLighting
    case dismiss
    
    var title: String {
        switch self {
        case .openSettings: return "Open Settings"
        case .showPermissionGuide: return "Permission Guide"
        case .checkDevice: return "Check Device"
        case .runDiagnostics: return "Run Diagnostics"
        case .contactSupport: return "Contact Support"
        case .retryConfiguration: return "Retry Setup"
        case .switchToFrontCamera: return "Switch Camera"
        case .resetSession: return "Reset Camera"
        case .waitAndRetry: return "Wait & Retry"
        case .retryCapture: return "Retry Capture"
        case .checkLighting: return "Lighting Tips"
        case .dismiss: return "Dismiss"
        }
    }
    
    var icon: String {
        switch self {
        case .openSettings: return "gear"
        case .showPermissionGuide: return "questionmark.circle"
        case .checkDevice: return "camera.badge.ellipsis"
        case .runDiagnostics: return "stethoscope"
        case .contactSupport: return "envelope"
        case .retryConfiguration: return "arrow.clockwise"
        case .switchToFrontCamera: return "camera.rotate"
        case .resetSession: return "power"
        case .waitAndRetry: return "clock"
        case .retryCapture: return "camera"
        case .checkLighting: return "lightbulb"
        case .dismiss: return "xmark"
        }
    }
    
    var style: ActionStyle {
        switch self {
        case .dismiss: return .cancel
        case .openSettings, .retryConfiguration, .retryCapture: return .default
        case .resetSession, .contactSupport: return .destructive
        default: return .secondary
        }
    }
}

enum ActionStyle {
    case `default`
    case cancel
    case destructive
    case secondary
    
    var color: Color {
        switch self {
        case .default: return .blue
        case .cancel: return .gray
        case .destructive: return .red
        case .secondary: return .secondary
        }
    }
}

// MARK: - SwiftUI Integration

struct CameraErrorAlertsModifier: ViewModifier {
    @ObservedObject var errorHandler: CameraErrorHandler
    let cameraManager: CameraManager
    
    func body(content: Content) -> some View {
        content
            .alert("Camera Error", isPresented: $errorHandler.showingErrorAlert) {
                ForEach(errorHandler.recoveryActions.prefix(3), id: \.title) { action in
                    Button(action.title) {
                        Task {
                            await errorHandler.executeRecoveryAction(action, with: cameraManager)
                        }
                    }
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(errorHandler.userGuidanceText(for: error))
                }
            }
            .sheet(isPresented: $errorHandler.showingRecoveryOptions) {
                CameraErrorRecoveryView(
                    errorHandler: errorHandler,
                    cameraManager: cameraManager
                )
            }
    }
}

struct CameraErrorRecoveryView: View {
    @ObservedObject var errorHandler: CameraErrorHandler
    let cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Error info
                if let error = errorHandler.currentError {
                    VStack(spacing: 12) {
                        Image(systemName: errorHandler.errorSeverity.icon)
                            .font(.system(size: 40))
                            .foregroundColor(errorHandler.errorSeverity.color)
                        
                        Text(error.localizedDescription)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(errorHandler.userGuidanceText(for: error))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                // Recovery actions
                VStack(spacing: 12) {
                    ForEach(errorHandler.recoveryActions, id: \.title) { action in
                        Button {
                            Task {
                                await errorHandler.executeRecoveryAction(action, with: cameraManager)
                                if action == .dismiss {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: action.icon)
                                Text(action.title)
                                Spacer()
                            }
                            .padding()
                            .background(action.style.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(action.style.color)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Camera Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension View {
    func cameraErrorHandling(
        errorHandler: CameraErrorHandler,
        cameraManager: CameraManager
    ) -> some View {
        modifier(CameraErrorAlertsModifier(
            errorHandler: errorHandler,
            cameraManager: cameraManager
        ))
    }
}