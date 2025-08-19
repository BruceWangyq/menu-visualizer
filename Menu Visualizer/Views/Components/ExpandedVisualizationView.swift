//
//  ExpandedVisualizationView.swift
//  Menu Visualizer
//
//  Full-screen rich visualization experience for AI-generated dish content
//  Multiple sections with interactive elements and share functionality
//

import SwiftUI

struct ExpandedVisualizationView: View {
    // MARK: - Properties
    
    let dish: Dish
    let visualization: DishVisualization
    let onRegenerate: () -> Void
    let onShare: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedTab: VisualizationTab = .overview
    @State private var showingShareSheet = false
    @State private var isRegenerating = false
    @State private var scrollOffset: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Hero header section
                        heroHeaderSection(geometry: geometry)
                        
                        // Tab navigation
                        tabNavigationSection
                        
                        // Content sections
                        contentSection
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: onDismiss)
                        .font(AppTypography.buttonTextSmall)
                        .foregroundColor(.spiceOrange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        shareMenuItems
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.charcoalGray)
                    }
                }
            }
            .background(backgroundGradient)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
    }
    
    // MARK: - Hero Header Section
    
    private func heroHeaderSection(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [Color.appetiteRed.opacity(0.15), Color.warmOrange.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280 - min(scrollOffset, 80))
            .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Dish name and category
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(dish.name)
                        .font(AppTypography.dishNameLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.charcoalGray)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        categoryBadge
                        
                        Spacer()
                        
                        if let price = dish.price {
                            Text(price)
                                .font(AppTypography.emphasisBold)
                                .foregroundColor(.herbGreen)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(.herbGreen.opacity(0.1), in: Capsule())
                        }
                    }
                }
                
                // AI enhancement indicator
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.spiceOrange)
                    
                    Text("AI Enhanced Visualization")
                        .font(AppTypography.highlightMedium)
                        .foregroundColor(.spiceOrange)
                    
                    Spacer()
                    
                    Button {
                        regenerateVisualization()
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            if isRegenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Regenerate")
                        }
                        .font(AppTypography.buttonTextSmall)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.spiceOrange, in: Capsule())
                        .foregroundColor(.white)
                    }
                    .disabled(isRegenerating)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
            }
        )
    }
    
    private var categoryBadge: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(dish.category.icon)
                .font(.title3)
            
            Text(dish.category.rawValue)
                .font(AppTypography.highlightMedium)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(categoryColor.opacity(0.15), in: Capsule())
        .foregroundColor(categoryColor)
    }
    
    // MARK: - Tab Navigation Section
    
    private var tabNavigationSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(VisualizationTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
        }
        .background(.regularMaterial)
    }
    
    private func tabButton(for tab: VisualizationTab) -> some View {
        Button {
            withAnimation(AppAnimations.standardEase) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14))
                    
                    Text(tab.title)
                        .font(AppTypography.labelSmall)
                }
                .foregroundColor(selectedTab == tab ? .spiceOrange : .midGray)
                
                Rectangle()
                    .fill(selectedTab == tab ? .spiceOrange : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        Group {
            switch selectedTab {
            case .overview:
                overviewContent
            case .ingredients:
                ingredientsContent
            case .preparation:
                preparationContent
            case .cultural:
                culturalContent
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        .animation(AppAnimations.standardEase, value: selectedTab)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            // Enhanced description
            enhancedDescriptionSection
            
            // Quick highlights
            quickHighlightsSection
            
            // Visual style
            visualStyleSection
        }
        .padding(AppSpacing.cardPadding)
    }
    
    private var enhancedDescriptionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Enhanced Description",
                icon: "text.quote",
                color: .goldenYellow
            )
            
            Text(visualization.generatedDescription)
                .font(AppTypography.sensoryItalic)
                .foregroundColor(.charcoalGray)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .padding(AppSpacing.lg)
                .background(.warmWhite, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                        .stroke(Color.goldenYellow.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var quickHighlightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Quick Highlights",
                icon: "star.fill",
                color: .spiceOrange
            )
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 2),
                spacing: AppSpacing.md
            ) {
                highlightCard(
                    icon: "leaf.fill",
                    title: "Fresh Ingredients",
                    subtitle: "\(visualization.ingredients.count) key items",
                    color: .vegetarianGreen
                )
                
                highlightCard(
                    icon: "flame.fill",
                    title: "Preparation",
                    subtitle: "Chef techniques",
                    color: .appetiteRed
                )
                
                if !visualization.visualStyle.isEmpty {
                    highlightCard(
                        icon: "paintbrush.pointed.fill",
                        title: "Presentation",
                        subtitle: "Restaurant style",
                        color: .organicPurple
                    )
                }
                
                highlightCard(
                    icon: "heart.fill",
                    title: "Quality",
                    subtitle: "\(Int(dish.confidence * 100))% confidence",
                    color: .wineRed
                )
            }
        }
    }
    
    private func highlightCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(AppTypography.highlightMedium)
                .foregroundColor(.charcoalGray)
            
            Text(subtitle)
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
    }
    
    private var visualStyleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if !visualization.visualStyle.isEmpty {
                sectionHeader(
                    title: "Visual Presentation",
                    icon: "paintbrush.pointed",
                    color: .organicPurple
                )
                
                Text(visualization.visualStyle)
                    .font(AppTypography.bodyMedium)
                    .italic()
                    .foregroundColor(.charcoalGray)
                    .padding(AppSpacing.lg)
                    .background(.softBeige, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
            }
        }
    }
    
    // MARK: - Ingredients Content
    
    private var ingredientsContent: some View {
        IngredientHighlightView(ingredients: visualization.ingredients)
            .padding(AppSpacing.cardPadding)
    }
    
    // MARK: - Preparation Content
    
    private var preparationContent: some View {
        PreparationNotesView(notes: visualization.preparationNotes)
            .padding(AppSpacing.cardPadding)
    }
    
    // MARK: - Cultural Content
    
    private var culturalContent: some View {
        CulturalContextView(
            dishName: dish.name,
            category: dish.category,
            ingredients: visualization.ingredients
        )
        .padding(AppSpacing.cardPadding)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(AppTypography.dishNameSmall)
                .foregroundColor(.charcoalGray)
            
            Spacer()
        }
    }
    
    private var shareMenuItems: some View {
        Group {
            Button {
                onShare(shareContent)
            } label: {
                Label("Share Dish Details", systemImage: "square.and.arrow.up")
            }
            
            Button {
                onShare(enhancedDescriptionOnly)
            } label: {
                Label("Share Description Only", systemImage: "text.quote")
            }
            
            Button {
                onShare(ingredientsListOnly)
            } label: {
                Label("Share Ingredients", systemImage: "list.bullet")
            }
            
            Divider()
            
            Button {
                // Copy to clipboard functionality would go here
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: some View {
        Color.warmGradient
            .ignoresSafeArea()
    }
    
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
        case .unknown: return .midGray
        }
    }
    
    private var shareContent: String {
        var content = "🍽️ \(dish.name)\n"
        if let price = dish.price {
            content += "💰 \(price)\n\n"
        }
        content += "✨ \(visualization.generatedDescription)\n\n"
        content += "🥘 Ingredients: \(visualization.ingredients.joined(separator: ", "))\n\n"
        if !visualization.preparationNotes.isEmpty {
            content += "👨‍🍳 \(visualization.preparationNotes)\n\n"
        }
        content += "📱 Shared from Menuly - Privacy-First Menu Reader"
        return content
    }
    
    private var enhancedDescriptionOnly: String {
        "🍽️ \(dish.name)\n\n✨ \(visualization.generatedDescription)\n\n📱 Shared from Menuly"
    }
    
    private var ingredientsListOnly: String {
        "🥘 \(dish.name) - Ingredients:\n\n\(visualization.ingredients.joined(separator: "\n• "))\n\n📱 Shared from Menuly"
    }
    
    // MARK: - Methods
    
    private func regenerateVisualization() {
        withAnimation(AppAnimations.standardEase) {
            isRegenerating = true
        }
        
        onRegenerate()
        
        // Simulate regeneration time - in real implementation this would be handled by the callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(AppAnimations.standardEase) {
                isRegenerating = false
            }
        }
    }
}

// MARK: - Visualization Tab Enum

enum VisualizationTab: String, CaseIterable {
    case overview = "Overview"
    case ingredients = "Ingredients"
    case preparation = "Preparation"
    case cultural = "Cultural"
    
    var title: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .overview: return "doc.text"
        case .ingredients: return "leaf.fill"
        case .preparation: return "flame.fill"
        case .cultural: return "globe"
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let visualization = DishVisualization(
        dishId: UUID(),
        generatedDescription: "A masterfully prepared Atlantic salmon fillet, grilled to perfection with a golden, crispy skin that gives way to tender, flaky pink flesh. The fish is elegantly seasoned with fresh dill, garlic, and a hint of lemon zest, creating layers of flavor that dance on the palate. Served alongside vibrant seasonal vegetables and drizzled with a delicate lemon butter sauce that enhances the natural richness of the salmon.",
        visualStyle: "Restaurant-quality plating with vibrant colors, elegant garnishes, and professional presentation that emphasizes the natural beauty of the ingredients",
        ingredients: ["Atlantic Salmon", "Fresh Dill", "Garlic", "Lemon Zest", "Butter", "Olive Oil", "Sea Salt", "Black Pepper", "Seasonal Vegetables"],
        preparationNotes: "Grilled over medium-high heat for 6-8 minutes per side. The skin should be crispy and the flesh should flake easily with a fork. Finished with fresh herbs and lemon."
    )
    
    var sampleDish = Dish(
        name: "Grilled Atlantic Salmon",
        description: "Fresh salmon with seasonal vegetables",
        price: "$28.99",
        category: .seafood,
        confidence: 0.95
    )
    sampleDish.aiVisualization = visualization
    
    ExpandedVisualizationView(
        dish: sampleDish,
        visualization: visualization,
        onRegenerate: { print("Regenerate visualization") },
        onShare: { content in print("Share: \(content)") },
        onDismiss: { print("Dismiss") }
    )
}