//
//  ContentView.swift
//  Menu Visualizer
//
//  Main app entry point with privacy-first architecture
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var pipeline = MenuProcessingPipeline()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    var body: some View {
        AppNavigationView()
            .environmentObject(coordinator)
            .environmentObject(pipeline)
            .onAppear {
                setupInitialState()
            }
            .onChange(of: pipeline.processingState) { _, newState in
                handleProcessingStateChange(newState)
            }
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialState() {
        if !hasSeenOnboarding {
            coordinator.updateState(.onboarding)
            coordinator.navigate(to: .onboarding)
        } else {
            coordinator.updateState(.idle)
        }
    }
    
    private func handleProcessingStateChange(_ state: ProcessingState) {
        switch state {
        case .idle:
            coordinator.updateState(.idle)
        case .processingOCR, .parsingMenu, .generatingVisualization:
            coordinator.updateState(.processing)
        case .completed:
            coordinator.updateState(.viewing)
            if let menu = pipeline.currentMenu {
                coordinator.navigate(to: .dishList(menu: menu))
            }
        case .error(let error):
            coordinator.updateState(.error(error))
            coordinator.handleError(error)
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
