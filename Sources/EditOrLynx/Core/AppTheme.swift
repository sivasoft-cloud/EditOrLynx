import SwiftUI
import AppKit

public enum NotchyGlassVariant: String, CaseIterable, Identifiable, Codable {
    case liquidGlass = "liquidGlass"
    case matteDark   = "matteDark"
    case trueBlack   = "trueBlack"
    case liquidLight = "liquidLight"
    case matteLight  = "matteLight"

    public var id: String { rawValue }

    public var isLight: Bool {
        self == .liquidLight || self == .matteLight
    }

    public var displayName: String {
        switch self {
        case .liquidGlass: return "Liquid Glass (Dark)"
        case .matteDark:   return "Matte Dark"
        case .trueBlack:   return "True OLED Black"
        case .liquidLight: return "Liquid Glass (Light)"
        case .matteLight:  return "Matte Light"
        }
    }

    public var subtitle: String {
        switch self {
        case .liquidGlass: return "Translucent dark glass with specular rim highlight"
        case .matteDark:   return "Solid deep dark finish for a clean look"
        case .trueBlack:   return "Pure OLED black matching the display notch"
        case .liquidLight: return "Translucent frosted crystal glass for light mode"
        case .matteLight:  return "Clean crisp light finish with subtle shadow"
        }
    }
}

public enum AppTheme {
    // Backgrounds
    public static let bg = Color(nsColor: NSColor(white: 0.08, alpha: 1.0))
    public static let cardBg = Color(nsColor: NSColor(white: 0.12, alpha: 0.95))
    public static let elevatedBg = Color(nsColor: NSColor(white: 0.16, alpha: 0.85))
    public static let hoverBg = Color.white.opacity(0.06)
    public static let stroke = Color.white.opacity(0.10)
    public static let divider = Color.white.opacity(0.08)

    // Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.70)
    public static let textTertiary = Color.white.opacity(0.40)

    // Accents
    public static let accent = Color(red: 0.35, green: 0.55, blue: 1.0)
    public static let success = Color(red: 0.25, green: 0.82, blue: 0.45)
    public static let warning = Color(red: 1.0, green: 0.65, blue: 0.20)
    public static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)
}
