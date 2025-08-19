//
//  DishListView.swift
//  Menu Visualizer
//
//  Modern dish list view with search, filtering, and visualization features
//

import SwiftUI

struct DishListView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var pipeline: MenuProcessingPipeline
    let menu: Menu
    @State private var selectedDish: Dish?
    @State private var searchText = ""
    @State private var selectedCategory: DishCategory?
    @State private var showingVisualizationForAll = false
    @State private var favoriteDishes: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with menu info
            headerView
            
            // Search and filter
            searchAndFilterView
            
            // Action buttons
            actionButtonsView
            
            // Dishes list
            dishesListView
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    coordinator.navigateBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        coordinator.navigate(to: .privacyDashboard)
                    } label: {
                        Label("Privacy Settings", systemImage: "hand.raised")
                    }
                    
                    Button {
                        coordinator.navigate(to: .settings)
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        pipeline.reset()
                        coordinator.navigateToRoot()
                    } label: {
                        Label("Clear Data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .fontWeight(.medium)
                }
            }
        }
        .refreshable {
            // Privacy-compliant refresh - regenerate visualizations only
            await generateMissingVisualizations()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Processing timestamp
            Text("Menu processed \(formattedDate)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Menu stats
            HStack(spacing: 20) {
                statView(
                    value: "\(menu.extractedDishes.count)",
                    label: "Dishes",
                    icon: "fork.knife"
                )
                
                statView(
                    value: "\(Int(menu.ocrResult.confidence * 100))%",
                    label: "Accuracy",
                    icon: "checkmark.circle"
                )
                
                statView(
                    value: "\(visualizedCount)/\(menu.extractedDishes.count)",
                    label: "Visualized",
                    icon: "photo"
                )
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private func statView(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
        }
    }
    
    // MARK: - Search and Filter View
    
    private var searchAndFilterView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search dishes...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryButton(for: nil, label: "All")
                    
                    ForEach(availableCategories, id: \.self) { category in
                        categoryButton(for: category, label: category.rawValue)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    showingVisualizationForAll = true
                    await pipeline.generateAllVisualizations()
                    showingVisualizationForAll = false
                }
            } label: {
                HStack(spacing: 6) {
                    if showingVisualizationForAll {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Visualize All")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue, in: Capsule())
                .foregroundColor(.white)
            }
            .disabled(showingVisualizationForAll || allDishesVisualized)
            
            Spacer()
            
            Text("\(filteredDishes.count) dishes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private func categoryButton(for category: DishCategory?, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = selectedCategory == category ? nil : category
            }
        } label: {
            HStack(spacing: 4) {
                if let category = category {
                    Text(category.icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedCategory == category ? .blue : .regularMaterial,
                in: Capsule()
            )
            .foregroundColor(
                selectedCategory == category ? .white : .primary
            )
        }
    }
    
    // MARK: - Dishes List View
    
    private var dishesListView: some View {
        List(filteredDishes, id: \.id) { dish in
            DishVisualizationCard(
                dish: dish,
                onTap: {
                    coordinator.navigate(to: .dishDetail(dish: dish))
                },
                onVisualize: {
                    Task {
                        await pipeline.generateVisualization(for: dish)
                    }
                },
                onFavorite: {
                    toggleFavorite(dish)
                }
            )
            .listRowInsets(EdgeInsets(top: AppSpacing.sm, leading: AppSpacing.md, bottom: AppSpacing.sm, trailing: AppSpacing.md))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: menu.timestamp)
    }
    
    private var availableCategories: [DishCategory] {
        let categories = Set(menu.extractedDishes.map { $0.category })
        return Array(categories).sorted { $0.rawValue < $1.rawValue }
    }
    
    private var filteredDishes: [Dish] {
        var dishes = pipeline.processedDishes.isEmpty ? menu.extractedDishes : pipeline.processedDishes
        
        // Filter by search text
        if !searchText.isEmpty {
            dishes = dishes.filter { dish in
                dish.name.localizedCaseInsensitiveContains(searchText) ||
                dish.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by category
        if let category = selectedCategory {
            dishes = dishes.filter { $0.category == category }
        }
        
        // Sort by confidence and name
        return dishes.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.name < rhs.name
        }
    }
    
    private var visualizedCount: Int {
        let dishes = pipeline.processedDishes.isEmpty ? menu.extractedDishes : pipeline.processedDishes
        return dishes.filter { $0.aiVisualization != nil }.count
    }
    
    private var allDishesVisualized: Bool {
        let dishes = pipeline.processedDishes.isEmpty ? menu.extractedDishes : pipeline.processedDishes
        return !dishes.isEmpty && dishes.allSatisfy { $0.aiVisualization != nil }
    }
    
    // MARK: - Methods
    
    private func toggleFavorite(_ dish: Dish) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if favoriteDishes.contains(dish.id) {
                favoriteDishes.remove(dish.id)
            } else {
                favoriteDishes.insert(dish.id)
            }
        }
    }
    
    private func generateMissingVisualizations() async {
        await pipeline.generateAllVisualizations()
    }
}

// MARK: - Dish Row View

struct DishRowView: View {
    let dish: Dish
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onVisualize: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with dish name and actions
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dish.name)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 8) {
                            // Category badge
                            HStack(spacing: 4) {
                                Text(dish.category.icon)
                                    .font(.caption)
                                Text(dish.category.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundColor(.blue)
                            
                            // Confidence indicator
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(confidenceColor(dish.confidence))
                                    .frame(width: 6, height: 6)
                                Text("\(Int(dish.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        // Price
                        if let price = dish.price {
                            Text(price)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            // Favorite button
                            Button(action: onFavorite) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(isFavorite ? .red : .secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            
                            // Visualization button
                            Button(action: onVisualize) {
                                if dish.isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else if dish.aiVisualization != nil {
                                    Image(systemName: "sparkles.square.filled.on.square")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(dish.isGenerating)
                        }
                    }
                }
                
                // Description
                if let description = dish.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Bottom row with visualization status
                HStack {
                    if dish.aiVisualization != nil {
                        Label("AI Visualized", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if dish.isGenerating {
                        Label("Generating...", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Action indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
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

// MARK: - Preview

#Preview {
    let sampleOCRResult = OCRResult(
        rawText: "Sample menu text",
        recognizedLines: [],
        confidence: 0.92,
        processingTime: 1.5,
        imageSize: CGSize(width: 800, height: 600)
    )
    
    let sampleDishes = [
        Dish(
            name: "Grilled Salmon",
            description: "Fresh Atlantic salmon with lemon herbs",
            price: "$24.99",
            category: .mainCourse,
            confidence: 0.95
        ),
        Dish(
            name: "Caesar Salad",
            description: "Crisp romaine lettuce with parmesan",
            price: "$14.99",
            category: .salad,
            confidence: 0.88
        )
    ]
    
    let sampleMenu = Menu(
        ocrResult: sampleOCRResult,
        extractedDishes: sampleDishes
    )
    
    DishListView(menu: sampleMenu)
        .environmentObject(AppCoordinator.preview)
        .environmentObject(MenuProcessingPipeline())
}