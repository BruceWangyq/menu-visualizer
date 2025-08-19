//
//  ComponentsIndex.swift
//  Menu Visualizer
//
//  Index file for AI visualization components
//  Ensures proper import and organization of visualization UI elements
//

import SwiftUI

// MARK: - Component Exports
// This file serves as a central index for all visualization components

// Design System
// - DesignSystem.swift: Core design tokens and styles

// Visualization Components
// - DishVisualizationCard.swift: Compact card for list views
// - ExpandedVisualizationView.swift: Full-screen detailed view
// - IngredientHighlightView.swift: Ingredient categorization and details
// - PreparationNotesView.swift: Cooking techniques and preparation guidance
// - CulturalContextView.swift: Cultural heritage and serving suggestions

// MARK: - Quick Access to Common Styles

extension View {
    /// Apply appetizing card styling to any view
    func appetizerCard() -> some View {
        self.appCard(
            background: Color.warmWhite,
            cornerRadius: AppSpacing.cornerRadiusLarge,
            shadowRadius: AppShadows.cardRadius
        )
    }
    
    /// Apply cultural context styling
    func culturalContextCard() -> some View {
        self
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: [Color.organicPurple.opacity(0.08), Color.organicPurple.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                    .stroke(Color.organicPurple.opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Apply preparation notes styling
    func preparationCard() -> some View {
        self
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: [Color.spiceOrange.opacity(0.08), Color.warmOrange.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                    .stroke(Color.spiceOrange.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Common Component Configurations

struct VisualizationConfig {
    static let cardSpacing = AppSpacing.md
    static let sectionSpacing = AppSpacing.sectionSpacing
    static let contentPadding = AppSpacing.cardPadding
    
    // Animation configurations
    static let quickAnimation = AppAnimations.quickEase
    static let standardAnimation = AppAnimations.standardEase
    static let bounceAnimation = AppAnimations.bouncy
    
    // Color configurations for different contexts
    static let primaryGradient = Color.warmGradient
    static let secondaryGradient = Color.appetiteGradient
    static let accentGradient = Color.earthGradient
}

// MARK: - Preview Helper Components

#if DEBUG
struct ComponentShowcase: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.sectionSpacing) {
                // Design system showcase
                designSystemShowcase
                
                // Component previews
                componentPreviews
            }
            .padding(AppSpacing.cardPadding)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Component Showcase")
    }
    
    private var designSystemShowcase: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Design System")
                .font(AppTypography.dishNameMedium)
                .foregroundColor(.charcoalGray)
            
            // Color palette
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppSpacing.sm) {
                colorSwatch("Appetite Red", .appetiteRed)
                colorSwatch("Warm Orange", .warmOrange)
                colorSwatch("Golden Yellow", .goldenYellow)
                colorSwatch("Sage Green", .sageGreen)
                colorSwatch("Spice Orange", .spiceOrange)
                colorSwatch("Herb Green", .herbGreen)
                colorSwatch("Wine Red", .wineRed)
                colorSwatch("Rich Brown", .richBrown)
            }
        }
        .appetizerCard()
    }
    
    private var componentPreviews: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Typography Samples")
                .font(AppTypography.dishNameMedium)
                .foregroundColor(.charcoalGray)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Grilled Atlantic Salmon")
                    .font(AppTypography.dishNameLarge)
                    .foregroundColor(.appetiteRed)
                
                Text("A perfectly seasoned fillet with aromatic herbs")
                    .font(AppTypography.sensoryItalic)
                    .foregroundColor(.midGray)
                
                Text("Fresh dill, garlic, lemon zest")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.charcoalGray)
                
                HStack {
                    Text("Mediterranean")
                        .ingredientChip(backgroundColor: .sageGreen.opacity(0.15), foregroundColor: .sageGreen)
                    
                    Text("Seafood")
                        .ingredientChip(backgroundColor: .glutenFreeBlue.opacity(0.15), foregroundColor: .glutenFreeBlue)
                    
                    Text("Gluten Free")
                        .ingredientChip(backgroundColor: .vegetarianGreen.opacity(0.15), foregroundColor: .vegetarianGreen)
                }
            }
        }
        .appetizerCard()
    }
    
    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSmall)
                .fill(color)
                .frame(height: 40)
            
            Text(name)
                .font(AppTypography.captionSmall)
                .multilineTextAlignment(.center)
                .foregroundColor(.charcoalGray)
        }
    }
}

struct ComponentShowcase_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ComponentShowcase()
        }
    }
}
#endif