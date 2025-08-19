//
//  AppCoordinator.swift
//  Menu Visualizer
//
//  Navigation coordinator for privacy-first app architecture
//

import SwiftUI

/// App-wide states for UI coordination
enum AppState: Equatable {
    case idle
    case onboarding
    case processing
    case viewing
    case error(MenulyError)
    
    var isProcessing: Bool {
        switch self {
        case .processing:
            return true
        default:
            return false
        }
    }
}

/// Navigation destinations for the app
enum NavigationDestination: Hashable {
    case onboarding
    case menuCapture
    case dishList(menu: Menu)
    case dishDetail(dish: Dish)
    case visualization(dish: Dish)
    case expandedVisualization(dish: Dish, visualization: DishVisualization)
    case settings
    case privacyPolicy
    case privacyDashboard
    case errorRecovery(error: MenulyError)
}

/// Centralized navigation coordinator following MVVM pattern
@MainActor
final class AppCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentState: AppState = .idle
    
    // MARK: - Navigation Methods
    
    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }
    
    func replace(with destination: NavigationDestination) {
        navigationPath = NavigationPath()
        navigationPath.append(destination)
    }
    
    // MARK: - View Factory
    
    @ViewBuilder
    func view(for destination: NavigationDestination) -> some View {
        switch destination {
        case .onboarding:
            OnboardingView()
                .environmentObject(self)
            
        case .menuCapture:
            MenuCaptureView()
                .environmentObject(self)
            
        case .dishList(let menu):
            DishListView(menu: menu)
                .environmentObject(self)
            
        case .dishDetail(let dish):
            DishDetailView(dish: dish)
                .environmentObject(self)
            
        case .visualization(let dish):
            VisualizationView(dish: dish)
                .environmentObject(self)
            
        case .expandedVisualization(let dish, let visualization):
            ExpandedVisualizationView(
                dish: dish,
                visualization: visualization,
                onRegenerate: {
                    // Handle regeneration - could trigger pipeline regeneration
                },
                onShare: { content in
                    // Handle sharing - could present share sheet
                },
                onDismiss: {
                    self.navigateBack()
                }
            )
            .environmentObject(self)
            
        case .settings:
            SettingsView()
                .environmentObject(self)
            
        case .privacyPolicy:
            PrivacyPolicyView()
                .environmentObject(self)
            
        case .privacyDashboard:
            PrivacyDashboard()
                .environmentObject(self)
            
        case .errorRecovery(let error):
            ErrorRecoveryView(error: error)
                .environmentObject(self)
        }
    }
    
    // MARK: - State Management
    
    func updateState(_ newState: AppState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentState = newState
        }
    }
    
    func handleError(_ error: MenulyError) {
        updateState(.error(error))
        navigate(to: .errorRecovery(error: error))
    }
    
    func recoverFromError() {
        updateState(.idle)
        navigateBack()
    }
}

// MARK: - Preview Helpers

extension AppCoordinator {
    static var preview: AppCoordinator {
        let coordinator = AppCoordinator()
        return coordinator
    }
}