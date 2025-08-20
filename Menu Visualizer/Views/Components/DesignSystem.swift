//
//  DesignSystem.swift
//  Menu Visualizer
//
//  Comprehensive visual design system for appetizing dish visualization UI
//  Focused on warm, food-inspired colors that stimulate appetite
//

import SwiftUI

// MARK: - Material Extensions

extension Material {
    /// Regular material for backwards compatibility  
    static let regularMaterial = Material.regular
}

extension Color {
    /// Regular material as a Color for backwards compatibility
    static let regularMaterial = Color(.systemBackground).opacity(0.8)
}

// MARK: - Color System

extension Color {
    
    // MARK: - Primary Appetizing Colors
    
    /// Rich, appetite-stimulating primary colors
    static let appetiteRed = Color(red: 0.89, green: 0.29, blue: 0.23) // #E34A3A
    static let warmOrange = Color(red: 0.98, green: 0.55, blue: 0.18) // #FA8C2E
    static let goldenYellow = Color(red: 0.96, green: 0.81, blue: 0.23) // #F5CF3A
    static let richBrown = Color(red: 0.55, green: 0.35, blue: 0.23) // #8C593A
    
    // MARK: - Secondary Earth Tones
    
    /// Complementary earth tones for secondary elements
    static let sageGreen = Color(red: 0.57, green: 0.64, blue: 0.51) // #91A382
    static let warmGray = Color(red: 0.45, green: 0.42, blue: 0.38) // #736B61
    static let creamWhite = Color(red: 0.98, green: 0.96, blue: 0.93) // #FAF5ED
    static let softBeige = Color(red: 0.95, green: 0.91, blue: 0.85) // #F2E8D9
    
    // MARK: - Accent Colors
    
    /// Interactive elements and highlights
    static let spiceOrange = Color(red: 0.95, green: 0.45, blue: 0.12) // #F2731E
    static let herbGreen = Color(red: 0.34, green: 0.69, blue: 0.31) // #57AF4F
    static let wineRed = Color(red: 0.72, green: 0.11, blue: 0.11) // #B81C1C
    
    // MARK: - Dietary Category Colors
    
    /// Distinct colors for dietary indicators
    static let vegetarianGreen = Color(red: 0.40, green: 0.73, blue: 0.42) // #66BA6B
    static let veganEmerald = Color(red: 0.20, green: 0.59, blue: 0.45) // #339772
    static let glutenFreeBlue = Color(red: 0.30, green: 0.58, blue: 0.89) // #4D94E3
    static let organicPurple = Color(red: 0.58, green: 0.40, blue: 0.74) // #9466BD
    static let spicyRed = Color(red: 0.92, green: 0.34, blue: 0.34) // #EB5757
    
    // MARK: - Neutral Elegance
    
    /// Elegant neutrals for text and backgrounds
    static let charcoalGray = Color(red: 0.20, green: 0.20, blue: 0.20) // #333333
    static let midGray = Color(red: 0.47, green: 0.47, blue: 0.47) // #787878
    static let lightGray = Color(red: 0.85, green: 0.85, blue: 0.85) // #D9D9D9
    static let warmWhite = Color(red: 0.99, green: 0.98, blue: 0.96) // #FCF9F5
    
    // MARK: - Status Colors
    
    /// Status and feedback colors
    static let successGreen = Color(red: 0.34, green: 0.69, blue: 0.31) // #57AF4F
    static let warningAmber = Color(red: 0.96, green: 0.81, blue: 0.23) // #F5CF3A
    static let errorCoral = Color(red: 0.96, green: 0.38, blue: 0.38) // #F56161
    
    // MARK: - Background Gradients
    
    /// Appetite-stimulating gradients
    static let warmGradient = LinearGradient(
        colors: [Color.warmOrange.opacity(0.1), Color.goldenYellow.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let appetiteGradient = LinearGradient(
        colors: [Color.appetiteRed.opacity(0.08), Color.spiceOrange.opacity(0.04)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let earthGradient = LinearGradient(
        colors: [Color.sageGreen.opacity(0.06), Color.richBrown.opacity(0.03)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

// MARK: - Typography System

struct AppTypography {
    
    // MARK: - Dish Names & Headlines
    
    static let dishNameLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let dishNameMedium = Font.system(size: 22, weight: .bold, design: .rounded)
    static let dishNameSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
    
    // MARK: - Body Text
    
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // MARK: - Emphasis & Sensory
    
    static let sensoryItalic = Font.system(size: 16, weight: .medium, design: .default).italic()
    static let emphasisBold = Font.system(size: 16, weight: .bold, design: .default)
    static let highlightMedium = Font.system(size: 14, weight: .semibold, design: .default)
    
    // MARK: - Details & Captions
    
    static let captionLarge = Font.system(size: 12, weight: .medium, design: .default)
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .semibold, design: .default)
    
    // MARK: - Interactive Elements
    
    static let buttonText = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let buttonTextSmall = Font.system(size: 14, weight: .medium, design: .rounded)
    static let tabText = Font.system(size: 12, weight: .medium, design: .default)
}

// MARK: - Spacing System

struct AppSpacing {
    
    // MARK: - Base Spacing Units
    
    static let xs: CGFloat = 4      // Tight spacing
    static let sm: CGFloat = 8      // Small spacing
    static let md: CGFloat = 16     // Medium spacing - default
    static let lg: CGFloat = 24     // Large spacing
    static let xl: CGFloat = 32     // Extra large spacing
    static let xxl: CGFloat = 48    // Section spacing
    
    // MARK: - Component Specific
    
    static let cardPadding: CGFloat = 20
    static let buttonPadding: CGFloat = 16
    static let chipPadding: CGFloat = 12
    static let listItemSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 28
    
    // MARK: - Corner Radius
    
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
}

// MARK: - Shadow System

struct AppShadows {
    
    static let cardShadow = Color.black.opacity(0.08)
    static let elevatedShadow = Color.black.opacity(0.12)
    static let buttonShadow = Color.black.opacity(0.15)
    
    static let subtleRadius: CGFloat = 2
    static let cardRadius: CGFloat = 4
    static let elevatedRadius: CGFloat = 8
    static let prominentRadius: CGFloat = 12
}

// MARK: - Animation System

struct AppAnimations {
    
    static let quickEase = Animation.easeInOut(duration: 0.2)
    static let standardEase = Animation.easeInOut(duration: 0.3)
    static let slowEase = Animation.easeInOut(duration: 0.5)
    
    static let bouncy = Animation.spring(response: 0.6, dampingFraction: 0.7)
    static let gentle = Animation.spring(response: 0.4, dampingFraction: 0.8)
    
    static let fadeIn = Animation.easeIn(duration: 0.3)
    static let fadeOut = Animation.easeOut(duration: 0.2)
}

// MARK: - Component Styles

// MARK: - Card Styles

struct AppCardStyle: ViewModifier {
    let background: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(
        background: Color = Color(.systemBackground),
        cornerRadius: CGFloat = AppSpacing.cornerRadiusMedium,
        shadowRadius: CGFloat = AppShadows.cardRadius
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: AppShadows.cardShadow, radius: shadowRadius, x: 0, y: 2)
    }
}

extension View {
    func appCard(
        background: Color = Color(.systemBackground),
        cornerRadius: CGFloat = AppSpacing.cornerRadiusMedium,
        shadowRadius: CGFloat = AppShadows.cardRadius
    ) -> some View {
        modifier(AppCardStyle(background: background, cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}

// MARK: - Button Styles

struct AppButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    
    init(
        backgroundColor: Color = .spiceOrange,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = AppSpacing.cornerRadiusMedium
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonText)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppSpacing.buttonPadding)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .shadow(
                color: AppShadows.buttonShadow,
                radius: configuration.isPressed ? AppShadows.subtleRadius : AppShadows.cardRadius,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppAnimations.quickEase, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var appetizing: AppButtonStyle {
        AppButtonStyle(backgroundColor: .spiceOrange, foregroundColor: .white)
    }
    
    static var secondary: AppButtonStyle {
        AppButtonStyle(backgroundColor: .sageGreen, foregroundColor: .white)
    }
    
    static var subtle: AppButtonStyle {
        AppButtonStyle(backgroundColor: .softBeige, foregroundColor: .charcoalGray)
    }
}

// MARK: - Chip Styles

struct IngredientChipStyle: ViewModifier {
    let backgroundColor: Color
    let foregroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .font(AppTypography.captionLarge)
            .fontWeight(.medium)
            .padding(.horizontal, AppSpacing.chipPadding)
            .padding(.vertical, AppSpacing.xs)
            .background(backgroundColor, in: Capsule())
            .foregroundColor(foregroundColor)
    }
}

extension View {
    func ingredientChip(
        backgroundColor: Color = .vegetarianGreen.opacity(0.15),
        foregroundColor: Color = .vegetarianGreen
    ) -> some View {
        modifier(IngredientChipStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor))
    }
}

// MARK: - Dietary Indicator Styles

enum DietaryIndicator: String, CaseIterable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten Free"
    case organic = "Organic"
    case spicy = "Spicy"
    case lowCalorie = "Low Calorie"
    
    var icon: String {
        switch self {
        case .vegetarian: return "leaf.fill"
        case .vegan: return "heart.fill"
        case .glutenFree: return "circle.slash"
        case .organic: return "checkmark.seal.fill"
        case .spicy: return "flame.fill"
        case .lowCalorie: return "heart.text.square"
        }
    }
    
    var color: Color {
        switch self {
        case .vegetarian: return .vegetarianGreen
        case .vegan: return .veganEmerald
        case .glutenFree: return .glutenFreeBlue
        case .organic: return .organicPurple
        case .spicy: return .spicyRed
        case .lowCalorie: return .sageGreen
        }
    }
    
    var backgroundColor: Color {
        return color.opacity(0.12)
    }
}

// MARK: - Loading State Styles

struct LoadingVisualizationStyle: View {
    let dishName: String
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Animated sparkles
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    let phaseOffset = animationPhase + Double(index) * 0.5
                    let sinValue = sin(phaseOffset)
                    let opacity = 0.3 + 0.7 * sinValue
                    let scale = 0.8 + 0.2 * sinValue
                    
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.spiceOrange)
                        .opacity(opacity)
                        .scaleEffect(scale)
                }
            }
            
            Text("Creating visualization for")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.midGray)
            
            Text(dishName)
                .font(AppTypography.dishNameSmall)
                .foregroundColor(.charcoalGray)
                .multilineTextAlignment(.center)
            
            Text("Analyzing flavors and presentation...")
                .font(AppTypography.captionLarge)
                .foregroundColor(.midGray)
                .italic()
        }
        .padding(AppSpacing.xl)
        .appCard(background: .warmWhite)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 2 * .pi
            }
        }
    }
}

// MARK: - Accessibility Helpers

extension View {
    func accessibleVisualizationCard(
        dishName: String,
        hasVisualization: Bool,
        isGenerating: Bool
    ) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel("\(dishName)")
            .accessibilityValue(
                hasVisualization ? "AI visualization available" :
                isGenerating ? "Generating visualization" : "No visualization"
            )
            .accessibilityHint("Tap to view detailed dish information and AI-generated visualization")
    }
    
    func accessibleIngredientChip(_ ingredient: String) -> some View {
        self.accessibilityLabel("Ingredient: \(ingredient)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to learn more about this ingredient")
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct DesignSystemPreviews {
    static var previews: some View {
        Group {
            // Color palette preview
            VStack(spacing: 16) {
                Text("Appetizing Color Palette")
                    .font(AppTypography.dishNameLarge)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    colorSwatch("Appetite Red", .appetiteRed)
                    colorSwatch("Warm Orange", .warmOrange)
                    colorSwatch("Golden Yellow", .goldenYellow)
                    colorSwatch("Rich Brown", .richBrown)
                    colorSwatch("Sage Green", .sageGreen)
                    colorSwatch("Spice Orange", .spiceOrange)
                    colorSwatch("Herb Green", .herbGreen)
                    colorSwatch("Wine Red", .wineRed)
                }
            }
            .padding()
            .previewDisplayName("Color Palette")
            
            // Typography preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Dish Typography")
                    .font(AppTypography.dishNameLarge)
                    .foregroundColor(.charcoalGray)
                
                Text("Grilled Atlantic Salmon")
                    .font(AppTypography.dishNameMedium)
                    .foregroundColor(.appetiteRed)
                
                Text("A perfectly seasoned fillet with fresh herbs and bright lemon sauce")
                    .font(AppTypography.sensoryItalic)
                    .foregroundColor(.midGray)
                
                Text("Fresh herbs, garlic, olive oil")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.charcoalGray)
            }
            .padding()
            .previewDisplayName("Typography")
        }
    }
    
    private static func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
            
            Text(name)
                .font(AppTypography.captionSmall)
                .multilineTextAlignment(.center)
        }
    }
}

struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemPreviews.previews
    }
}
#endif