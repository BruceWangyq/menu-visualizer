//
//  SettingsView.swift
//  Menu Visualizer
//
//  Placeholder settings view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Settings")
                .font(AppTypography.dishNameLarge)
                .foregroundColor(.charcoalGray)
            
            Text("Settings functionality coming soon")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.midGray)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(AppCoordinator.preview)
    }
}