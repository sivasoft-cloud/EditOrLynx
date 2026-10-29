import SwiftUI
import AppKit

/// Visual style options for the island background
public enum NotchMaterialVariant: String, CaseIterable, Identifiable {
    case liquidGlass = "liquidGlass"
    case matteDark   = "matteDark"
    case trueBlack   = "trueBlack"
    case liquidLight = "liquidLight"
    case matteLight  = "matteLight"

    public var id: String { rawValue }

    public var isLight: Bool {
        self == .liquidLight || self == .matteLight
    }

    public var title: String {
        switch self {
        case .liquidGlass: return "Liquid Glass (Dark)"
        case .matteDark:   return "Matte Dark"
        case .trueBlack:   return "True Black"
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

/// Native macOS Visual Effect wrapper for clean translucent materials
public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

/// Notchy-styled Liquid Glass background with subtle inner highlight and razor rim
public struct NotchyLiquidGlassBackground: View {
    public var variant: NotchMaterialVariant
    public var accentTint: Color?

    public init(variant: NotchMaterialVariant = .liquidGlass, accentTint: Color? = nil) {
        self.variant = variant
        self.accentTint = accentTint
    }

    public var body: some View {
        ZStack {
            switch variant {
            case .liquidGlass:
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color(white: 0.12, opacity: 0.94),
                                Color(white: 0.05, opacity: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            case .matteDark:
                Color(white: 0.09)
            case .trueBlack:
                Color.black.opacity(0.99)
            case .liquidLight:
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color(white: 0.98, opacity: 0.92),
                                Color(white: 0.88, opacity: 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            case .matteLight:
                Color(white: 0.94)
            }

            if let tint = accentTint {
                tint.opacity(0.12)
            }
        }
    }
}

/// Modifier that applies Notchy's signature inner highlight and hairline rim stroke to any shape
public struct NotchSurfaceModifier<S: InsettableShape>: ViewModifier {
    public let shape: S
    public let isExpanded: Bool
    public var isLight: Bool = false

    public func body(content: Content) -> some View {
        content
            .clipShape(shape)
            // Subtle top inner highlight (specular glow)
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: (isLight ? Color.black : Color.white).opacity(isLight ? 0.08 : 0.15), location: 0.0),
                                .init(color: (isLight ? Color.black : Color.white).opacity(isLight ? 0.02 : 0.04), location: 0.3),
                                .init(color: Color.clear, location: 0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
            }
            // Crisp outer hairline rim stroke
            .overlay {
                shape
                    .strokeBorder((isLight ? Color.black : Color.white).opacity(isLight ? 0.12 : 0.08), lineWidth: 0.75)
            }
            // High-fidelity drop shadow ONLY in expanded mode
            // (In compact mode, shadows are strictly disabled to prevent blocking clicks on underlying apps)
            .shadow(
                color: Color.black.opacity(isExpanded ? (isLight ? 0.18 : 0.35) : 0.0),
                radius: isExpanded ? 16 : 0,
                x: 0,
                y: isExpanded ? 8 : 0
            )
            .shadow(
                color: Color.black.opacity(isExpanded ? (isLight ? 0.10 : 0.20) : 0.0),
                radius: isExpanded ? 4 : 0,
                x: 0,
                y: isExpanded ? 2 : 0
            )
    }
}

extension View {
    public func notchSurfaceStyle<S: InsettableShape>(shape: S, isExpanded: Bool, isLight: Bool = false) -> some View {
        self.modifier(NotchSurfaceModifier(shape: shape, isExpanded: isExpanded, isLight: isLight))
    }
}
