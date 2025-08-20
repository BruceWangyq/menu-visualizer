//
//  CulturalContextView.swift
//  Menu Visualizer
//
//  Cultural context and origin stories for dishes with serving suggestions and regional variations
//  Designed to educate and inspire culinary exploration
//

import SwiftUI

struct CulturalContextView: View {
    // MARK: - Properties
    
    let dishName: String
    let category: DishCategory
    let ingredients: [String]
    
    @State private var selectedRegion: CulturalRegion? = nil
    @State private var showingPairingDetail = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
            // Header section
            headerSection
            
            // Origin story
            originStorySection
            
            // Regional variations
            if !regionalVariations.isEmpty {
                regionalVariationsSection
            }
            
            // Traditional serving
            traditionalServingSection
            
            // Pairing suggestions
            pairingsuggestionsSection
            
            // Cultural significance
            culturalSignificanceSection
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.organicPurple)
                
                Text("Cultural Heritage")
                    .font(AppTypography.dishNameSmall)
                    .foregroundColor(.charcoalGray)
                
                Spacer()
                
                Image(systemName: identifiedCulture.flagIcon)
                    .font(.title2)
            }
            
            Text("Discover the rich history and traditions behind this dish")
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .italic()
        }
    }
    
    // MARK: - Origin Story Section
    
    private var originStorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Origin & History",
                icon: "book.fill",
                color: .richBrown
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Cultural region
                HStack {
                    Image(systemName: identifiedCulture.flagIcon)
                        .font(.title)
                        .foregroundColor(identifiedCulture.color)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(identifiedCulture.name)
                            .font(AppTypography.dishNameSmall)
                            .foregroundColor(.charcoalGray)
                        
                        Text(identifiedCulture.region)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(.midGray)
                    }
                    
                    Spacer()
                }
                
                // Origin story
                Text(identifiedCulture.originStory(for: dishName, category: category))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.charcoalGray)
                    .lineSpacing(4)
                    .padding(AppSpacing.lg)
                    .background(
                        LinearGradient(
                            colors: [identifiedCulture.color.opacity(0.08), identifiedCulture.color.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                            .stroke(identifiedCulture.color.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Regional Variations Section
    
    private var regionalVariationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Regional Variations",
                icon: "map.fill",
                color: .sageGreen
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(regionalVariations, id: \.name) { variation in
                        regionalVariationCard(variation)
                    }
                }
                .padding(.horizontal, 1) // Prevent shadow clipping
            }
        }
    }
    
    private func regionalVariationCard(_ variation: RegionalVariation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(variation.flagEmoji)
                    .font(.title2)
                
                Text(variation.name)
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
                
                Spacer()
            }
            
            Text(variation.description)
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            if !variation.keyIngredients.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Key Ingredients:")
                        .font(AppTypography.captionSmall)
                        .fontWeight(.medium)
                        .foregroundColor(.charcoalGray)
                    
                    Text(variation.keyIngredients.joined(separator: ", "))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(.sageGreen)
                        .italic()
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 200)
        .background(Color.warmWhite, in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium)
                .stroke(Color.sageGreen.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: AppShadows.cardShadow, radius: AppShadows.subtleRadius, x: 0, y: 1)
    }
    
    // MARK: - Traditional Serving Section
    
    private var traditionalServingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Traditional Serving",
                icon: "fork.knife",
                color: .goldenYellow
            )
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 2),
                spacing: AppSpacing.md
            ) {
                servingCard(
                    icon: "clock.fill",
                    title: "Best Time",
                    subtitle: identifiedCulture.traditionalMealTime(for: category),
                    color: .goldenYellow
                )
                
                servingCard(
                    icon: "person.2.fill",
                    title: "Serving Style",
                    subtitle: identifiedCulture.servingStyle(for: category),
                    color: .warmOrange
                )
                
                servingCard(
                    icon: "leaf.fill",
                    title: "Accompaniments",
                    subtitle: identifiedCulture.traditionalAccompaniments(for: category, ingredients: ingredients),
                    color: .vegetarianGreen
                )
                
                servingCard(
                    icon: "heart.fill",
                    title: "Occasion",
                    subtitle: identifiedCulture.traditionalOccasion(for: category),
                    color: .appetiteRed
                )
            }
        }
    }
    
    private func servingCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
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
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
    }
    
    // MARK: - Pairing Suggestions Section
    
    private var pairingsuggestionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Pairing Suggestions",
                icon: "wineglass.fill",
                color: .wineRed
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Beverage pairings
                pairingCategory(
                    title: "Beverages",
                    icon: "cup.and.saucer.fill",
                    items: identifiedCulture.beveragePairings(for: category, ingredients: ingredients),
                    color: .wineRed
                )
                
                // Side dish pairings
                pairingCategory(
                    title: "Side Dishes",
                    icon: "bowl.fill",
                    items: identifiedCulture.sideDishPairings(for: category, ingredients: ingredients),
                    color: .herbGreen
                )
                
                // Dessert pairings (if not already dessert)
                if category != .dessert {
                    pairingCategory(
                        title: "Desserts",
                        icon: "birthday.cake.fill",
                        items: identifiedCulture.dessertPairings(for: category),
                        color: .organicPurple
                    )
                }
            }
        }
    }
    
    private func pairingCategory(title: String, icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
            }
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.adaptive(minimum: 100)), count: 3),
                spacing: AppSpacing.xs
            ) {
                ForEach(items.prefix(6), id: \.self) { item in
                    Text(item)
                        .font(AppTypography.captionLarge)
                        .padding(.horizontal, AppSpacing.chipPadding)
                        .padding(.vertical, AppSpacing.xs)
                        .background(color.opacity(0.12), in: Capsule())
                        .foregroundColor(color)
                }
            }
        }
    }
    
    // MARK: - Cultural Significance Section
    
    private var culturalSignificanceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                title: "Cultural Significance",
                icon: "star.fill",
                color: .spiceOrange
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Cultural meaning
                culturalMeaningCard
                
                // Modern adaptations
                modernAdaptationsCard
            }
        }
    }
    
    private var culturalMeaningCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.spiceOrange)
                
                Text("Cultural Meaning")
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
            }
            
            Text(identifiedCulture.culturalMeaning(for: dishName, category: category))
                .font(AppTypography.bodyMedium)
                .italic()
                .foregroundColor(.charcoalGray)
                .lineSpacing(4)
        }
        .padding(AppSpacing.lg)
        .background(Color.spiceOrange.opacity(0.06), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
    }
    
    private var modernAdaptationsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.herbGreen)
                
                Text("Modern Adaptations")
                    .font(AppTypography.highlightMedium)
                    .foregroundColor(.charcoalGray)
            }
            
            Text(identifiedCulture.modernAdaptations(for: dishName, category: category))
                .font(AppTypography.bodyMedium)
                .foregroundColor(.charcoalGray)
                .lineSpacing(4)
        }
        .padding(AppSpacing.lg)
        .background(Color.herbGreen.opacity(0.06), in: RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMedium))
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
    
    private var identifiedCulture: CulturalRegion {
        return CulturalRegion.identify(from: dishName, category: category, ingredients: ingredients)
    }
    
    private var regionalVariations: [RegionalVariation] {
        return identifiedCulture.getRegionalVariations(for: dishName, category: category)
    }
}

// MARK: - Cultural Region Enum

enum CulturalRegion: String, CaseIterable {
    case mediterranean = "Mediterranean"
    case asian = "Asian"
    case european = "European"
    case american = "American"
    case latinAmerican = "Latin American"
    case middleEastern = "Middle Eastern"
    case african = "African"
    case indian = "Indian"
    case international = "International"
    
    var name: String {
        rawValue
    }
    
    var region: String {
        switch self {
        case .mediterranean: return "Mediterranean Basin"
        case .asian: return "East & Southeast Asia"
        case .european: return "Continental Europe"
        case .american: return "North America"
        case .latinAmerican: return "Latin America"
        case .middleEastern: return "Middle East"
        case .african: return "Africa"
        case .indian: return "Indian Subcontinent"
        case .international: return "Global Fusion"
        }
    }
    
    var flagIcon: String {
        switch self {
        case .mediterranean: return "sun.max.fill"
        case .asian: return "pagoda.fill"
        case .european: return "building.columns.fill"
        case .american: return "flag.fill"
        case .latinAmerican: return "flame.fill"
        case .middleEastern: return "moon.stars.fill"
        case .african: return "sun.and.horizon.fill"
        case .indian: return "leaf.circle.fill"
        case .international: return "globe"
        }
    }
    
    var color: Color {
        switch self {
        case .mediterranean: return .warmOrange
        case .asian: return .appetiteRed
        case .european: return .richBrown
        case .american: return .glutenFreeBlue
        case .latinAmerican: return .spicyRed
        case .middleEastern: return .organicPurple
        case .african: return .goldenYellow
        case .indian: return .vegetarianGreen
        case .international: return .midGray
        }
    }
    
    static func identify(from dishName: String, category: DishCategory, ingredients: [String]) -> CulturalRegion {
        let lowercaseName = dishName.lowercased()
        let lowercaseIngredients = ingredients.map { $0.lowercased() }.joined(separator: " ")
        let combined = "\(lowercaseName) \(lowercaseIngredients)"
        
        // Asian cuisine indicators
        if combined.contains("salmon") && (combined.contains("soy") || combined.contains("miso") || combined.contains("ginger")) {
            return .asian
        }
        if combined.contains("rice") || combined.contains("noodle") || combined.contains("soy") || combined.contains("ginger") {
            return .asian
        }
        
        // Mediterranean cuisine indicators
        if combined.contains("olive") || combined.contains("basil") || combined.contains("tomato") || combined.contains("feta") {
            return .mediterranean
        }
        if lowercaseName.contains("greek") || lowercaseName.contains("italian") || lowercaseName.contains("mediterranean") {
            return .mediterranean
        }
        
        // Indian cuisine indicators
        if combined.contains("curry") || combined.contains("turmeric") || combined.contains("cumin") || combined.contains("cardamom") {
            return .indian
        }
        if lowercaseName.contains("tandoor") || lowercaseName.contains("masala") || lowercaseName.contains("biryani") {
            return .indian
        }
        
        // Latin American indicators
        if combined.contains("lime") || combined.contains("cilantro") || combined.contains("jalapeño") || combined.contains("avocado") {
            return .latinAmerican
        }
        if lowercaseName.contains("mexican") || lowercaseName.contains("latin") || lowercaseName.contains("salsa") {
            return .latinAmerican
        }
        
        // European indicators
        if combined.contains("butter") || combined.contains("cream") || combined.contains("wine") || combined.contains("thyme") {
            return .european
        }
        if lowercaseName.contains("french") || lowercaseName.contains("german") || lowercaseName.contains("british") {
            return .european
        }
        
        // American indicators
        if category == .mainCourse && (combined.contains("barbecue") || combined.contains("bbq") || combined.contains("grilled")) {
            return .american
        }
        if lowercaseName.contains("american") || lowercaseName.contains("burger") || lowercaseName.contains("steak") {
            return .american
        }
        
        // Default to international fusion
        return .international
    }
    
    func originStory(for dishName: String, category: DishCategory) -> String {
        switch self {
        case .mediterranean:
            return "This dish reflects the ancient Mediterranean tradition of celebrating fresh, seasonal ingredients. Born from the confluence of sea and land, Mediterranean cuisine has been shaped by centuries of trade, bringing together the olive groves of Greece, the herb gardens of Provence, and the coastal waters rich with seafood."
            
        case .asian:
            return "Rooted in thousands of years of culinary philosophy, this dish embodies the Asian principle of balance - harmonizing flavors, textures, and colors. The techniques passed down through generations emphasize the natural essence of ingredients, creating dishes that nourish both body and spirit."
            
        case .european:
            return "This dish carries the heritage of European culinary refinement, where cooking evolved from necessity to artistry. Born in the kitchens of continental Europe, it represents centuries of technique perfection, seasonal awareness, and the transformation of simple ingredients into extraordinary experiences."
            
        case .american:
            return "This dish embodies the American spirit of innovation and abundance. Born from the melting pot of cultures that shaped American cuisine, it represents the fusion of immigrant traditions with local ingredients, creating something uniquely bold and satisfying."
            
        case .latinAmerican:
            return "Rich with the vibrant spirit of Latin America, this dish tells the story of indigenous ingredients meeting Spanish colonial influences. It celebrates the abundance of the Americas - fresh herbs, bright citrus, and bold spices that have defined the region's cuisine for generations."
            
        case .middleEastern:
            return "This dish carries the ancient wisdom of Middle Eastern cuisine, where hospitality and flavor have been intertwined for millennia. Born along the spice routes, it represents the generous use of aromatic spices and the tradition of sharing meals as a form of community and celebration."
            
        case .african:
            return "Rooted in the diverse culinary traditions of Africa, this dish reflects the continent's rich agricultural heritage and the ingenious use of local ingredients. It embodies the communal spirit of African dining, where meals are shared experiences that strengthen family and community bonds."
            
        case .indian:
            return "This dish is a testament to India's ancient culinary philosophy, where food is considered medicine and every spice has a purpose. Born from Ayurvedic principles and regional traditions, it represents the complex layering of flavors that has made Indian cuisine beloved worldwide."
            
        case .international:
            return "This dish represents the beautiful fusion of global culinary traditions, where techniques and ingredients from different cultures come together to create something new. It embodies our modern, connected world where the best of international cuisine can inspire innovative and delicious combinations."
        }
    }
    
    func culturalMeaning(for dishName: String, category: DishCategory) -> String {
        switch self {
        case .mediterranean:
            return "In Mediterranean culture, meals are sacred moments of connection. This dish represents the philosophy of 'slow food' - taking time to appreciate quality ingredients and sharing meaningful conversations around the table."
            
        case .asian:
            return "This dish embodies the Asian concept of harmony and balance. Each element serves a purpose, creating not just nourishment for the body, but also contributing to overall well-being and spiritual satisfaction."
            
        case .european:
            return "In European tradition, this dish represents the artistry of cooking - the transformation of simple ingredients into something that delights all the senses. It carries the heritage of craftsmanship and attention to detail."
            
        case .american:
            return "This dish symbolizes American values of innovation and generosity. It represents the ability to take influences from many cultures and create something uniquely satisfying and accessible to all."
            
        case .latinAmerican:
            return "In Latin American culture, this dish represents celebration and community. Food is an expression of love and hospitality, meant to bring people together in joy and abundance."
            
        case .middleEastern:
            return "This dish embodies the Middle Eastern tradition of hospitality, where feeding guests is considered a sacred duty. It represents generosity, warmth, and the sharing of abundance with others."
            
        case .african:
            return "In African tradition, this dish represents unity and community strength. Meals are communal experiences that reinforce family bonds and cultural identity, passed down through generations."
            
        case .indian:
            return "This dish reflects the Indian understanding of food as medicine for both body and soul. Each ingredient is chosen not just for flavor, but for its healing properties and spiritual significance."
            
        case .international:
            return "This dish represents our global culinary future - a world where the best traditions from every culture can come together, creating new experiences while honoring ancestral wisdom."
        }
    }
    
    func modernAdaptations(for dishName: String, category: DishCategory) -> String {
        switch self {
        case .mediterranean:
            return "Modern chefs have embraced Mediterranean principles, focusing on farm-to-table ingredients and sustainable seafood. Contemporary versions often feature local, seasonal ingredients while maintaining the essential spirit of simplicity and quality."
            
        case .asian:
            return "Today's interpretations honor traditional techniques while incorporating modern nutritional understanding. Plant-based versions and fusion elements reflect current dietary preferences while maintaining the essential balance of flavors."
            
        case .european:
            return "Contemporary European cuisine has evolved to be lighter and more health-conscious while maintaining its foundational techniques. Modern versions often feature reduced dairy and innovative plant-based alternatives."
            
        case .american:
            return "Modern American cuisine has embraced healthier preparation methods and locally-sourced ingredients. Today's versions often feature leaner proteins and more vegetables while maintaining the bold, satisfying flavors."
            
        case .latinAmerican:
            return "Contemporary Latin American cuisine has gained global recognition for its fresh, vibrant flavors. Modern adaptations often feature quinoa and other superfoods while celebrating traditional preparation methods."
            
        case .middleEastern:
            return "Modern Middle Eastern cuisine has found new appreciation for its healthy, flavorful approach. Contemporary versions often highlight the naturally plant-forward aspects and ancient grains."
            
        case .african:
            return "Today's African-inspired dishes are gaining recognition for their nutritious ingredients and bold flavors. Modern interpretations often feature ancient grains and vegetables that are now considered superfoods."
            
        case .indian:
            return "Contemporary Indian cuisine has evolved to meet modern dietary needs while honoring traditional spice combinations. Plant-based versions and health-conscious adaptations maintain the complex flavor profiles."
            
        case .international:
            return "This fusion approach represents the future of dining - combining the best techniques and ingredients from multiple cultures to create innovative, delicious, and often healthier versions of beloved dishes."
        }
    }
    
    func traditionalMealTime(for category: DishCategory) -> String {
        switch category {
        case .appetizer:
            return "Start of meal"
        case .soup:
            return "First course"
        case .salad:
            return "Light meal or side"
        case .mainCourse, .meat, .seafood:
            return "Lunch or dinner"
        case .pasta:
            return "Lunch or dinner"
        case .vegetarian:
            return "Any time"
        case .dessert:
            return "After meal"
        case .beverage:
            return "Throughout meal"
        case .special:
            return "Special occasion"
        case .unknown:
            return "Flexible timing"
        }
    }
    
    func servingStyle(for category: DishCategory) -> String {
        switch self {
        case .mediterranean:
            return "Family style sharing"
        case .asian:
            return "Individual portions"
        case .european:
            return "Plated course"
        case .american:
            return "Individual servings"
        case .latinAmerican:
            return "Communal sharing"
        case .middleEastern:
            return "Shared platters"
        case .african:
            return "Community bowl"
        case .indian:
            return "Shared portions"
        case .international:
            return "Flexible style"
        }
    }
    
    func traditionalAccompaniments(for category: DishCategory, ingredients: [String]) -> String {
        switch self {
        case .mediterranean:
            return "Crusty bread, olive oil"
        case .asian:
            return "Steamed rice, tea"
        case .european:
            return "Wine, artisan bread"
        case .american:
            return "Seasonal vegetables"
        case .latinAmerican:
            return "Rice, beans, tortillas"
        case .middleEastern:
            return "Flatbread, yogurt"
        case .african:
            return "Grains, vegetables"
        case .indian:
            return "Rice, naan, chutney"
        case .international:
            return "Varied sides"
        }
    }
    
    func traditionalOccasion(for category: DishCategory) -> String {
        switch self {
        case .mediterranean:
            return "Family gatherings"
        case .asian:
            return "Daily meals"
        case .european:
            return "Formal dining"
        case .american:
            return "Casual dining"
        case .latinAmerican:
            return "Celebrations"
        case .middleEastern:
            return "Hospitality meals"
        case .african:
            return "Community feasts"
        case .indian:
            return "Family meals"
        case .international:
            return "Modern dining"
        }
    }
    
    func beveragePairings(for category: DishCategory, ingredients: [String]) -> [String] {
        switch self {
        case .mediterranean:
            return ["White wine", "Rosé", "Sparkling water", "Herbal tea"]
        case .asian:
            return ["Green tea", "Sake", "Light beer", "Jasmine tea"]
        case .european:
            return ["Red wine", "White wine", "Beer", "Coffee"]
        case .american:
            return ["Craft beer", "Bourbon", "Iced tea", "Soda"]
        case .latinAmerican:
            return ["Cerveza", "Sangria", "Lime water", "Horchata"]
        case .middleEastern:
            return ["Mint tea", "Turkish coffee", "Pomegranate juice", "Ayran"]
        case .african:
            return ["Rooibos tea", "Palm wine", "Hibiscus tea", "Ginger beer"]
        case .indian:
            return ["Chai tea", "Lassi", "Mango juice", "Coconut water"]
        case .international:
            return ["Wine", "Beer", "Tea", "Coffee"]
        }
    }
    
    func sideDishPairings(for category: DishCategory, ingredients: [String]) -> [String] {
        switch self {
        case .mediterranean:
            return ["Greek salad", "Hummus", "Roasted vegetables", "Olives"]
        case .asian:
            return ["Steamed rice", "Miso soup", "Pickled vegetables", "Edamame"]
        case .european:
            return ["Roasted potatoes", "Seasonal salad", "Artisan bread", "Cheese"]
        case .american:
            return ["Coleslaw", "French fries", "Corn bread", "Garden salad"]
        case .latinAmerican:
            return ["Black beans", "Rice", "Guacamole", "Plantains"]
        case .middleEastern:
            return ["Tabbouleh", "Hummus", "Pita bread", "Fattoush"]
        case .african:
            return ["Injera", "Couscous", "Plantains", "Collard greens"]
        case .indian:
            return ["Basmati rice", "Naan", "Dal", "Raita"]
        case .international:
            return ["Mixed greens", "Bread", "Roasted vegetables", "Grains"]
        }
    }
    
    func dessertPairings(for category: DishCategory) -> [String] {
        switch self {
        case .mediterranean:
            return ["Baklava", "Fresh fruit", "Gelato", "Tiramisu"]
        case .asian:
            return ["Mochi", "Green tea ice cream", "Fruit", "Red bean dessert"]
        case .european:
            return ["Chocolate mousse", "Fruit tart", "Crème brûlée", "Sorbet"]
        case .american:
            return ["Apple pie", "Ice cream", "Brownies", "Cheesecake"]
        case .latinAmerican:
            return ["Flan", "Tres leches", "Churros", "Fresh fruit"]
        case .middleEastern:
            return ["Baklava", "Halva", "Date cookies", "Rose water sweets"]
        case .african:
            return ["Sweet potato pie", "Fruit", "Honey cakes", "Coconut treats"]
        case .indian:
            return ["Gulab jamun", "Kulfi", "Kheer", "Laddu"]
        case .international:
            return ["Seasonal fruit", "Ice cream", "Pastries", "Chocolate"]
        }
    }
    
    func getRegionalVariations(for dishName: String, category: DishCategory) -> [RegionalVariation] {
        switch self {
        case .mediterranean:
            return [
                RegionalVariation(
                    name: "Greek Style",
                    flagEmoji: "🇬🇷",
                    description: "Features feta cheese, olives, and fresh herbs with olive oil",
                    keyIngredients: ["Feta cheese", "Kalamata olives", "Oregano"]
                ),
                RegionalVariation(
                    name: "Italian Style", 
                    flagEmoji: "🇮🇹",
                    description: "Incorporates fresh basil, tomatoes, and mozzarella",
                    keyIngredients: ["Fresh basil", "San Marzano tomatoes", "Mozzarella"]
                ),
                RegionalVariation(
                    name: "Spanish Style",
                    flagEmoji: "🇪🇸", 
                    description: "Uses saffron, paprika, and sherry vinegar",
                    keyIngredients: ["Saffron", "Smoked paprika", "Sherry vinegar"]
                )
            ]
            
        case .asian:
            return [
                RegionalVariation(
                    name: "Japanese Style",
                    flagEmoji: "🇯🇵",
                    description: "Emphasizes umami with miso, soy sauce, and mirin",
                    keyIngredients: ["Miso paste", "Soy sauce", "Mirin"]
                ),
                RegionalVariation(
                    name: "Chinese Style",
                    flagEmoji: "🇨🇳",
                    description: "Features ginger, scallions, and soy-based sauces",
                    keyIngredients: ["Fresh ginger", "Scallions", "Hoisin sauce"]
                ),
                RegionalVariation(
                    name: "Thai Style",
                    flagEmoji: "🇹🇭",
                    description: "Balances sweet, sour, and spicy with herbs",
                    keyIngredients: ["Lemongrass", "Fish sauce", "Thai basil"]
                )
            ]
            
        default:
            return []
        }
    }
}

// MARK: - Regional Variation Structure

struct RegionalVariation {
    let name: String
    let flagEmoji: String
    let description: String
    let keyIngredients: [String]
}

// MARK: - Preview

#Preview {
    let sampleIngredients = [
        "Atlantic Salmon", "Fresh Dill", "Garlic", "Lemon", "Olive Oil",
        "Sea Salt", "Black Pepper", "Butter"
    ]
    
    ScrollView {
        CulturalContextView(
            dishName: "Grilled Atlantic Salmon",
            category: .seafood,
            ingredients: sampleIngredients
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}