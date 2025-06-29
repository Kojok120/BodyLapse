import SwiftUI

extension Color {
    // Primary colors for the new design
    static let bodyLapseTurquoise = Color(red: 0.0, green: 0.686, blue: 0.8) // #00AFCC
    static let bodyLapseYellow = Color(red: 1.0, green: 0.843, blue: 0.0) // #FFD700
    static let bodyLapseLightGray = Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5
    
    // Legacy colors (kept for compatibility)
    static let bodyLapseTeal = Color(red: 0.0, green: 0.5, blue: 0.5)
    static let bodyLapseGreen = Color(red: 0.4, green: 0.7, blue: 0.4)
    static let bodyLapseOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    
    static let bodyLapseDarkTeal = Color(red: 0.0, green: 0.3, blue: 0.4)
    static let bodyLapseLightGreen = Color(red: 0.6, green: 0.85, blue: 0.6)
    static let bodyLapseDarkOrange = Color(red: 0.8, green: 0.4, blue: 0.1)
    
    static let bodyLapseBackground = Color.white
    static let bodyLapseCardBackground = Color.white
}

struct GradientColors {
    static let primaryGradient = LinearGradient(
        colors: [Color.bodyLapseTeal, Color.bodyLapseGreen, Color.bodyLapseOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color.bodyLapseDarkTeal, Color.bodyLapseGreen],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color.bodyLapseOrange, Color.bodyLapseYellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [Color.bodyLapseDarkTeal.opacity(0.3), Color.bodyLapseBackground],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.bodyLapseCardBackground, Color.bodyLapseDarkTeal.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ThemedButton: ViewModifier {
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary   // Turquoise button for navigation actions
        case secondary // Gray button for secondary actions
        case accent    // Yellow button for CTA actions
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(foregroundColor)
            .font(.headline)
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: shadowColor.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .bodyLapseTurquoise
        case .secondary:
            return .gray.opacity(0.15)
        case .accent:
            return .bodyLapseYellow
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .accent:
            return .black
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return .bodyLapseTurquoise
        case .secondary:
            return .gray
        case .accent:
            return .bodyLapseYellow
        }
    }
}

struct ThemedCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.bodyLapseLightGray, lineWidth: 1)
            )
            .shadow(color: Color.gray.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func themedButton(style: ThemedButton.ButtonStyle = .primary) -> some View {
        self.modifier(ThemedButton(style: style))
    }
    
    func themedCard() -> some View {
        self.modifier(ThemedCard())
    }
}