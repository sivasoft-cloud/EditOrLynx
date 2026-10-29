import SwiftUI
import AppKit

public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

public struct NotchGlassBackground: View {
    public var variant: NotchyGlassVariant

    public init(variant: NotchyGlassVariant = .liquidGlass) {
        self.variant = variant
    }

    public var body: some View {
        ZStack {
            switch variant {
            case .liquidGlass:
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .overlay(Color.black.opacity(0.72))
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.white.opacity(0.02), location: 0.25),
                                .init(color: Color.clear, location: 0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

            case .matteDark:
                Color(nsColor: NSColor(white: 0.10, alpha: 0.98))

            case .trueBlack:
                Color.black

            case .liquidLight:
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                    .overlay(Color.white.opacity(0.75))
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.60), location: 0.0),
                                .init(color: Color.black.opacity(0.04), location: 0.4),
                                .init(color: Color.clear, location: 0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

            case .matteLight:
                Color(nsColor: NSColor(white: 0.94, alpha: 0.98))
            }
        }
    }
}
