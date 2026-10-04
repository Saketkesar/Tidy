import SwiftUI
import AppKit

public enum TidyTheme {
    // Elegant soft blush-rose palette (clean, tasteful, modern - never neon or dark)
    public static let primaryRose = Color(hex: "E04B76")
    public static let roseHover = Color(hex: "CE3A65")
    public static let roseLight = Color(hex: "FFF0F5")
    public static let roseSoftBorder = Color(hex: "F3E8EE")
    public static let roseChipBg = Color(hex: "FDF4F7")
    
    // Aliases
    public static let blushLight = roseLight
    public static let blushBorder = roseSoftBorder
    public static let blushSubtle = roseChipBg
    
    // Gradients
    public static let primaryGradient = LinearGradient(
        colors: [Color(hex: "F2678F"), Color(hex: "E04B76")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let subtlePinkGradient = LinearGradient(
        colors: [Color(hex: "FFF7FA"), Color(hex: "FFF0F5")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let cardGradient = LinearGradient(
        colors: [Color.white, Color(hex: "FFFBFC")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Backgrounds - Clean white and soft warm off-white (never dark)
    public static let windowBackground = Color(hex: "FAF8F9")
    public static let sidebarBackground = Color(hex: "FCFAFB")
    public static let cardBackground = Color.white
    public static let innerCardBackground = Color(hex: "FAF7F9")
    
    // Text & Accents (High contrast, crisp typography)
    public static let textPrimary = Color(hex: "1F1A24")
    public static let textSecondary = Color(hex: "6D6577")
    public static let textMuted = Color(hex: "9F97A8")
    
    public static let accentColor = Color(hex: "E04B76")
    public static let successColor = Color(hex: "10B981")
    public static let warningColor = Color(hex: "F59E0B")
    public static let dangerColor = Color(hex: "EF4444")
    
    // Soft subtle shadow for floating white cards
    public static let cardShadow = Color(hex: "5A2D42").opacity(0.04)
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
