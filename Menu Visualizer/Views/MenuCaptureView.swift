//
//  MenuCaptureView.swift
//  Menu Visualizer
//
//  Menu capture view using robust camera implementation
//

import SwiftUI
import AVFoundation

struct MenuCaptureView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var cameraManager = CameraManager.shared
    @StateObject private var errorHandler = CameraErrorHandler()
    @StateObject private var viewModel: MenuCaptureViewModel
    
    @State private var showingSettings = false
    @State private var showingDiagnostics = false
    @State private var cameraState: CameraState = .initializing
    
    init() {
        // Note: This will be properly initialized with coordinator in onAppear
        self._viewModel = StateObject(wrappedValue: MenuCaptureViewModel(coordinator: AppCoordinator.preview))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraState {
            case .initializing:
                initializingView
                
            case .permissionRequired:
                permissionRequiredView
                
            case .ready:
                cameraView
                
            case .capturing:
                capturingView
                
            case .reviewing:
                if let image = cameraManager.capturedImage {
                    reviewingView(image: image)
                }
                
            case .error:
                errorView
            }
        }
        .onAppear {
            // Initialize the view model with the coordinator
            viewModel.coordinator = coordinator
            initializeCamera()
        }
        .onChange(of: cameraManager.authorizationStatus) { _, status in
            updateCameraState(for: status)
        }
        .onChange(of: cameraManager.currentError) { _, error in
            if error != nil {
                cameraState = .error
                errorHandler.handleError(error!)
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, image in
            if image != nil {
                cameraState = .reviewing
            }
        }
        .cameraErrorHandling(errorHandler: errorHandler, cameraManager: cameraManager)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingDiagnostics) {
            CameraDiagnosticsView()
        }
    }
    
    // MARK: - Camera States
    
    private var initializingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Initializing Camera...")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    private var permissionRequiredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 16) {
                Text("Camera Permission Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("""
                Menu Visualizer needs camera access to capture photos of menus for text recognition and dish visualization.
                
                • Photos are processed locally on your device
                • No images are stored or transmitted
                • Data is cleared when you close the app
                • Processing happens entirely offline for privacy
                """)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                Button {
                    Task {
                        await requestCameraPermission()
                    }
                } label: {
                    Text("Grant Camera Access")
                        .foregroundColor(.white)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: Capsule())
                }
                
                Button {
                    showingDiagnostics = true
                } label: {
                    Text("Run Diagnostics")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private var cameraView: some View {
        ZStack {
            // Camera preview
            CameraPreview(
                cameraManager: cameraManager,
                onTapToFocus: { point in
                    cameraManager.setFocus(at: point)
                },
                onZoomGesture: { factor in
                    cameraManager.setZoom(factor)
                }
            )
            
            // Camera overlay
            CameraViewfinderOverlay()
                .padding()
            
            // Camera controls
            CameraControlOverlay(
                cameraManager: cameraManager,
                onCapture: {
                    Task {
                        await capturePhoto()
                    }
                },
                onSwitchCamera: {
                    Task {
                        await switchCamera()
                    }
                },
                onFlashToggle: nil // Implement if needed
            )
            
            // Top bar
            topBar
        }
    }
    
    private var capturingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Capturing Photo...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }
    
    private func reviewingView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Image preview
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                // Processing overlay if processing
                if viewModel.isProcessing {
                    Rectangle()
                        .fill(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                    
                    VStack(spacing: 16) {
                        ProgressView(value: viewModel.processingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .scaleEffect(x: 1, y: 2)
                        
                        Text(viewModel.processingStatusText)
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        if viewModel.isProcessing {
                            Button("Cancel") {
                                viewModel.cancelCurrentOperation()
                            }
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
            
            // Action buttons
            if !viewModel.isProcessing {
                HStack(spacing: 32) {
                    Button {
                        retakePhoto()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.rotate")
                                .font(.title2)
                            Text("Retake")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        Task {
                            await processPhoto(image)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "text.viewfinder")
                                .font(.title2)
                            Text("Process")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 120, height: 60)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        sharePhoto(image)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("Share")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 80, height: 60)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Camera Error")
                .font(.title)
                .foregroundColor(.white)
            
            if let error = cameraManager.currentError {
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button {
                    Task {
                        await retryCamera()
                    }
                } label: {
                    Text("Retry")
                        .foregroundColor(.white)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: Capsule())
                }
                
                Button {
                    showingDiagnostics = true
                } label: {
                    Text("Run Diagnostics")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private var topBar: some View {
        VStack {
            HStack {
                Button {
                    coordinator.navigateBack()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                Text("Menu Visualizer")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.white)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func initializeCamera() {
        Task {
            await requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() async {
        let granted = await cameraManager.requestPermission()
        
        if granted {
            let configured = await cameraManager.configureSession()
            
            if configured {
                cameraManager.startSession()
                cameraState = .ready
            } else {
                cameraState = .error
            }
        } else {
            cameraState = .permissionRequired
        }
    }
    
    private func updateCameraState(for status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            if cameraState == .permissionRequired {
                Task {
                    let configured = await cameraManager.configureSession()
                    if configured {
                        cameraManager.startSession()
                        cameraState = .ready
                    }
                }
            }
        case .denied, .restricted:
            cameraState = .permissionRequired
        case .notDetermined:
            cameraState = .initializing
        @unknown default:
            cameraState = .error
        }
    }
    
    private func capturePhoto() async {
        cameraState = .capturing
        
        let result = await cameraManager.capturePhoto()
        
        switch result {
        case .success:
            cameraState = .reviewing
        case .failure(let error):
            errorHandler.handleError(error)
            cameraState = .error
        }
    }
    
    private func switchCamera() async {
        let success = await cameraManager.switchCamera()
        
        if !success {
            errorHandler.handleError(.deviceNotFound)
        }
    }
    
    private func retakePhoto() {
        cameraManager.capturedImage = nil
        cameraState = .ready
    }
    
    private func processPhoto(_ image: UIImage) async {
        await viewModel.processMenuPhoto(image)
    }
    
    private func sharePhoto(_ image: UIImage) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func retryCamera() async {
        cameraState = .initializing
        await requestCameraPermission()
    }
}

// MARK: - Camera State

enum CameraState {
    case initializing
    case permissionRequired
    case ready
    case capturing
    case reviewing
    case error
}

// MARK: - Preview

#Preview {
    MenuCaptureView()
        .environmentObject(AppCoordinator.preview)
}