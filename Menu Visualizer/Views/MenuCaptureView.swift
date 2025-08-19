//
//  MenuCaptureView.swift
//  Menu Visualizer
//
//  Main camera capture view for menu photography
//

import SwiftUI
import AVFoundation

struct MenuCaptureView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: MenuCaptureViewModel
    @StateObject private var permissionManager = CameraPermissionManager()
    @State private var showingSettings = false
    @State private var focusPoint: CGPoint?
    
    init() {
        // Initialize with placeholder coordinator, will be replaced by environment
        _viewModel = StateObject(wrappedValue: MenuCaptureViewModel(coordinator: AppCoordinator()))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Main content
                    Spacer()
                    
                    if viewModel.isShowingCamera {
                        cameraView
                    } else if let image = viewModel.capturedImage {
                        capturedImageView(image)
                    } else {
                        welcomeView
                    }
                    
                    Spacer()
                    
                    // Controls
                    controlsView
                    
                    // Processing indicator
                    if viewModel.isProcessing {
                        processingView
                    }
                }
            }
        }
        .onAppear {
            // Update view model with environment coordinator
            viewModel.coordinator = coordinator
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Camera Error", isPresented: .constant(viewModel.currentError != nil)) {
            Button("Settings") {
                permissionManager.openAppSettings()
            }
            Button("Try Again") {
                Task {
                    await viewModel.retryLastOperation()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.currentError = nil
            }
        } message: {
            Text(viewModel.currentError?.localizedDescription ?? "")
        }
        .overlay {
            permissionManager.permissionAlerts()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Menuly")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            // App icon or illustration
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 16) {
                Text("Visualize Your Menu")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Take a photo of any menu and see beautiful AI-generated visualizations of each dish")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Privacy notice
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Privacy First")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Text("All processing happens on your device. No data is stored or shared.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    
    // MARK: - Camera View
    
    private var cameraView: some View {
        ZStack {
            if permissionManager.authorizationStatus == .authorized {
                CameraView(
                    cameraService: viewModel.cameraService,
                    permissionManager: permissionManager,
                    onCapture: { image in
                        Task {
                            await viewModel.processMenuPhoto(image)
                        }
                    },
                    onError: { error in
                        viewModel.handleError(error)
                    },
                    onFocusTap: { point in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            focusPoint = point
                        }
                        
                        // Clear focus indicator after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                focusPoint = nil
                            }
                        }
                    }
                )
            } else {
                // Permission needed view
                permissionPromptView
            }
            
            // Focus indicator
            if let point = focusPoint {
                FocusIndicator()
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .onAppear {
            Task {
                await permissionManager.requestCameraPermission()
            }
        }
    }
    
    private var permissionPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Camera Permission Required")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(permissionManager.privacyExplanation())
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Grant Camera Access") {
                permissionManager.presentPermissionGuidance()
            }
            .foregroundColor(.white)
            .padding()
            .background(.blue, in: Capsule())
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Captured Image View
    
    private func capturedImageView(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            
            // Action buttons
            HStack(spacing: 20) {
                Button {
                    viewModel.resetCapture()
                } label: {
                    Label("Retake", systemImage: "camera.rotate")
                        .foregroundColor(.white)
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                }
                
                Button {
                    Task {
                        await viewModel.processMenuPhoto(image)
                    }
                } label: {
                    Label("Process Menu", systemImage: "text.viewfinder")
                        .foregroundColor(.white)
                        .padding()
                        .background(.blue, in: Capsule())
                }
                .disabled(viewModel.isProcessing)
            }
        }
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        HStack {
            if !viewModel.isShowingCamera {
                // Gallery button (placeholder)
                Button {
                    // TODO: Implement photo library picker
                } label: {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .disabled(viewModel.isProcessing)
            }
            
            Spacer()
            
            // Main capture button
            Button {
                if viewModel.isShowingCamera {
                    Task {
                        await viewModel.capturePhoto()
                    }
                } else {
                    Task {
                        await viewModel.startCameraSession()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(.black, lineWidth: 2)
                        .frame(width: 70, height: 70)
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: viewModel.isShowingCamera ? "camera.fill" : "camera")
                            .font(.title)
                            .foregroundColor(.black)
                    }
                }
            }
            .disabled(viewModel.isProcessing || !viewModel.canCapture)
            
            Spacer()
            
            if !viewModel.isShowingCamera {
                // Settings or info button
                Button {
                    coordinator.navigate(to: .privacyPolicy)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: viewModel.processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text(viewModel.processingStatusText)
                .foregroundColor(.white)
                .font(.subheadline)
            
            // Performance metrics (if available)
            if let metrics = viewModel.performanceMetrics {
                Text("Processed in \(String(format: "%.1f", metrics.totalProcessingTime))s")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Cancel button
            if viewModel.isProcessing {
                Button("Cancel") {
                    viewModel.cancelCurrentOperation()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func openSettings() {
        permissionManager.openAppSettings()
    }
}

// MARK: - Camera Overlay View

struct CameraOverlayView: View {
    var body: some View {
        ZStack {
            // Viewfinder frame
            Rectangle()
                .stroke(.white, lineWidth: 2)
                .background(.clear)
            
            // Corner brackets
            VStack {
                HStack {
                    // Top-left corner
                    cornerBracket
                    Spacer()
                    // Top-right corner
                    cornerBracket
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    // Bottom-left corner
                    cornerBracket
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    // Bottom-right corner
                    cornerBracket
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(8)
            
            // Instructions
            VStack {
                Spacer()
                
                Text("Position menu within frame")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                
                Spacer().frame(height: 20)
            }
        }
    }
    
    private var cornerBracket: some View {
        Path { path in
            let length: CGFloat = 20
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        }
        .stroke(.white, lineWidth: 3)
        .frame(width: 20, height: 20)
    }
}

// MARK: - Focus Indicator

struct FocusIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(isAnimating ? 1.0 : 1.5)
            .opacity(isAnimating ? 0.8 : 0.2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    MenuCaptureView()
        .environmentObject(AppCoordinator.preview)
}