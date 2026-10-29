import SwiftUI
import AppKit

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, modules, downloads, ai, extensions, advanced, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    "General"
        case .appearance: "Appearance"
        case .modules:    "Modules"
        case .downloads:  "Downloader"
        case .ai:         "AI Assistant"
        case .extensions: "Extensions"
        case .advanced:   "Advanced"
        case .about:      "About"
        }
    }

    var icon: String {
        switch self {
        case .general:    "gear"
        case .appearance: "paintbrush"
        case .modules:    "square.grid.2x2"
        case .downloads:  "arrow.down.circle"
        case .ai:         "sparkles"
        case .extensions: "puzzlepiece.extension"
        case .advanced:   "wrench.and.screwdriver"
        case .about:      "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selectedPane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(NotchyTheme.divider)
                .frame(width: 1)
            contentArea
        }
        .frame(minWidth: 820, idealWidth: 980, minHeight: 580, idealHeight: 700)
        .background(NotchyTheme.bg)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // App Branding Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Edit.or.lynx")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

            ForEach(SettingsPane.allCases) { pane in
                sidebarRow(pane)
            }
            Spacer()
            quitRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: 204)
        .background(NotchyTheme.bg)
    }

    private func sidebarRow(_ pane: SettingsPane) -> some View {
        let isSelected = selectedPane == pane
        return Button {
            selectedPane = pane
        } label: {
            HStack(spacing: 9) {
                Image(systemName: pane.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .accentColor : NotchyTheme.textSec)
                    .frame(width: 18, alignment: .center)
                Text(pane.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : NotchyTheme.textSec)
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? NotchyTheme.sidebarSel : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var quitRow: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(NotchyTheme.textSec)
                    .frame(width: 18, alignment: .center)
                Text("Quit")
                    .font(.system(size: 13))
                    .foregroundColor(NotchyTheme.textSec)
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    private var contentArea: some View {
        Group {
            if selectedPane == .extensions {
                detailContent
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    detailContent
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedPane {
        case .general:    GeneralSettingsView()
        case .appearance: AppearanceSettingsView()
        case .modules:    ModuleSettingsView()
        case .downloads:  DownloaderSettingsView()
        case .ai:         AISettingsView()
        case .extensions: ExtensionsSettingsView()
        case .advanced:   AdvancedSettingsView()
        case .about:      AboutSettingsView()
        }
    }
}

// MARK: - Backward-Compatibility Wrappers

public struct SettingSectionLabel: View {
    public let title: String
    public init(title: String) { self.title = title }

    public var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(NotchyTheme.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public typealias SettingGroup<Content: View> = SettingsGroup<Content>
public typealias SettingRowDivider = SWDivider
public typealias SettingToggleRow = SWToggleRow

public struct StepperField: View {
    @Binding public var value: Double
    public let step: Double
    public let range: ClosedRange<Double>
    public let label: (Double) -> String

    public init(value: Binding<Double>, step: Double, range: ClosedRange<Double>, label: @escaping (Double) -> String) {
        self._value = value
        self.step = step
        self.range = range
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 0) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)

            Text(label(value))
                .font(.system(size: 12, design: .monospaced))
                .frame(minWidth: 44, alignment: .center)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(white: 1, opacity: 0.22), lineWidth: 1)
        )
    }
}

// Backward-compat wrapper used by ExtensionsSettingsView
public struct SettingsCard<Content: View>: View {
    public let title: String
    public var subtitle: String? = nil
    @ViewBuilder public var content: Content

    public init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(NotchyTheme.textSec)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Rectangle()
                .fill(NotchyTheme.divider)
                .frame(height: 0.5)

            content
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchyTheme.cardBg)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(NotchyTheme.border, lineWidth: 1)
        )
    }
}
