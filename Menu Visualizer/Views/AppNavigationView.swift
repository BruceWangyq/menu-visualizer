//
//  AppNavigationView.swift
//  Menu Visualizer
//
//  Main navigation structure for the Menuly app
//

import SwiftUI

struct AppNavigationView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            mainContentView
                .navigationDestination(for: NavigationDestination.self) { destination in
                    coordinator.view(for: destination)
                }
        }
        .overlay {
            // Global processing overlay
            if pipeline.processingState.isProcessing {
                ProcessingStatusView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: pipeline.processingState.isProcessing)
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        switch coordinator.currentState {
        case .onboarding:
            OnboardingView()
        case .idle, .viewing:
            MenuCaptureView()
        case .processing:
            MenuCaptureView()
                .disabled(true)
        case .error:
            MenuCaptureView()
        }
    }
}

// MARK: - Main App Layout

struct MainAppView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    @State private var selectedTab: AppTab = .capture
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Capture Tab
            NavigationStack {
                MenuCaptureView()
                    .navigationTitle("Menuly")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                coordinator.navigate(to: .settings)
                            } label: {
                                Image(systemName: "gear")
                                    .fontWeight(.medium)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Capture", systemImage: "camera.fill")
            }
            .tag(AppTab.capture)
            
            // Recent Results Tab (if available)
            if let menu = pipeline.currentMenu {
                NavigationStack {
                    DishListView(menu: menu)
                        .navigationTitle("Menu")
                        .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Results", systemImage: "list.bullet")
                }
                .tag(AppTab.results)
            }
            
            // Privacy Tab
            NavigationStack {
                PrivacyDashboard()
                    .navigationTitle("Privacy")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Privacy", systemImage: "hand.raised.fill")
            }
            .tag(AppTab.privacy)
        }
        .tint(.primary)
    }
}

// MARK: - Supporting Types

enum AppTab: String, CaseIterable {
    case capture = "capture"
    case results = "results"
    case privacy = "privacy"
    
    var title: String {
        switch self {
        case .capture: return "Capture"
        case .results: return "Results"
        case .privacy: return "Privacy"
        }
    }
    
    var systemImage: String {
        switch self {
        case .capture: return "camera.fill"
        case .results: return "list.bullet"
        case .privacy: return "hand.raised.fill"
        }
    }
}

// MARK: - Preview

#Preview("Navigation View") {
    AppNavigationView()
        .environmentObject(AppCoordinator.preview)
        .environmentObject(MenuProcessingPipeline())
}

#Preview("Tab View") {
    MainAppView()
        .environmentObject(AppCoordinator.preview)
        .environmentObject(MenuProcessingPipeline())
}