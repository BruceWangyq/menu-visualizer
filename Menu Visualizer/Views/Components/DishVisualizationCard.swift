//
//  DishVisualizationCard.swift
//  Menu Visualizer
//
//  Compact dish visualization card for list views with progressive disclosure
//  Designed to be appetizing and encourage exploration
//

import SwiftUI

struct DishVisualizationCard: View {
    // MARK: - Properties
    
    let dish: Dish
    let onTap: () -> Void
    let onVisualize: () -> Void
    let onFavorite: () -> Void
    
    @State private var isFavorite: Bool = false
    @State private var showingVisualizationPreview = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header section with dish info
                headerSection
                
                // Visualization preview or generation prompt
                if let visualization = dish.aiVisualization {
                    visualizationPreviewSection(visualization)
                } else if dish.isGenerating {
                    generatingSection
                } else {
                    generatePromptSection
                }
                
                // Footer with actions and status
                footerSection
            }
            .background(.regularMaterial)
            .appCard(cornerRadius: AppSpacing.cornerRadiusLarge)
            .accessibleVisualizationCard(
                dishName: dish.name,
                hasVisualization: dish.aiVisualization != nil,
                isGenerating: dish.isGenerating
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Dish name and category
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(dish.name)
                        .font(AppTypography.dishNameSmall)
                        .foregroundColor(.charcoalGray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    categoryBadge
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    // Price
                    if let price = dish.price {
                        Text(price)
                            .font(AppTypography.emphasisBold)
                            .foregroundColor(.herbGreen)
                    }
                    
                    // Confidence indicator
                    confidenceIndicator
                }
            }
            
            // Original description
            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.midGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.md)
    }
    
    private var categoryBadge: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(dish.category?.icon ?? "❓")
                .font(.caption)
            
            Text(dish.category?.rawValue ?? "Unknown")
                .font(AppTypography.captionLarge)
                .fontWeight(.medium)
        }
        .padding(.horizontal, AppSpacing.chipPadding)
        .padding(.vertical, AppSpacing.xs)
        .background(
            categoryColor.opacity(0.12),
            in: Capsule()
        )
        .foregroundColor(categoryColor)
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 6, height: 6)
            
            Text("\(Int(dish.confidence * 100))%")
                .font(AppTypography.captionSmall)
                .foregroundColor(.midGray)
        }
    }
    
    // MARK: - Visualization Sections
    
    private func visualizationPreviewSection(_ visualization: DishVisualization) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Preview header
            HStack {
                Label("AI Enhanced", systemImage: "sparkles")
                    .font(AppTypography.captionLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.spiceOrange)
                
                Spacer()
                
                Button {
                    withAnimation(AppAnimations.standardEase) {
                        showingVisualizationPreview.toggle()
                    }
                } label: {
                    Image(systemName: showingVisualizationPreview ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.midGray)
                }
                .buttonStyle(.plain)
            }
            
            // Expandable preview content
            if showingVisualizationPreview {
                visualizationPreviewContent(visualization)
            } else {
                visualizationTeaser(visualization)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.md)
    }
    
    private func visualizationTeaser(_ visualization: DishVisualization) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Key ingredients preview
            if !visualization.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Key Ingredients")
                        .font(AppTypography.captionLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.charcoalGray)
                    
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(Array(visualization.ingredients.prefix(3)), id: \.self) { ingredient in
                            Text(ingredient)
                                .ingredientChip()
                        }
                        
                        if visualization.ingredients.count > 3 {
                            Text("+\(visualization.ingredients.count - 3)")
                                .font(AppTypography.captionSmall)
                                .fontWeight(.medium)
                                .foregroundColor(.midGray)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Enhanced description indicator
            VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                Image(systemName: "text.quote")
                    .font(.title3)
                    .foregroundColor(.goldenYellow)
                
                Text("Enhanced")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(.midGray)
            }
        }
    }
    
    private func visualizationPreviewContent(_ visualization: DishVisualization) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Enhanced description preview
            Text(visualization.generatedDescription)
                .font(AppTypography.sensoryItalic)
                .foregroundColor(.charcoalGray)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Ingredients grid
            if !visualization.ingredients.isEmpty {
                ingredientsPreview(visualization.ingredients)
            }
            
            // Quick visual style hint
            if !visualization.visualStyle.isEmpty {
                HStack {
                    Image(systemName: "paintbrush.pointed")
                        .font(.caption)
                        .foregroundColor(.wineRed)
                    
                    Text(visualization.visualStyle)
                        .font(AppTypography.captionLarge)
                        .italic()
                        .foregroundColor(.midGray)
                        .lineLimit(1)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func ingredientsPreview(_ ingredients: [String]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.adaptive(minimum: 80)), count: 3),
            spacing: AppSpacing.xs
        ) {
            ForEach(Array(ingredients.prefix(6)), id: \.self) { ingredient in
                Text(ingredient)
                    .ingredientChip(
                        backgroundColor: .vegetarianGreen.opacity(0.1),
                        foregroundColor: .vegetarianGreen
                    )
                    .accessibleIngredientChip(ingredient)
            }
            
            if ingredients.count > 6 {
                Text("+\(ingredients.count - 6) more")
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .padding(.horizontal, AppSpacing.chipPadding)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.lightGray.opacity(0.3), in: Capsule())
                    .foregroundColor(.midGray)
            }
        }
    }
    
    private var generatingSection: some View {
        LoadingVisualizationStyle(dishName: dish.name)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.md)
    }
    
    private var generatePromptSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title2)
                    .foregroundColor(Color.spiceOrange.opacity(0.7))
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Create AI Visualization")
                        .font(AppTypography.highlightMedium)
                        .foregroundColor(.charcoalGray)
                    
                    Text("Enhanced description with ingredients and presentation")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(.midGray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    onVisualize()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "sparkles")
                        Text("Generate")
                    }
                    .font(AppTypography.buttonTextSmall)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.spiceOrange, in: Capsule())
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .shadow(color: AppShadows.buttonShadow, radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.md)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            // Status indicator
            statusIndicator
            
            Spacer()
            
            // Action buttons
            HStack(spacing: AppSpacing.md) {
                // Favorite button
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isFavorite ? .appetiteRed : .midGray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                
                // Regenerate visualization button (if exists)
                if dish.aiVisualization != nil {
                    Button(action: onVisualize) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(Color.spiceOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Regenerate visualization")
                }
                
                // Navigation indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.lightGray)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.cardPadding)
    }
    
    private var statusIndicator: some View {
        Group {
            if dish.aiVisualization != nil {
                Label("AI Enhanced", systemImage: "checkmark.circle.fill")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(.successGreen)
            } else if dish.isGenerating {
                Label("Generating...", systemImage: "hourglass")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(Color.spiceOrange)
            } else {
                Label("Ready to enhance", systemImage: "plus.circle")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(.midGray)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var categoryColor: Color {
        switch dish.category {
        case .appetizer: return .goldenYellow
        case .soup: return .warmOrange
        case .salad: return .sageGreen
        case .mainCourse: return .appetiteRed
        case .pasta: return .goldenYellow
        case .seafood: return .glutenFreeBlue
        case .meat: return .wineRed
        case .vegetarian: return .vegetarianGreen
        case .dessert: return .organicPurple
        case .beverage: return .glutenFreeBlue
        case .special: return Color.spiceOrange
        case .unknown: return .midGray
        case .none: return .midGray
        }
    }
    
    private var confidenceColor: Color {
        switch dish.confidence {
        case 0.8...1.0: return .successGreen
        case 0.6..<0.8: return .warningAmber
        default: return .errorCoral
        }
    }
}

// MARK: - Preview

#Preview("With Visualization") {
    let visualization = DishVisualization(
        dishId: UUID(),
        generatedDescription: "A perfectly grilled Atlantic salmon fillet, seasoned with fresh herbs and garlic, served with a bright lemon sauce that enhances the natural flavors of the fish. The crispy skin contrasts beautifully with the tender, flaky interior.",
        visualStyle: "Elegant plating with vibrant colors and restaurant-quality presentation",
        ingredients: ["Atlantic Salmon", "Fresh Herbs", "Garlic", "Lemon", "Olive Oil", "Sea Salt", "Black Pepper", "Butter"],
        preparationNotes: "Grilled over medium-high heat for perfect doneness."
    )
    
    var sampleDish = Dish(
        name: "Grilled Atlantic Salmon",
        description: "Fresh salmon with lemon herbs and seasonal vegetables",
        price: "$28.99",
        category: .seafood,
        extractionConfidence: 0.95
    )
    
    let sampleDishWithVisualization = {
        var dish = sampleDish
        dish.aiVisualization = visualization
        return dish
    }()
    
    return VStack(spacing: 20) {
        DishVisualizationCard(
            dish: sampleDishWithVisualization,
            onTap: { print("Card tapped") },
            onVisualize: { print("Visualize tapped") },
            onFavorite: { print("Favorite tapped") }
        )
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Generating") {
    var generatingDish = Dish(
        name: "Truffle Mushroom Risotto",
        description: "Creamy arborio rice with wild mushrooms",
        price: "$24.99",
        category: .vegetarian,
        extractionConfidence: 0.88
    )
    
    let dishInProgress = {
        var dish = generatingDish
        dish.isGenerating = true
        return dish
    }()
    
    return VStack(spacing: 20) {
        DishVisualizationCard(
            dish: dishInProgress,
            onTap: { print("Card tapped") },
            onVisualize: { print("Visualize tapped") },
            onFavorite: { print("Favorite tapped") }
        )
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("No Visualization") {
    let plainDish = Dish(
        name: "Caesar Salad",
        description: "Fresh romaine lettuce with parmesan cheese and croutons",
        price: "$16.99",
        category: .salad,
        extractionConfidence: 0.92
    )
    
    VStack(spacing: 20) {
        DishVisualizationCard(
            dish: plainDish,
            onTap: { print("Card tapped") },
            onVisualize: { print("Visualize tapped") },
            onFavorite: { print("Favorite tapped") }
        )
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}