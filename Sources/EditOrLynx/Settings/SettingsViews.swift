import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case downloader
    case ai
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .downloader: return "Downloader"
        case .ai:         return "AI Assistant"
        case .about:      return "About"
        }
    }

    public var iconName: String {
        switch self {
        case .general:    return "gear"
        case .appearance: return "paintbrush"
        case .downloader: return "arrow.down.circle"
        case .ai:         return "sparkles"
        case .about:      return "info.circle"
        }
    }
}

public struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .downloader

    public var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                    Text("Edit.or.lynx")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                Divider()
                    .background(AppTheme.divider)
                    .padding(.bottom, 6)

                ForEach(SettingsTab.allCases) { tab in
                    let isSel = selectedTab == tab
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13))
                                .frame(width: 20)
                                .foregroundStyle(isSel ? AppTheme.accent : AppTheme.textSecondary)
                            Text(tab.title)
                                .font(.system(size: 13, weight: isSel ? .semibold : .medium))
                                .foregroundStyle(isSel ? AppTheme.textPrimary : AppTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isSel ? Color.white.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                }

                Spacer()
            }
            .frame(width: 190)
            .background(AppTheme.bg)

            Divider()
                .background(AppTheme.divider)

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsPane()
                    case .appearance:
                        AppearanceSettingsPane()
                    case .downloader:
                        DownloaderSettingsPane()
                    case .ai:
                        AISettingsPane()
                    case .about:
                        AboutSettingsPane()
                    }
                }
                .padding(24)
            }
            .background(Color(nsColor: NSColor(white: 0.05, alpha: 1.0)))
        }
        .frame(width: 720, height: 480)
    }
}

// MARK: - General Pane
public struct GeneralSettingsPane: View {
    @AppStorage("general.launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("general.showInMenuBar") var showInMenuBar: Bool = true
    @AppStorage("general.clipboardMonitor") var clipboardMonitor: Bool = true

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup(title: "Startup & System") {
                SWToggleRow(title: "Launch at Login", subtitle: "Automatically launch Edit.or.lynx when you sign in.", isOn: $launchAtLogin)
                SWDivider()
                SWToggleRow(title: "Show Menu Bar Icon", subtitle: "Keep quick access available in the macOS top menu bar.", isOn: $showInMenuBar)
                SWDivider()
                SWToggleRow(title: "Automatic Clipboard Monitor", subtitle: "Prompt to download supported media and file links automatically.", isOn: $clipboardMonitor)
            }
        }
    }
}

// MARK: - Appearance Pane
public struct AppearanceSettingsPane: View {
    @AppStorage("appearance.notchMaterialVariant") var variantRaw: String = NotchyGlassVariant.liquidGlass.rawValue
    @AppStorage("appearance.continuousCurvature") var continuousCurvature: Bool = true

    private var selectedVariant: Binding<NotchyGlassVariant> {
        Binding(
            get: { NotchyGlassVariant(rawValue: variantRaw) ?? .liquidGlass },
            set: { variantRaw = $0.rawValue }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup(title: "Notch Surface Material") {
                SWMenuRow(
                    title: "Liquid Glass Mode",
                    subtitle: selectedVariant.wrappedValue.subtitle,
                    selection: selectedVariant,
                    options: NotchyGlassVariant.allCases.map { ($0, $0.displayName) }
                )
                SWDivider()
                SWToggleRow(
                    title: "Apple G2 Curvature Continuity",
                    subtitle: "Renders authentic continuous curvature squircle matching MacBook display corners.",
                    isOn: $continuousCurvature
                )
            }
        }
    }
}

// MARK: - Downloader Pane
public struct DownloaderSettingsPane: View {
    @AppStorage("downloader.maxConnections") var maxConnections: Double = 16
    @AppStorage("downloader.maxConcurrent") var maxConcurrent: Double = 5
    @AppStorage("downloader.autoZipGDrive") var autoZipGDrive: Bool = true

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup(title: "Turbo Engine Connections") {
                SWSliderRow(
                    title: "Max Connections per Task",
                    subtitle: "Segments large files into parallel chunk streams for up to 16x faster speeds.",
                    value: $maxConnections,
                    range: 1...32,
                    step: 1,
                    valueLabel: "\(Int(maxConnections)) threads"
                )
                SWDivider()
                SWSliderRow(
                    title: "Concurrent Downloads",
                    subtitle: "Number of parallel downloads executing simultaneously.",
                    value: $maxConcurrent,
                    range: 1...10,
                    step: 1,
                    valueLabel: "\(Int(maxConcurrent)) tasks"
                )
            }

            SettingsGroup(title: "Google Drive & Cloud Batching") {
                SWToggleRow(
                    title: "Auto-Zip Google Drive Folders",
                    subtitle: "Automatically groups and downloads shared folders with up to 100 items into a single archive.",
                    isOn: $autoZipGDrive
                )
                SWDivider()
                SWButtonRow(
                    title: "Downloads Folder",
                    subtitle: "~/Downloads",
                    buttonTitle: "Choose…",
                    icon: "folder"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.begin { res in
                        if res == .OK, let url = panel.url {
                            UserDefaults.standard.set(url.path, forKey: "downloader.customPath")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AI Pane
public struct AISettingsPane: View {
    @AppStorage("ai.provider") var provider: String = "OpenAI"
    @AppStorage("ai.apiKey") var apiKey: String = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup(title: "AI Automation Provider") {
                SWMenuRow(
                    title: "Selected Provider",
                    subtitle: "LLM backend for smart clipboard renaming and media summarization.",
                    selection: $provider,
                    options: [("OpenAI", "OpenAI"), ("Anthropic", "Anthropic Claude"), ("Gemini", "Google Gemini"), ("Ollama", "Local Ollama")]
                )
            }
        }
    }
}

// MARK: - About Pane
public struct AboutSettingsPane: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                HStack(spacing: 16) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit.or.lynx")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Version 2.0.2 (Build 2026)")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)

                        Text("Made by edit.or.siva · Instagram @edit.or.siva")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
    }
}
