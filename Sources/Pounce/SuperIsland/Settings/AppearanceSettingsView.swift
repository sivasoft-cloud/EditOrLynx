import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState

    private enum Defaults {
        static let bounceAmount: Double = 0.25
        static let animationLevel = AnimationLevel.full
        static let reduceMotion = false
        static let compactIslandWidth: Double = 216
        static let compactIslandHeight: Double = 32
        static let expandedIslandWidth: Double = 460
        static let expandedIslandHeight: Double = 110
        static let notchMaterial = NotchMaterialVariant.liquidGlass
        static let continuousCurvature = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // MARK: - Notch Material & Glass Style
            section(
                title: "Notch Surface & Glass Material",
                reset: {
                    appState.notchMaterialVariant = Defaults.notchMaterial
                    appState.continuousCurvature = Defaults.continuousCurvature
                }
            ) {
                SWMenuRow(
                    title: "Material Style",
                    subtitle: appState.notchMaterialVariant.subtitle,
                    selection: Binding(
                        get: { appState.notchMaterialVariant },
                        set: { appState.notchMaterialVariant = $0 }
                    ),
                    options: NotchMaterialVariant.allCases.map { ($0, $0.title) }
                )

                SWDivider()

                SWToggleRow(
                    title: "Apple Continuous Squircle (G2 Curvature)",
                    subtitle: "Blends outward notch ears and corners with high-order geometric continuity",
                    isOn: $appState.continuousCurvature
                )
            }

            // MARK: - Animation
            section(
                title: "Animation & Dynamics",
                reset: {
                    appState.animationLevel = Defaults.animationLevel
                    appState.reduceMotion = Defaults.reduceMotion
                    appState.bounceAmount = Defaults.bounceAmount
                }
            ) {
                SWMenuRow(
                    title: "Animation Intensity",
                    subtitle: "Controls island motion, bounce, and transitions",
                    selection: Binding(
                        get: { AnimationLevel(rawValue: appState.animationLevelRaw) ?? .full },
                        set: { appState.animationLevelRaw = $0.rawValue }
                    ),
                    options: AnimationLevel.allCases.map { ($0, $0.title) }
                )

                SWDivider()

                SWToggleRow(
                    title: "Reduce Motion",
                    subtitle: "Disable springs and simplify island transitions",
                    isOn: $appState.reduceMotion
                )

                SWDivider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spring Bounce").font(.system(size: 13))
                        Text("Extra bounce for compact ↔ expanded animations")
                            .font(.system(size: 11))
                            .foregroundColor(NotchyTheme.textSec)
                    }
                    Spacer(minLength: 12)
                    StepperField(
                        value: $appState.bounceAmount,
                        step: 0.05,
                        range: 0.0...0.5
                    ) { "\(Int(($0 * 100).rounded()))%" }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }

            // MARK: - Compact Size
            section(
                title: "Compact Notch Size",
                reset: {
                    appState.compactIslandWidth = Defaults.compactIslandWidth
                    appState.compactIslandHeight = Defaults.compactIslandHeight
                }
            ) {
                sizeRow(
                    title: "Width",
                    description: "Pill width on notched MacBook displays",
                    value: $appState.compactIslandWidth,
                    step: 2,
                    range: 140...320,
                    unit: "pt"
                )
                SWDivider()
                sizeRow(
                    title: "Height",
                    description: "Pill height on notched MacBook displays",
                    value: $appState.compactIslandHeight,
                    step: 1,
                    range: 22...60,
                    unit: "pt"
                )
            }

            // MARK: - Expanded Size
            section(
                title: "Expanded Island Dimensions",
                reset: {
                    appState.expandedIslandWidth = Defaults.expandedIslandWidth
                    appState.expandedIslandHeight = Defaults.expandedIslandHeight
                }
            ) {
                sizeRow(
                    title: "Expanded Width",
                    description: "Width when hovered or displaying modules",
                    value: $appState.expandedIslandWidth,
                    step: 4,
                    range: 320...640,
                    unit: "pt"
                )
                SWDivider()
                sizeRow(
                    title: "Expanded Height",
                    description: "Height when hovered or displaying modules",
                    value: $appState.expandedIslandHeight,
                    step: 2,
                    range: 70...200,
                    unit: "pt"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        reset: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SettingSectionLabel(title: title)
                Button("Reset", action: reset)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(NotchyTheme.textSec)
            }
            SettingsGroup {
                content()
            }
        }
    }

    private func sizeRow(
        title: String,
        description: String,
        value: Binding<Double>,
        step: Double,
        range: ClosedRange<Double>,
        unit: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(description).font(.system(size: 11)).foregroundColor(NotchyTheme.textSec)
            }
            Spacer(minLength: 12)
            StepperField(
                value: value,
                step: step,
                range: range
            ) { "\(Int($0)) \(unit)" }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}
