//
//  OnboardingView.swift
//  Menu Visualizer
//
//  Privacy-focused onboarding with camera permissions and app introduction
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var currentPage = 0
    @State private var showingPermissionRequest = false
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    privacyPage.tag(1)
                    featuresPage.tag(2)
                    permissionsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom controls
                bottomControls
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    // MARK: - Welcome Page
    
    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon and title
            VStack(spacing: 24) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: currentPage)
                
                VStack(spacing: 8) {
                    Text("Welcome to Menuly")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Menu Reader")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Value proposition
            VStack(spacing: 16) {
                featureHighlight(
                    icon: "camera.fill",
                    title: "Capture Any Menu",
                    description: "Take a photo of any restaurant menu"
                )
                
                featureHighlight(
                    icon: "eye",
                    title: "Instant Recognition",
                    description: "AI reads and extracts dish information"
                )
                
                featureHighlight(
                    icon: "sparkles",
                    title: "Enhanced Descriptions",
                    description: "Get AI-generated dish visualizations"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Privacy Page
    
    private var privacyPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Privacy shield icon
            Image(systemName: "hand.raised.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Privacy First")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Your privacy is our top priority")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Privacy features
            VStack(spacing: 20) {
                privacyFeature(
                    icon: "iphone",
                    title: "Local Processing",
                    description: "Photos never leave your device"
                )
                
                privacyFeature(
                    icon: "eye.slash",
                    title: "No Data Collection",
                    description: "We don't store or track your data"
                )
                
                privacyFeature(
                    icon: "timer",
                    title: "Session Only",
                    description: "Data cleared when you close the app"
                )
                
                privacyFeature(
                    icon: "shield.checkered",
                    title: "Minimal API Usage",
                    description: "Only dish names sent for AI enhancement"
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Features Page
    
    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Features icon
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Powerful Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Everything you need to explore menus")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Feature list
            VStack(spacing: 20) {
                featureDetail(
                    icon: "doc.text.viewfinder",
                    title: "Smart OCR",
                    description: "Apple Vision technology reads any menu format",
                    color: .blue
                )
                
                featureDetail(
                    icon: "square.grid.3x3.fill.square",
                    title: "Auto Categorization",
                    description: "Dishes automatically sorted by category",
                    color: .green
                )
                
                featureDetail(
                    icon: "magnifyingglass",
                    title: "Search & Filter",
                    description: "Find dishes quickly with smart search",
                    color: .purple
                )
                
                featureDetail(
                    icon: "sparkles.square.filled.on.square",
                    title: "AI Visualizations",
                    description: "Enhanced descriptions with ingredients",
                    color: .orange
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Permissions Page
    
    private var permissionsPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Camera icon
            Image(systemName: cameraPermissionIcon)
                .font(.system(size: 80))
                .foregroundColor(cameraPermissionColor)
            
            VStack(spacing: 16) {
                Text("Camera Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(cameraPermissionMessage)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Permission explanation
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photos stay on your device")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("Never uploaded or stored remotely")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local text recognition")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("Apple Vision processes everything locally")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? .blue : .gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentPage ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            
            // Navigation buttons
            HStack(spacing: 16) {
                // Back button
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.gray.opacity(0.2), in: Capsule())
                        .foregroundColor(.primary)
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
                
                // Next/Finish button
                Button {
                    handleNextButtonTap()
                } label: {
                    HStack(spacing: 8) {
                        Text(nextButtonText)
                        if currentPage < totalPages - 1 {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(nextButtonColor, in: Capsule())
                    .foregroundColor(.white)
                }
                .disabled(!canProceed)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Views
    
    private func featureHighlight(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func privacyFeature(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func featureDetail(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var nextButtonText: String {
        switch currentPage {
        case totalPages - 1:
            return cameraPermissionStatus == .authorized ? "Get Started" : "Enable Camera"
        default:
            return "Next"
        }
    }
    
    private var nextButtonColor: Color {
        switch currentPage {
        case totalPages - 1:
            return cameraPermissionStatus == .authorized ? .green : .blue
        default:
            return .blue
        }
    }
    
    private var canProceed: Bool {
        if currentPage == totalPages - 1 {
            return cameraPermissionStatus != .denied
        }
        return true
    }
    
    private var cameraPermissionIcon: String {
        switch cameraPermissionStatus {
        case .authorized:
            return "camera.fill"
        case .denied:
            return "camera.fill.badge.ellipsis"
        default:
            return "camera"
        }
    }
    
    private var cameraPermissionColor: Color {
        switch cameraPermissionStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        default:
            return .blue
        }
    }
    
    private var cameraPermissionMessage: String {
        switch cameraPermissionStatus {
        case .authorized:
            return "Camera access granted! You're ready to scan menus."
        case .denied:
            return "Camera access is required to scan menus. Please enable in Settings."
        default:
            return "We need camera access to read menu photos"
        }
    }
    
    // MARK: - Methods
    
    private func handleNextButtonTap() {
        if currentPage < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            // Last page - handle permission or finish
            if cameraPermissionStatus == .notDetermined {
                requestCameraPermission()
            } else {
                finishOnboarding()
            }
        }
    }
    
    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraPermissionStatus = granted ? .authorized : .denied
                if granted {
                    self.finishOnboarding()
                }
            }
        }
    }
    
    private func finishOnboarding() {
        hasSeenOnboarding = true
        coordinator.updateState(.idle)
        coordinator.navigateToRoot()
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppCoordinator.preview)
}