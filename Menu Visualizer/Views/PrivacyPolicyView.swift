//
//  PrivacyPolicyView.swift
//  Menu Visualizer
//
//  Placeholder privacy policy view
//

import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Privacy Policy")
                .font(AppTypography.dishNameLarge)
                .foregroundColor(.charcoalGray)
            
            Text("Privacy policy content coming soon")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.midGray)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
            .environmentObject(AppCoordinator.preview)
    }
}