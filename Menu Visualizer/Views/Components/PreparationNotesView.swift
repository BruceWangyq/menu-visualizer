//
//  PreparationNotesView.swift
//  Menu Visualizer
//
//  Elegant presentation of step-by-step preparation guidance and chef insights
//  Designed to inspire and educate with professional cooking techniques
//

import SwiftUI

struct PreparationNotesView: View {
    // MARK: - Properties
    
    let notes: String
    @State private var selectedTechnique: CookingTechnique? = nil
    @State private var showingTechniqueDetail = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            // Header section
            headerSection
            
            // Preparation steps
            preparationStepsSection
            
            // Cooking techniques
            if !identifiedTechniques.isEmpty {
                cookingTechniquesSection
            }
            
            // Chef tips
            chefTipsSection
            
            // Timing and temperature guide
            timingTemperatureSection
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.spiceOrange)
                
                Text("Preparation Guide")
                    .font(AppTypography.dishNameSmall)
                    .foregroundColor(.charcoalGray)
                
                Spacer()
                
                Image(systemName: "chef.hat")
                    .font(.title3)
                    .foregroundColor(.richBrown)
            }
            
            Text("Professional cooking techniques and timing for perfect results")
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .italic()
        }
    }
    
    // MARK: - Preparation Steps Section
    
    private var preparationStepsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Preparation Notes",
                icon: "list.bullet.rectangle",
                color: .appetiteRed
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(Array(preparationSteps.enumerated()), id: \.offset) { index, step in
                    preparationStepCard(step: step, number: index + 1)
                }
            }
        }
    }
    
    private func preparationStepCard(step: String, number: Int) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.spiceOrange)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(AppTypography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Step content
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(step.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.charcoalGray)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Extract timing info if present
                if let timing = extractTiming(from: step) {
                    timingBadge(timing)
                }
                
                // Extract temperature info if present
                if let temperature = extractTemperature(from: step) {
                    temperatureBadge(temperature)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(.warmWhite, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                .stroke(Color.spiceOrange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func timingBadge(_ timing: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundColor(.goldenYellow)
            
            Text(timing)
                .font(AppTypography.captionLarge)
                .fontWeight(.medium)
                .foregroundColor(.charcoalGray)
        }
        .padding(.horizontal, AppSpacing.chipPadding)
        .padding(.vertical, AppSpacing.xs)
        .background(.goldenYellow.opacity(0.15), in: Capsule())
    }
    
    private func temperatureBadge(_ temperature: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "thermometer.medium")
                .font(.caption)
                .foregroundColor(.appetiteRed)
            
            Text(temperature)
                .font(AppTypography.captionLarge)
                .fontWeight(.medium)
                .foregroundColor(.charcoalGray)
        }
        .padding(.horizontal, AppSpacing.chipPadding)
        .padding(.vertical, AppSpacing.xs)
        .background(.appetiteRed.opacity(0.15), in: Capsule())
    }
    
    // MARK: - Cooking Techniques Section
    
    private var cookingTechniquesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Cooking Techniques",
                icon: "flame",
                color: .wineRed
            )
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 2),
                spacing: AppSpacing.md
            ) {
                ForEach(identifiedTechniques, id: \.self) { technique in
                    techniqueCard(technique)
                }
            }
        }
    }
    
    private func techniqueCard(_ technique: CookingTechnique) -> some View {
        Button {
            selectedTechnique = technique
            showingTechniqueDetail = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Image(systemName: technique.icon)
                        .font(.title3)
                        .foregroundColor(technique.color)
                    
                    Spacer()
                    
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.midGray)
                }
                
                Text(technique.name)
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
                    .multilineTextAlignment(.leading)
                
                Text(technique.shortDescription)
                    .font(AppTypography.captionLarge)
                    .foregroundColor(.midGray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Difficulty indicator
                HStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < technique.difficulty ? technique.color : technique.color.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                    
                    Spacer()
                    
                    Text(technique.difficultyText)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(.midGray)
                }
            }
            .padding(AppSpacing.md)
            .background(.softBeige, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                    .stroke(technique.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingTechniqueDetail) {
            if let selectedTechnique = selectedTechnique {
                TechniqueDetailSheet(technique: selectedTechnique)
            }
        }
    }
    
    // MARK: - Chef Tips Section
    
    private var chefTipsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Chef's Tips",
                icon: "lightbulb.fill",
                color: .goldenYellow
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(chefTips, id: \.self) { tip in
                    chefTipCard(tip)
                }
            }
        }
    }
    
    private func chefTipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "chef.hat.fill")
                .font(.title3)
                .foregroundColor(.richBrown)
            
            Text(tip)
                .font(AppTypography.bodyMedium)
                .italic()
                .foregroundColor(.charcoalGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [Color.goldenYellow.opacity(0.08), Color.warmOrange.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                .stroke(Color.goldenYellow.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Timing and Temperature Section
    
    private var timingTemperatureSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Timing & Temperature",
                icon: "gauge.high",
                color: .herbGreen
            )
            
            HStack(spacing: AppSpacing.lg) {
                // Cooking time
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.goldenYellow)
                        Text("Cooking Time")
                            .font(AppTypography.highlightMedium)
                            .foregroundColor(.charcoalGray)
                    }
                    
                    if let cookingTime = extractOverallTiming() {
                        Text(cookingTime)
                            .font(AppTypography.emphasisBold)
                            .foregroundColor(.goldenYellow)
                    } else {
                        Text("Variable")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.midGray)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 50)
                
                // Temperature
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "thermometer.medium")
                            .foregroundColor(.appetiteRed)
                        Text("Temperature")
                            .font(AppTypography.highlightMedium)
                            .foregroundColor(.charcoalGray)
                    }
                    
                    if let temperature = extractOverallTemperature() {
                        Text(temperature)
                            .font(AppTypography.emphasisBold)
                            .foregroundColor(.appetiteRed)
                    } else {
                        Text("As needed")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.midGray)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.lg)
            .background(.herbGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(AppTypography.highlightMedium)
                .foregroundColor(.charcoalGray)
        }
    }
    
    // MARK: - Computed Properties
    
    private var preparationSteps: [String] {
        // Split notes into sentences and filter meaningful ones
        let sentences = notes.components(separatedBy: CharacterSet(charactersIn: ".!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 }
        
        return sentences.isEmpty ? [notes] : sentences
    }
    
    private var identifiedTechniques: [CookingTechnique] {
        let lowercaseNotes = notes.lowercased()
        return CookingTechnique.allCases.filter { technique in
            technique.keywords.contains { lowercaseNotes.contains($0) }
        }
    }
    
    private var chefTips: [String] {
        var tips: [String] = []
        
        let lowercaseNotes = notes.lowercased()
        
        if lowercaseNotes.contains("crispy") || lowercaseNotes.contains("crisp") {
            tips.append("For extra crispiness, pat ingredients dry before cooking and avoid overcrowding the pan.")
        }
        
        if lowercaseNotes.contains("tender") || lowercaseNotes.contains("flaky") {
            tips.append("Don't overcook - the residual heat will finish the cooking process while keeping the texture perfect.")
        }
        
        if lowercaseNotes.contains("season") || lowercaseNotes.contains("salt") {
            tips.append("Season at multiple stages of cooking for layered, complex flavors throughout the dish.")
        }
        
        if lowercaseNotes.contains("rest") {
            tips.append("Allow proteins to rest after cooking to redistribute juices for maximum flavor and tenderness.")
        }
        
        if lowercaseNotes.contains("hot") || lowercaseNotes.contains("heat") {
            tips.append("Preheat your cooking surface properly - this ensures even cooking and prevents sticking.")
        }
        
        // Default tips if none were identified
        if tips.isEmpty {
            tips = [
                "Taste and adjust seasoning throughout the cooking process.",
                "Use high-quality ingredients for the best results.",
                "Have all ingredients prepared before you start cooking."
            ]
        }
        
        return tips
    }
    
    // MARK: - Helper Methods
    
    private func extractTiming(from step: String) -> String? {
        let patterns = [
            #"\d+\s*(?:-\s*\d+)?\s*min(?:ute)?s?"#,
            #"\d+\s*(?:-\s*\d+)?\s*hour?s?"#,
            #"\d+\s*(?:-\s*\d+)?\s*sec(?:ond)?s?"#
        ]
        
        for pattern in patterns {
            if let match = step.range(of: pattern, options: .regularExpression) {
                return String(step[match])
            }
        }
        
        return nil
    }
    
    private func extractTemperature(from step: String) -> String? {
        let patterns = [
            #"\d+°?[FC]"#,
            #"\d+\s*degrees?"#,
            #"(?:low|medium|high)(?:\s*-?\s*(?:low|medium|high))?\s*heat"#
        ]
        
        for pattern in patterns {
            if let match = step.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                return String(step[match])
            }
        }
        
        return nil
    }
    
    private func extractOverallTiming() -> String? {
        let allTimings = preparationSteps.compactMap { extractTiming(from: $0) }
        return allTimings.first
    }
    
    private func extractOverallTemperature() -> String? {
        let allTemperatures = preparationSteps.compactMap { extractTemperature(from: $0) }
        return allTemperatures.first
    }
}

// MARK: - Cooking Technique Enum

enum CookingTechnique: String, CaseIterable {
    case grilling = "Grilling"
    case sauteing = "Sautéing"
    case roasting = "Roasting"
    case braising = "Braising"
    case poaching = "Poaching"
    case searing = "Searing"
    case steaming = "Steaming"
    case baking = "Baking"
    case frying = "Frying"
    case broiling = "Broiling"
    
    var name: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .grilling: return "flame.fill"
        case .sauteing: return "drop.triangle.fill"
        case .roasting: return "oven.fill"
        case .braising: return "pot.fill"
        case .poaching: return "drop.fill"
        case .searing: return "flame"
        case .steaming: return "cloud.fill"
        case .baking: return "oven"
        case .frying: return "drop.triangle"
        case .broiling: return "sun.max.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .grilling, .searing, .broiling: return .spicyRed
        case .sauteing, .frying: return .warmOrange
        case .roasting, .baking: return .richBrown
        case .braising: return .wineRed
        case .poaching, .steaming: return .glutenFreeBlue
        }
    }
    
    var shortDescription: String {
        switch self {
        case .grilling: return "High heat, direct flame cooking"
        case .sauteing: return "Quick cooking in small amount of fat"
        case .roasting: return "Dry heat cooking in oven"
        case .braising: return "Slow cooking with moisture"
        case .poaching: return "Gentle cooking in liquid"
        case .searing: return "High heat to create crust"
        case .steaming: return "Cooking with steam heat"
        case .baking: return "Dry heat in enclosed oven"
        case .frying: return "Cooking submerged in hot fat"
        case .broiling: return "High heat from above"
        }
    }
    
    var difficulty: Int {
        switch self {
        case .steaming, .poaching: return 1
        case .baking, .roasting, .braising: return 2
        case .sauteing, .grilling, .frying, .searing, .broiling: return 3
        }
    }
    
    var difficultyText: String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Advanced"
        default: return "Unknown"
        }
    }
    
    var keywords: [String] {
        switch self {
        case .grilling: return ["grill", "grilled", "barbecue", "bbq"]
        case .sauteing: return ["sauté", "sautéed", "sauteed", "pan-fried"]
        case .roasting: return ["roast", "roasted", "oven"]
        case .braising: return ["braise", "braised", "slow cook"]
        case .poaching: return ["poach", "poached", "gently cook"]
        case .searing: return ["sear", "seared", "crispy skin"]
        case .steaming: return ["steam", "steamed"]
        case .baking: return ["bake", "baked"]
        case .frying: return ["fry", "fried", "deep fry"]
        case .broiling: return ["broil", "broiled"]
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .grilling:
            return "Grilling involves cooking food over direct heat, typically on a grill. The high heat creates beautiful char marks and imparts a smoky flavor. Temperature control is key - use different zones for various cooking stages."
        case .sauteing:
            return "Sautéing means 'to jump' in French, referring to the way food moves in the pan. Use high heat, a small amount of fat, and keep ingredients moving for even cooking. Perfect for vegetables and thin cuts of meat."
        case .roasting:
            return "Roasting uses dry heat in an oven to cook food evenly on all sides. The circulating hot air creates a caramelized exterior while keeping the interior moist. Ideal for larger cuts of meat and whole vegetables."
        case .braising:
            return "Braising combines both dry and moist heat cooking methods. First sear the food, then cook slowly in liquid. This technique breaks down tough fibers in meat, creating tender, flavorful results."
        case .poaching:
            return "Poaching is a gentle cooking method using liquid at a temperature just below boiling. The liquid should barely simmer. This technique preserves delicate textures and is perfect for fish, eggs, and fruits."
        case .searing:
            return "Searing creates a flavorful crust by cooking at high temperature. This doesn't 'seal in juices' as commonly believed, but it does create complex flavors through the Maillard reaction. Essential for building flavor layers."
        case .steaming:
            return "Steaming cooks food using the steam from boiling water. This gentle method preserves nutrients and natural flavors while creating tender textures. Food never touches the water directly."
        case .baking:
            return "Baking uses dry heat in an enclosed oven. The consistent temperature cooks food evenly, making it perfect for breads, pastries, and casseroles. Proper preheating is essential for best results."
        case .frying:
            return "Frying submerges food in hot fat or oil. Temperature control is crucial - too low and food becomes greasy, too high and it burns outside while remaining raw inside. Monitor oil temperature carefully."
        case .broiling:
            return "Broiling cooks food with intense heat from above, similar to an upside-down grill. Keep food close to the heat source for quick cooking. Watch carefully as food can go from perfect to burned quickly."
        }
    }
}

// MARK: - Technique Detail Sheet

struct TechniqueDetailSheet: View {
    let technique: CookingTechnique
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Image(systemName: technique.icon)
                                .font(.largeTitle)
                                .foregroundColor(technique.color)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(technique.name)
                                    .font(AppTypography.dishNameMedium)
                                    .foregroundColor(.charcoalGray)
                                
                                Text(technique.shortDescription)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(.midGray)
                            }
                        }
                        
                        // Difficulty indicator
                        HStack {
                            Text("Difficulty:")
                                .font(AppTypography.highlightMedium)
                                .foregroundColor(.charcoalGray)
                            
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill(index < technique.difficulty ? technique.color : technique.color.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            
                            Text(technique.difficultyText)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(.midGray)
                            
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Detailed description
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Technique Details")
                            .font(AppTypography.highlightMedium)
                            .foregroundColor(.charcoalGray)
                        
                        Text(technique.detailedDescription)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.charcoalGray)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
                .padding(AppSpacing.cardPadding)
            }
            .navigationTitle("Cooking Technique")
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
    let sampleNotes = """
    Grilled over medium-high heat for 6-8 minutes per side. The skin should be crispy and the flesh should flake easily with a fork. Season generously with salt and pepper before cooking. Heat the grill to 400°F for optimal results. Let the fish rest for 2-3 minutes after cooking to allow juices to redistribute. Finish with fresh herbs and a squeeze of lemon for brightness.
    """
    
    ScrollView {
        PreparationNotesView(notes: sampleNotes)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}