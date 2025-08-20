//
//  VisualizationView.swift
//  Menu Visualizer
//
//  Placeholder visualization view for legacy navigation support
//  Use ExpandedVisualizationView for full functionality
//

import SwiftUI

struct VisualizationView: View {
    let dish: Dish
    @EnvironmentObject private var coordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            if let visualization = dish.aiVisualization {
                // Redirect to enhanced view
                ExpandedVisualizationView(
                    dish: dish,
                    visualization: visualization,
                    onRegenerate: {
                        // Handle regeneration
                    },
                    onShare: { content in
                        // Handle sharing
                    },
                    onDismiss: {
                        coordinator.navigateBack()
                    }
                )
            } else {
                // No visualization available
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 64))
                        .foregroundColor(.spiceOrange.opacity(0.5))
                    
                    Text("No Visualization Available")
                        .font(AppTypography.dishNameMedium)
                        .foregroundColor(.charcoalGray)
                    
                    Text("Return to the dish detail to generate an AI visualization")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(.midGray)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        coordinator.navigateBack()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.left")
                            Text("Back to Dish")
                        }
                        .font(AppTypography.buttonText)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.spiceOrange, in: Capsule())
                        .foregroundColor(.white)
                    }
                }
                .padding(AppSpacing.xl)
                .appetizerCard()
                .padding(AppSpacing.cardPadding)
            }
        }
        .navigationTitle("Visualization")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    let sampleDish = Dish(
        name: "Sample Dish",
        description: "A sample dish for preview",
        price: "$12.99",
        category: .mainCourse,
        extractionConfidence: 0.9
    )
    
    NavigationView {
        VisualizationView(dish: sampleDish)
            .environmentObject(AppCoordinator.preview)
    }
}