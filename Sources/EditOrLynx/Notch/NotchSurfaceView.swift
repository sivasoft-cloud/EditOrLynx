import SwiftUI

public struct NotchSurfaceView: View {
    @EnvironmentObject var controller: NotchWindowController
    @AppStorage("appearance.notchMaterialVariant") var variantRaw: String = NotchyGlassVariant.liquidGlass.rawValue

    private var variant: NotchyGlassVariant {
        NotchyGlassVariant(rawValue: variantRaw) ?? .liquidGlass
    }

    private var shape: NotchShape {
        NotchShape(
            cornerRadius: controller.isExpanded ? 24 : 18,
            earRadius: 12,
            isAttachedToTop: true
        )
    }

    public var body: some View {
        let size = controller.currentSize

        ZStack(alignment: .top) {
            // Liquid glass backdrop
            NotchGlassBackground(variant: variant)
                .clipShape(shape)

            // Content
            Group {
                if controller.isExpanded {
                    NotchExpandedView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    NotchCompactView()
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity)
                }
            }

            // Specular top highlight (monoInnerHighlight)
            shape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: (variant.isLight ? Color.black : Color.white).opacity(variant.isLight ? 0.08 : 0.15), location: 0.0),
                            .init(color: (variant.isLight ? Color.black : Color.white).opacity(variant.isLight ? 0.02 : 0.03), location: 0.3),
                            .init(color: Color.clear, location: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
                .allowsHitTesting(false)

            // Razor rim stroke (rimStroke)
            shape
                .strokeBorder((variant.isLight ? Color.black : Color.white).opacity(variant.isLight ? 0.12 : 0.08), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .shadow(color: .black.opacity(controller.isExpanded ? 0.35 : 0.0), radius: controller.isExpanded ? 16 : 0, y: controller.isExpanded ? 8 : 0)
        .contentShape(shape)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                controller.toggleExpanded()
            }
        }
    }
}
