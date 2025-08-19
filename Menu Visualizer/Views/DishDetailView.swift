//
//  DishDetailView.swift
//  Menu Visualizer
//
//  Detailed view for individual dishes with AI visualization
//

import SwiftUI

struct DishDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    let dish: Dish
    @State private var isGeneratingVisualization = false
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header section
                headerSection
                
                // AI Visualization section
                if let visualization = currentVisualization {
                    visualizationSection(visualization)
                } else {
                    generateVisualizationSection
                }
                
                // Dish details section
                dishDetailsSection
                
                // Actions section
                actionsSection
            }
            .padding()
        }
        .navigationTitle(dish.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareButton
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dish name and category
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(dish.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        // Category badge
                        HStack(spacing: 6) {
                            Text(dish.category.icon)
                                .font(.title3)
                            Text(dish.category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundColor(.blue)
                        
                        // Confidence indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(confidenceColor(dish.confidence))
                                .frame(width: 8, height: 8)
                            Text("\(Int(dish.confidence * 100))% confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price
                if let price = dish.price {
                    Text(price)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Description
            if let description = dish.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Visualization Section
    
    private func visualizationSection(_ visualization: DishVisualization) -> some View {
        VStack(spacing: 0) {
            // Enhanced visualization button
            Button {
                // Navigate to expanded visualization view
                coordinator.navigate(to: .expandedVisualization(dish: dish, visualization: visualization))
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Section header
                    HStack {
                        Label("AI Enhanced Visualization", systemImage: "sparkles")
                            .font(AppTypography.highlightMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.spiceOrange)
                        
                        Spacer()
                        
                        HStack(spacing: AppSpacing.xs) {
                            Text("View Details")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(.spiceOrange)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.spiceOrange)
                        }
                    }
                    
                    // Quick preview with enhanced styling
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Enhanced description preview
                        Text(visualization.generatedDescription)
                            .font(AppTypography.sensoryItalic)
                            .foregroundColor(.charcoalGray)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        
                        // Ingredients preview
                        if !visualization.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Key Ingredients")
                                    .font(AppTypography.captionLarge)
                                    .fontWeight(.medium)
                                    .foregroundColor(.charcoalGray)
                                
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 100))
                                ], spacing: AppSpacing.xs) {
                                    ForEach(Array(visualization.ingredients.prefix(6)), id: \.self) { ingredient in
                                        Text(ingredient)
                                            .ingredientChip()
                                    }
                                    
                                    if visualization.ingredients.count > 6 {
                                        Text("+\(visualization.ingredients.count - 6) more")
                                            .font(AppTypography.captionSmall)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, AppSpacing.chipPadding)
                                            .padding(.vertical, AppSpacing.xs)
                                            .background(.lightGray.opacity(0.3), in: Capsule())
                                            .foregroundColor(.midGray)
                                    }
                                }
                            }
                        }
                        
                        // Quick action buttons
                        HStack {
                            Button {
                                Task {
                                    await regenerateVisualization()
                                }
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    if isGeneratingVisualization {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text("Regenerate")
                                }
                                .font(AppTypography.captionLarge)
                                .fontWeight(.medium)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(.warmGray.opacity(0.2), in: Capsule())
                                .foregroundColor(.warmGray)
                            }
                            .disabled(isGeneratingVisualization)
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.title3)
                                .foregroundColor(.spiceOrange.opacity(0.7))
                        }
                    }
                }
                .padding(AppSpacing.cardPadding)
                .background(
                    LinearGradient(
                        colors: [Color.warmOrange.opacity(0.08), Color.goldenYellow.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge)
                        .stroke(Color.spiceOrange.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var generateVisualizationSection: some View {
        VStack(spacing: AppSpacing.md) {
            if isGeneratingVisualization || dish.isGenerating {
                // Enhanced loading state
                LoadingVisualizationStyle(dishName: dish.name)
            } else {
                // Enhanced generate button
                VStack(spacing: AppSpacing.lg) {
                    // Icon and title
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 56))
                            .foregroundColor(.spiceOrange)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("Create AI Visualization")
                            .font(AppTypography.dishNameSmall)
                            .fontWeight(.bold)
                            .foregroundColor(.charcoalGray)
                        
                        Text("Generate an enhanced description with ingredients, preparation techniques, and cultural context")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.midGray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    // Features preview
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppSpacing.sm) {
                        featurePreview(icon: "text.quote", title: "Rich Description", color: .goldenYellow)
                        featurePreview(icon: "leaf.fill", title: "Ingredients", color: .vegetarianGreen)
                        featurePreview(icon: "flame.fill", title: "Preparation", color: .appetiteRed)
                        featurePreview(icon: "globe", title: "Cultural Context", color: .organicPurple)
                    }
                    
                    // Generate button
                    Button {
                        Task {
                            await generateVisualization()
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                            Text("Generate Visualization")
                                .font(AppTypography.buttonText)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [.spiceOrange, .warmOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: AppShadows.buttonShadow, radius: 4, x: 0, y: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.xl)
                .background(
                    LinearGradient(
                        colors: [Color.warmWhite, Color.creamWhite],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge)
                        .stroke(Color.spiceOrange.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private func featurePreview(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(title)
                .font(AppTypography.captionLarge)
                .fontWeight(.medium)
                .foregroundColor(.charcoalGray)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(color.opacity(0.1), in: Capsule())
    }
    
    // MARK: - Dish Details Section
    
    private var dishDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                detailRow(label: "Category", value: dish.category.rawValue, icon: "tag")
                
                if let price = dish.price {
                    detailRow(label: "Price", value: price, icon: "dollarsign.circle")
                }
                
                detailRow(
                    label: "OCR Confidence",
                    value: "\(Int(dish.confidence * 100))%",
                    icon: "checkmark.circle"
                )
                
                if let description = dish.description {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("Original Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Share button
            Button {
                prepareShareContent()
                showingShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Dish")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.white)
            }
            
            // Privacy note
            Text("Shared content is privacy-safe and contains no personal data")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var shareButton: some View {
        Button {
            prepareShareContent()
            showingShareSheet = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentVisualization: DishVisualization? {
        // Try to get from pipeline first (most up-to-date), then from dish
        if let pipelineDish = pipeline.processedDishes.first(where: { $0.id == dish.id }) {
            return pipelineDish.aiVisualization
        }
        return dish.aiVisualization
    }
    
    // MARK: - Methods
    
    private func generateVisualization() async {
        isGeneratingVisualization = true
        await pipeline.generateVisualization(for: dish)
        isGeneratingVisualization = false
    }
    
    private func regenerateVisualization() async {
        isGeneratingVisualization = true
        // Create a new copy of the dish without visualization to force regeneration
        var dishCopy = dish
        dishCopy.aiVisualization = nil
        await pipeline.generateVisualization(for: dishCopy)
        isGeneratingVisualization = false
    }
    
    private func prepareShareContent() {
        var content = "🍽️ \(dish.name)\n"
        
        if let description = dish.description {
            content += "\n📝 \(description)\n"
        }
        
        if let price = dish.price {
            content += "\n💰 \(price)\n"
        }
        
        if let visualization = currentVisualization {
            content += "\n✨ AI Enhanced Description:\n\(visualization.generatedDescription)\n"
            
            if !visualization.ingredients.isEmpty {
                content += "\n🥘 Key Ingredients: \(visualization.ingredients.joined(separator: ", "))\n"
            }
        }
        
        content += "\n📱 Shared from Menuly - Privacy-First Menu Reader"
        shareText = content
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let sampleVisualization = DishVisualization(
        dishId: UUID(),
        generatedDescription: "A perfectly grilled Atlantic salmon fillet, seasoned with fresh herbs and served with a bright lemon garlic sauce. The fish is cooked to a beautiful medium doneness with a crispy skin and tender, flaky interior.",
        visualStyle: "Elegant plating with vibrant colors and professional presentation",
        ingredients: ["Atlantic Salmon", "Fresh Herbs", "Lemon", "Garlic", "Olive Oil", "Sea Salt"],
        preparationNotes: "Grilled over medium-high heat for 6-8 minutes per side. The skin should be crispy and the flesh should flake easily with a fork."
    )
    
    var sampleDish = Dish(
        name: "Grilled Salmon",
        description: "Fresh Atlantic salmon with lemon herbs",
        price: "$24.99",
        category: .seafood,
        confidence: 0.95
    )
    sampleDish.aiVisualization = sampleVisualization
    
    NavigationView {
        DishDetailView(dish: sampleDish)
            .environmentObject(AppCoordinator.preview)
            .environmentObject(MenuProcessingPipeline())
    }
}