//
//  ErrorRecoveryView.swift
//  Menu Visualizer
//
//  Placeholder error recovery view
//

import SwiftUI

struct ErrorRecoveryView: View {
    let error: MenulyError
    @EnvironmentObject private var coordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.errorCoral)
            
            Text("Something went wrong")
                .font(AppTypography.dishNameMedium)
                .foregroundColor(.charcoalGray)
            
            Text(error.localizedDescription)
                .font(AppTypography.bodyMedium)
                .foregroundColor(.midGray)
                .multilineTextAlignment(.center)
            
            Button {
                coordinator.recoverFromError()
            } label: {
                Text("Try Again")
                    .font(AppTypography.buttonText)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.spiceOrange, in: Capsule())
                    .foregroundColor(.white)
            }
        }
        .padding(AppSpacing.xl)
        .navigationTitle("Error")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        ErrorRecoveryView(error: .networkError("Connection failed"))
            .environmentObject(AppCoordinator.preview)
    }
}