//
//  IngredientHighlightView.swift
//  Menu Visualizer
//
//  Visual ingredient presentation with categories, dietary indicators, and interactive elements
//  Designed to make ingredients appetizing and informative
//

import SwiftUI

struct IngredientHighlightView: View {
    // MARK: - Properties
    
    let ingredients: [String]
    @State private var selectedCategory: IngredientCategory? = nil
    @State private var showingIngredientDetail: String? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            // Header section
            headerSection
            
            // Category filters
            categoryFilterSection
            
            // Ingredients grid
            ingredientsGridSection
            
            // Dietary summary
            dietarySummarySection
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.vegetarianGreen)
                
                Text("Key Ingredients")
                    .font(AppTypography.dishNameSmall)
                    .foregroundColor(.charcoalGray)
                
                Spacer()
                
                Text("\(filteredIngredients.count) items")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(.midGray)
                    .padding(.horizontal, AppSpacing.chipPadding)
                    .padding(.vertical, AppSpacing.xs)
                    .background(.lightGray.opacity(0.3), in: Capsule())
            }
            
            Text("Tap ingredients to learn more about their flavors and nutritional benefits")
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .italic()
        }
    }
    
    // MARK: - Category Filter Section
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                categoryFilterButton(for: nil, label: "All")
                
                ForEach(availableCategories, id: \.self) { category in
                    categoryFilterButton(for: category, label: category.displayName)
                }
            }
            .padding(.horizontal, 1) // Prevent clipping of shadows
        }
    }
    
    private func categoryFilterButton(for category: IngredientCategory?, label: String) -> some View {
        Button {
            withAnimation(AppAnimations.standardEase) {
                selectedCategory = selectedCategory == category ? nil : category
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                }
                
                Text(label)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
                
                if let category = category {
                    Text("\(ingredientCount(for: category))")
                        .font(AppTypography.captionSmall)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.5), in: Circle())
                }
            }
            .padding(.horizontal, AppSpacing.chipPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(
                backgroundForCategory(category),
                in: Capsule()
            )
            .foregroundColor(
                foregroundColorForCategory(category)
            )
            .shadow(
                color: selectedCategory == category ? AppShadows.cardShadow : .clear,
                radius: 2,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Ingredients Grid Section
    
    private var ingredientsGridSection: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 2),
            spacing: AppSpacing.md
        ) {
            ForEach(filteredIngredients, id: \.self) { ingredient in
                ingredientCard(ingredient)
            }
        }
    }
    
    private func ingredientCard(_ ingredient: String) -> some View {
        let category = categorizeIngredient(ingredient)
        let info = IngredientInfo.info(for: ingredient)
        
        return Button {
            withAnimation(AppAnimations.standardEase) {
                showingIngredientDetail = ingredient
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header with icon and category
                HStack {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(category.color)
                    
                    Spacer()
                    
                    // Dietary indicators
                    HStack(spacing: 2) {
                        ForEach(info.dietaryIndicators, id: \.self) { indicator in
                            Image(systemName: indicator.icon)
                                .font(.caption2)
                                .foregroundColor(indicator.color)
                        }
                    }
                }
                
                // Ingredient name
                Text(ingredient)
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Flavor notes
                if !info.flavorNotes.isEmpty {
                    Text(info.flavorNotes)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(.midGray)
                        .italic()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Category badge
                Text(category.displayName)
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 2)
                    .background(category.color.opacity(0.15), in: Capsule())
                    .foregroundColor(category.color)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.warmWhite, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                    .stroke(category.color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: AppShadows.cardShadow, radius: AppShadows.subtleRadius, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibleIngredientChip(ingredient)
        .sheet(item: Binding<IngredientDetailItem?>(
            get: { showingIngredientDetail.map { IngredientDetailItem(ingredient: $0) } },
            set: { showingIngredientDetail = $0?.ingredient }
        )) { item in
            IngredientDetailSheet(ingredient: item.ingredient)
        }
    }
    
    // MARK: - Dietary Summary Section
    
    private var dietarySummarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.successGreen)
                
                Text("Dietary Information")
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
            }
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 3),
                spacing: AppSpacing.sm
            ) {
                ForEach(dietarySummary, id: \.self) { indicator in
                    dietaryBadge(indicator)
                }
            }
            
            // Allergy information
            if !allergenWarnings.isEmpty {
                allergyWarningSection
            }
        }
        .padding(AppSpacing.lg)
        .background(.softBeige, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
    }
    
    private func dietaryBadge(_ indicator: DietaryIndicator) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: indicator.icon)
                .font(.title3)
                .foregroundColor(indicator.color)
            
            Text(indicator.rawValue)
                .font(AppTypography.captionLarge)
                .fontWeight(.medium)
                .foregroundColor(.charcoalGray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(indicator.backgroundColor, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSmall))
    }
    
    private var allergyWarningSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.warningAmber)
                
                Text("Allergen Information")
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(allergenWarnings, id: \.self) { allergen in
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(.warningAmber)
                        
                        Text(allergen)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(.charcoalGray)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(.warningAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSmall))
    }
    
    // MARK: - Computed Properties
    
    private var availableCategories: [IngredientCategory] {
        let categories = ingredients.map { categorizeIngredient($0) }
        return Array(Set(categories)).sorted { $0.displayName < $1.displayName }
    }
    
    private var filteredIngredients: [String] {
        guard let selectedCategory = selectedCategory else { return ingredients }
        return ingredients.filter { categorizeIngredient($0) == selectedCategory }
    }
    
    private var dietarySummary: [DietaryIndicator] {
        let allIndicators = ingredients.flatMap { IngredientInfo.info(for: $0).dietaryIndicators }
        let commonIndicators = Set(allIndicators)
        
        // Only show indicators that apply to most ingredients
        return Array(commonIndicators).filter { indicator in
            let count = allIndicators.filter { $0 == indicator }.count
            return Double(count) / Double(ingredients.count) >= 0.7 // 70% threshold
        }.sorted { $0.rawValue < $1.rawValue }
    }
    
    private var allergenWarnings: [String] {
        let allergens = ingredients.compactMap { IngredientInfo.info(for: $0).allergen }
        return Array(Set(allergens)).sorted()
    }
    
    // MARK: - Helper Methods
    
    private func ingredientCount(for category: IngredientCategory) -> Int {
        ingredients.filter { categorizeIngredient($0) == category }.count
    }
    
    private func backgroundForCategory(_ category: IngredientCategory?) -> Color {
        if selectedCategory == category {
            return category?.color ?? .spiceOrange
        }
        return .lightGray.opacity(0.3)
    }
    
    private func foregroundColorForCategory(_ category: IngredientCategory?) -> Color {
        if selectedCategory == category {
            return .white
        }
        return category?.color ?? .charcoalGray
    }
    
    private func categorizeIngredient(_ ingredient: String) -> IngredientCategory {
        return IngredientInfo.info(for: ingredient).category
    }
}

// MARK: - Ingredient Category Enum

enum IngredientCategory: String, CaseIterable, Hashable {
    case protein = "Protein"
    case vegetable = "Vegetable"
    case herb = "Herb"
    case spice = "Spice"
    case dairy = "Dairy"
    case grain = "Grain"
    case fruit = "Fruit"
    case oil = "Oil"
    case seasoning = "Seasoning"
    case other = "Other"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .protein: return "fish.fill"
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .spice: return "flame.fill"
        case .dairy: return "drop.fill"
        case .grain: return "circle.grid.2x2.fill"
        case .fruit: return "apple.logo"
        case .oil: return "drop.triangle.fill"
        case .seasoning: return "sparkles"
        case .other: return "circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .protein: return .appetiteRed
        case .vegetable: return .vegetarianGreen
        case .herb: return .sageGreen
        case .spice: return .spicyRed
        case .dairy: return .glutenFreeBlue
        case .grain: return .goldenYellow
        case .fruit: return .organicPurple
        case .oil: return .warmOrange
        case .seasoning: return .richBrown
        case .other: return .midGray
        }
    }
}

// MARK: - Ingredient Info Structure

struct IngredientInfo {
    let category: IngredientCategory
    let flavorNotes: String
    let dietaryIndicators: [DietaryIndicator]
    let allergen: String?
    
    static func info(for ingredient: String) -> IngredientInfo {
        let lowercased = ingredient.lowercased()
        
        // Proteins
        if lowercased.contains("salmon") || lowercased.contains("fish") || lowercased.contains("tuna") {
            return IngredientInfo(
                category: .protein,
                flavorNotes: "Rich, buttery with oceanic depth",
                dietaryIndicators: [],
                allergen: "Fish"
            )
        }
        
        if lowercased.contains("chicken") || lowercased.contains("beef") || lowercased.contains("pork") {
            return IngredientInfo(
                category: .protein,
                flavorNotes: "Savory and hearty",
                dietaryIndicators: [],
                allergen: nil
            )
        }
        
        // Herbs
        if lowercased.contains("basil") {
            return IngredientInfo(
                category: .herb,
                flavorNotes: "Sweet, aromatic with peppery finish",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("dill") || lowercased.contains("herb") {
            return IngredientInfo(
                category: .herb,
                flavorNotes: "Fresh, tangy with subtle citrus",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("parsley") || lowercased.contains("cilantro") {
            return IngredientInfo(
                category: .herb,
                flavorNotes: "Bright, fresh with earthy undertones",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Spices
        if lowercased.contains("garlic") {
            return IngredientInfo(
                category: .spice,
                flavorNotes: "Pungent, aromatic with sweet undertones",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("pepper") {
            return IngredientInfo(
                category: .spice,
                flavorNotes: "Sharp, warming with subtle heat",
                dietaryIndicators: [.vegetarian, .vegan, .spicy],
                allergen: nil
            )
        }
        
        if lowercased.contains("paprika") || lowercased.contains("cumin") {
            return IngredientInfo(
                category: .spice,
                flavorNotes: "Warm, earthy with smoky notes",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Vegetables
        if lowercased.contains("onion") {
            return IngredientInfo(
                category: .vegetable,
                flavorNotes: "Sweet when cooked, sharp when raw",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("tomato") {
            return IngredientInfo(
                category: .vegetable,
                flavorNotes: "Bright acidity with umami depth",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("mushroom") {
            return IngredientInfo(
                category: .vegetable,
                flavorNotes: "Earthy, umami-rich with meaty texture",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Dairy
        if lowercased.contains("cheese") || lowercased.contains("parmesan") {
            return IngredientInfo(
                category: .dairy,
                flavorNotes: "Rich, nutty with sharp complexity",
                dietaryIndicators: [.vegetarian],
                allergen: "Dairy"
            )
        }
        
        if lowercased.contains("butter") {
            return IngredientInfo(
                category: .dairy,
                flavorNotes: "Rich, creamy with sweet undertones",
                dietaryIndicators: [.vegetarian],
                allergen: "Dairy"
            )
        }
        
        if lowercased.contains("cream") {
            return IngredientInfo(
                category: .dairy,
                flavorNotes: "Smooth, luxurious mouthfeel",
                dietaryIndicators: [.vegetarian],
                allergen: "Dairy"
            )
        }
        
        // Oils
        if lowercased.contains("olive oil") {
            return IngredientInfo(
                category: .oil,
                flavorNotes: "Fruity with peppery finish",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("oil") {
            return IngredientInfo(
                category: .oil,
                flavorNotes: "Neutral base for cooking",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Fruits
        if lowercased.contains("lemon") {
            return IngredientInfo(
                category: .fruit,
                flavorNotes: "Bright citrus with clean acidity",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("lime") {
            return IngredientInfo(
                category: .fruit,
                flavorNotes: "Tart citrus with tropical notes",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Seasonings
        if lowercased.contains("salt") {
            return IngredientInfo(
                category: .seasoning,
                flavorNotes: "Enhances and balances all flavors",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        if lowercased.contains("vinegar") {
            return IngredientInfo(
                category: .seasoning,
                flavorNotes: "Sharp acidity with complex undertones",
                dietaryIndicators: [.vegetarian, .vegan],
                allergen: nil
            )
        }
        
        // Grains
        if lowercased.contains("rice") || lowercased.contains("pasta") || lowercased.contains("bread") {
            return IngredientInfo(
                category: .grain,
                flavorNotes: "Neutral base with subtle nuttiness",
                dietaryIndicators: [.vegetarian],
                allergen: "Gluten"
            )
        }
        
        // Default case
        return IngredientInfo(
            category: .other,
            flavorNotes: "Unique flavor contribution",
            dietaryIndicators: [.vegetarian, .vegan],
            allergen: nil
        )
    }
}

// MARK: - Supporting Types

struct IngredientDetailItem: Identifiable {
    let id = UUID()
    let ingredient: String
}

struct IngredientDetailSheet: View {
    let ingredient: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                let info = IngredientInfo.info(for: ingredient)
                
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: info.category.icon)
                            .font(.title)
                            .foregroundColor(info.category.color)
                        
                        Text(ingredient)
                            .font(AppTypography.dishNameMedium)
                            .foregroundColor(.charcoalGray)
                    }
                    
                    Text(info.category.displayName)
                        .font(AppTypography.highlightMedium)
                        .foregroundColor(info.category.color)
                        .padding(.horizontal, AppSpacing.chipPadding)
                        .padding(.vertical, AppSpacing.xs)
                        .background(info.category.color.opacity(0.15), in: Capsule())
                }
                
                // Flavor notes
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Flavor Profile")
                        .font(AppTypography.highlightMedium)
                        .foregroundColor(.charcoalGray)
                    
                    Text(info.flavorNotes)
                        .font(AppTypography.sensoryItalic)
                        .foregroundColor(.midGray)
                        .padding(AppSpacing.md)
                        .background(.softBeige, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSmall))
                }
                
                // Dietary indicators
                if !info.dietaryIndicators.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Dietary Information")
                            .font(AppTypography.highlightMedium)
                            .foregroundColor(.charcoalGray)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppSpacing.sm) {
                            ForEach(info.dietaryIndicators, id: \.self) { indicator in
                                HStack {
                                    Image(systemName: indicator.icon)
                                        .foregroundColor(indicator.color)
                                    Text(indicator.rawValue)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(.charcoalGray)
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(indicator.backgroundColor, in: Capsule())
                            }
                        }
                    }
                }
                
                // Allergen warning
                if let allergen = info.allergen {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.warningAmber)
                            Text("Allergen Information")
                                .font(AppTypography.highlightMedium)
                                .foregroundColor(.charcoalGray)
                        }
                        
                        Text("Contains: \(allergen)")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.charcoalGray)
                            .padding(AppSpacing.md)
                            .background(.warningAmber.opacity(0.1), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSmall))
                    }
                }
                
                Spacer()
            }
            .padding(AppSpacing.cardPadding)
            .navigationTitle("Ingredient Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleIngredients = [
        "Atlantic Salmon", "Fresh Dill", "Garlic", "Lemon", "Olive Oil",
        "Sea Salt", "Black Pepper", "Butter", "Parmesan Cheese", "Fresh Basil",
        "Cherry Tomatoes", "Red Onion", "Mushrooms", "Rice", "Paprika"
    ]
    
    ScrollView {
        IngredientHighlightView(ingredients: sampleIngredients)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}