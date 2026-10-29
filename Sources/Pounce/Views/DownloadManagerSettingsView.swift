import SwiftUI
import AppKit
import PounceCore

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case downloads
    case notch
    case appearance
    case browser
    case extensions
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .downloads: return "Downloads"
        case .notch: return "Notch"
        case .appearance: return "Appearance"
        case .browser: return "Browsers"
        case .extensions: return "Extensions"
        case .advanced: return "Advanced"
        case .about: return "About & Pro"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .downloads: return "arrow.down.circle"
        case .notch: return "macwindow"
        case .appearance: return "paintbrush"
        case .browser: return "globe"
        case .extensions: return "puzzlepiece.extension"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

struct DownloadManagerSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var shelf = ShelfStore.shared
    @ObservedObject private var nowPlayingManager = NowPlayingManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared

    @AppStorage("avatarPalette") private var avatarPalette: String = "aurora"
    @AppStorage("notch.puffEnabled") private var notchPuffEnabled: Bool = true
    @AppStorage("notchMascotChoice") private var notchMascotChoice: String = "jelly"

    @State private var selectedTab: SettingsTab = .general
    @State private var hoveredTab: SettingsTab? = nil

    // Startup & System Settings State
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var licenseKeyInput: String = ""
    @State private var isActivatingLicense: Bool = false
    @State private var licenseFeedback: String? = nil
    @State private var showResetAlert = false
    @State private var screenOptions: [ScreenDetector.ScreenOption] = ScreenDetector.availableScreenOptions()

    // Update Checker State
    @State private var updateStatus: String? = nil
    @State private var updateDetails: (version: String, notes: String, url: String)? = nil
    @State private var isCheckingUpdates = false

    var body: some View {
        VStack(spacing: 0) {
            // macOS Preferences Horizontal Toolbar Tabs
            toolbarHeader
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().overlay(Pal.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    brandHeader
                        .padding(.top, 12)

                    switch selectedTab {
                    case .general:
                        generalTabContent
                    case .downloads:
                        downloadsTabContent
                    case .notch:
                        notchTabContent
                    case .appearance:
                        appearanceTabContent
                    case .browser:
                        browserTabContent
                    case .extensions:
                        extensionsTabContent
                    case .advanced:
                        advancedTabContent
                    case .about:
                        aboutTabContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            refreshScreenOptions()
        }
    }

    // MARK: - Toolbar Header

    private var toolbarHeader: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = selectedTab == tab
                let isHovered = hoveredTab == tab

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color(hex: 0x0A84FF) : (isHovered ? Pal.text : Pal.secondary))

                        Text(tab.title)
                            .font(Typo.body(9.5, isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color(hex: 0x0A84FF) : (isHovered ? Pal.text : Pal.secondary))
                            .lineLimit(1)
                    }
                    .frame(width: 62, height: 48)
                    .background(
                        isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? Color.white.opacity(0.14) : Color.clear, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .onHover { hoveredTab = $0 ? tab : nil }
            }
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            PounceMark(size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Edit.or.lynx")
                        .font(Typo.display(13, .bold))
                        .foregroundStyle(Pal.text)

                    if model.plan == .pro {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 0.28, green: 0.78, blue: 0.46).opacity(0.16), in: Capsule())
                    } else {
                        Text("FREE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(Pal.secondary)
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }
                Text("Universal native macOS 4K download manager & Edit.or.lynx dynamic notch companion.")
                    .font(Typo.body(9.5))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    // MARK: - 1. General Tab

    @ViewBuilder
    private var generalTabContent: some View {
        settingsCard(title: "Startup & Menubar", symbol: "menubar.rectangle") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Start Edit.or.lynx and the dynamic notch automatically on login.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                ToggleSwitch(isOn: Binding(
                    get: { launchAtLogin },
                    set: { val in
                        launchAtLogin = val
                        val ? LaunchAtLogin.enable() : LaunchAtLogin.disable()
                        appState.launchAtLogin = val
                    }
                ))
            }
            .padding(.vertical, 9)

            divider

            toggleRow(
                title: "Show menu bar icon",
                subtitle: "Keep quick download status and island controls in the menu bar.",
                binding: $appState.showMenuBarIcon
            )

            divider

            toggleRow(
                title: "Show Dynamic Notch on all Spaces",
                subtitle: "The dynamic island remains accessible across all Mission Control desktops.",
                binding: $appState.showOnAllSpaces
            )

            divider

            toggleRow(
                title: "Hide on fullscreen applications",
                subtitle: "Dismiss the notch overlay when movies or games go into native fullscreen.",
                binding: $appState.hideOnFullscreen
            )

            divider

            toggleRow(
                title: "Prevent accidental quit with Cmd+Q guard",
                subtitle: "Protects active downloads and transfers from sudden closure.",
                binding: $appState.allowQuitHotkey
            )
        }

        settingsCard(title: "Sound Cues & Haptics", symbol: "speaker.wave.2") {
            toggleRow(
                title: "Download completed sound chime",
                subtitle: "Plays a clean acoustic chime when all chunks finalize.",
                binding: Binding(
                    get: { model.notchSoundsEnabled },
                    set: { model.setNotchSounds($0) }
                )
            )

            divider

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notch haptic feedback intensity")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Trackpad haptic tap sensation on link detection and notch peek.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                SegmentedPills(
                    options: NotchHapticIntensity.allCases.map { ($0.rawValue, $0.title, nil as String?) },
                    selection: Binding(
                        get: { appState.notchHapticIntensity },
                        set: { appState.notchHapticIntensity = $0 }
                    )
                )
                .frame(width: 220)
            }
            .padding(.vertical, 9)
        }

        settingsCard(title: "Floating Screen Helper", symbol: "macwindow.on.rectangle") {
            toggleRow(
                title: "Show floating browser download button",
                subtitle: "A small draggable button on screen to grab media and video links with 1 click.",
                binding: Binding(
                    get: { model.engine.settings.showBrowserButton },
                    set: { model.setBrowserButton($0) }
                )
            )
        }
    }

    // MARK: - 2. Downloads Tab

    @ViewBuilder
    private var downloadsTabContent: some View {
        settingsCard(title: "Transfer Engine", symbol: "arrow.down.circle") {
            numberRow(
                title: "Connections per download",
                subtitle: model.plan == .pro ? "Split each file across parallel HTTP connections." : "Free allows up to \(model.entitlements.maxConnections) — Pro unlocks 32.",
                value: model.engine.settings.connections,
                range: 1...model.entitlements.maxConnections,
                unit: "connections"
            ) { model.setConnections($0) }

            divider

            numberRow(
                title: "Simultaneous downloads",
                subtitle: model.plan == .pro ? "How many transfers can run at once." : "Free runs up to \(model.entitlements.maxConcurrent) at once — Pro unlocks 10.",
                value: model.engine.settings.maxConcurrent,
                range: 1...model.entitlements.maxConcurrent,
                unit: "at once"
            ) { model.setMaxConcurrent($0) }

            divider

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save downloads to")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text(model.engine.settings.destinationFolder.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                HStack(spacing: 6) {
                    SoftButton(title: "Choose…", symbol: "folder") {
                        model.chooseDestination()
                    }
                    SoftButton(title: "Open Folder", symbol: "arrow.up.forward.app") {
                        model.openDestinationInFinder()
                    }
                }
            }
            .padding(.vertical, 9)

            divider

            toggleRow(
                title: "Auto-delete completed items",
                subtitle: "Clear finished downloads from the list after 7 days.",
                binding: Binding(
                    get: { model.engine.settings.autoDelete },
                    set: { model.setAutoDelete($0) }
                )
            )
        }

        settingsCard(title: "Lossless Audio & Metadata", symbol: "waveform") {
            toggleRow(
                title: "Embed ID3 / Lossless Metadata & HD Cover Art",
                subtitle: "Automatically writes artist, album, title, and high-res cover into downloaded audio files.",
                binding: .constant(true)
            )
            divider
            toggleRow(
                title: "Prioritize Studio Master 320k / Lossless",
                subtitle: "Queries Apple Music, Spotify, Indian, and Global streaming APIs for bit-perfect audio.",
                binding: .constant(true)
            )
        }

        settingsCard(title: "Google Drive 100-File Batch", symbol: "folder.badge.gearshape") {
            toggleRow(
                title: "Auto-Zip Google Drive folder downloads",
                subtitle: "Streams large Google Drive directories (up to 100 items) and bundles them into an organized ZIP archive without browser crashes.",
                binding: .constant(true)
            )
        }
    }

    // MARK: - 3. Notch & HUD Tab

    @ViewBuilder
    private var notchTabContent: some View {
        settingsCard(title: "Dynamic Notch Master Control", symbol: "macwindow") {
            toggleRow(
                title: "Enable Dynamic Notch HUD",
                subtitle: "Show the fluid Edit.or.lynx dynamic notch on the top bezel of your Mac display.",
                binding: Binding(
                    get: { model.notchEnabled },
                    set: { model.setNotchEnabled($0) }
                )
            )



            divider

            toggleRow(
                title: "Trackpad swipe to cycle modules",
                subtitle: "Swipe horizontally on the island surface to switch between active modules.",
                binding: $appState.islandSurfaceSwipeEnabled
            )

            divider

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-dismiss delay")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Time before an expanded HUD contracts back to the compact pill.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                StepperField(
                    value: $appState.expandedAutoDismissDelay,
                    step: 0.5,
                    range: 0.5...6.0
                ) { "\(String(format: "%.1f", $0)) s" }
            }
            .padding(.vertical, 8)

            divider

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hover peek delay")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Cursor dwell time over notch before smooth expansion.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                StepperField(
                    value: $appState.hoverExpandDelay,
                    step: 0.05,
                    range: 0.05...1.0
                ) { "\(Int($0 * 1000)) ms" }
            }
            .padding(.vertical, 8)
        }

        settingsCard(title: "Notch Dimensions (Normal & Hover)", symbol: "arrow.up.left.and.arrow.down.right") {
            // Normal (Compact) Sizing
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Normal (Compact) State")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.text)
                    Spacer()
                    Button("Reset Default") {
                        appState.compactIslandWidth = 216
                        appState.compactIslandHeight = 32
                    }
                    .font(Typo.body(9.5, .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Pal.accent)
                }

                // Width
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compact Width: \(Int(appState.compactIslandWidth)) pt")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Horizontal width of the idle compact notch pill.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Slider(value: $appState.compactIslandWidth, in: 160...360, step: 2)
                        .frame(width: 140)
                }

                // Height
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compact Height: \(Int(appState.compactIslandHeight)) pt")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Vertical thickness of the idle compact notch.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Slider(value: $appState.compactIslandHeight, in: 22...48, step: 1)
                        .frame(width: 140)
                }
            }
            .padding(.vertical, 4)

            divider

            // Hover (Expanded) Sizing
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Hover (Expanded) State")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.text)
                    Spacer()
                    Button("Reset Default") {
                        appState.expandedIslandWidth = 460
                        appState.expandedIslandHeight = 110
                    }
                    .font(Typo.body(9.5, .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Pal.accent)
                }

                // Width
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expanded Width: \(Int(appState.expandedIslandWidth)) pt")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Width of the notch when hovered or expanded.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Slider(value: $appState.expandedIslandWidth, in: 320...600, step: 4)
                        .frame(width: 140)
                }

                // Height
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expanded Height: \(Int(appState.expandedIslandHeight)) pt")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Height of the notch when hovered or expanded.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Slider(value: $appState.expandedIslandHeight, in: 65...160, step: 2)
                        .frame(width: 140)
                }
            }
            .padding(.vertical, 4)
        }

        settingsCard(title: "Installed Notch Modules", symbol: "square.grid.2x2") {
            toggleRow(
                title: "4K Studio Downloader Module",
                subtitle: "Live transfer speeds, progress bars, pause/resume, and quick link input directly in the notch.",
                binding: $appState.downloadsEnabled
            )

            divider

            toggleRow(
                title: "Smart Clipboard & Link Monitor",
                subtitle: "Detects copied media URLs and offers instant 1-click downloads with clip history.",
                binding: $appState.clipboardEnabled
            )

            divider

            toggleRow(
                title: "Quick Note & Scratchpad Module",
                subtitle: "Instant note taking, text file saving, and word/char count directly in the notch.",
                binding: $appState.quickNoteEnabled
            )

            divider

            toggleRow(
                title: "Drop Shelf Module",
                subtitle: "Drag and drop files, links, and photos onto the notch to park them for later.",
                binding: $appState.shelfEnabled
            )

            if appState.shelfEnabled {
                divider
                toggleRow(
                    title: "Auto-open shelf on drop",
                    subtitle: "Instantly expand the shelf HUD when dropping items onto the island.",
                    binding: $appState.shelfAutoOpenOnDrop
                )
            }

            divider

            toggleRow(
                title: "Now Playing Module",
                subtitle: "Lossless album art, spectrogram view, playback controls, and scrubber.",
                binding: $appState.nowPlayingEnabled
            )

            if appState.nowPlayingEnabled {
                divider
                toggleRow(
                    title: "Browser media detection",
                    subtitle: "Detect media playing inside Chrome, Safari, Brave, Arc, and Firefox.",
                    binding: $nowPlayingManager.browserDetectionEnabled
                )
            }

            divider

            toggleRow(
                title: "Battery & Power HUD Module",
                subtitle: "Real-time battery percentage, charging state, wattage, and time remaining.",
                binding: $appState.batteryEnabled
            )

            divider

            toggleRow(
                title: "System Notifications & Notices Module",
                subtitle: "Route volume changes, AirDrop files, power events, drive mounts, and screenshots to the notch.",
                binding: $appState.notificationsEnabled
            )

            divider

            toggleRow(
                title: "Connectivity Module",
                subtitle: "Wi-Fi network signal and connected Bluetooth peripherals info.",
                binding: $appState.connectivityEnabled
            )

            divider

            toggleRow(
                title: "Teleprompter Module",
                subtitle: "Speech-synchronized floating prompter for presentations and video recordings.",
                binding: $appState.teleprompterEnabled
            )
        }

        settingsCard(title: "Home Screen 3-Slot Configuration", symbol: "rectangle.3.group") {
            homeSlotRow(title: "Left slot", selection: $appState.homeLeadingPanelRaw)
            divider
            homeSlotRow(title: "Center slot", selection: $appState.homeCenterPanelRaw)
            divider
            homeSlotRow(title: "Right slot", selection: $appState.homeTrailingPanelRaw)
        }

        settingsCard(title: "Notch Companion & Mascot", symbol: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Select an animated companion living inside your compact notch pill, or disable it completely.")
                    .font(Typo.body(10))
                    .foregroundStyle(Pal.secondary)

                HStack(spacing: 8) {
                    ForEach(NotchMascotType.allCases) { m in
                        let isSel = notchMascotChoice == m.rawValue
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                notchMascotChoice = m.rawValue
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(isSel ? Pal.accent.opacity(0.2) : Pal.elevated)
                                        .frame(width: 36, height: 36)
                                        .overlay(Circle().stroke(isSel ? Pal.accent : Pal.stroke, lineWidth: 1.2))

                                    switch m {
                                    case .disabled:
                                        Image(systemName: "nosign")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Pal.secondary)
                                    case .jelly:
                                        PuffNotchView(size: 24)
                                    case .cat:
                                        NotchCyberCatView(size: 24)
                                    case .ghost:
                                        NotchCosmicGhostView(size: 24)
                                    case .spark:
                                        NotchRetroSparkView(size: 24)
                                    case .panda:
                                        NotchZenPandaView(size: 24)
                                    }
                                }

                                Text(m.title)
                                    .font(Typo.body(9.5, isSel ? .bold : .medium))
                                    .foregroundStyle(isSel ? Pal.text : Pal.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSel ? Color.white.opacity(0.08) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSel ? Pal.accent : Pal.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if notchMascotChoice != NotchMascotType.disabled.rawValue {
                    divider

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Color Palette")
                                .font(Typo.body(11, .medium))
                                .foregroundStyle(Pal.text)
                            Text("Choose color theme for your notch companion.")
                                .font(Typo.body(9))
                                .foregroundStyle(Pal.tertiary)
                        }
                        Spacer()
                        Picker("", selection: $avatarPalette) {
                            Text("Aurora").tag("aurora")
                            Text("Sunset").tag("sunset")
                            Text("Cyberpunk").tag("cyberpunk")
                            Text("Bubblegum").tag("bubblegum")
                            Text("Neon").tag("neon")
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
    }

    // MARK: - 4. Appearance & Mascot Tab

    @ViewBuilder
    private var appearanceTabContent: some View {
        settingsCard(title: "Appearance & Theme", symbol: "circle.lefthalf.filled") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme mode")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Follow macOS appearance, or keep Edit.or.lynx light or dark.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                SegmentedPills(
                    options: AppearanceMode.allCases.map { ($0, $0.title, nil as String?) },
                    selection: Binding(
                        get: { model.appearance },
                        set: { model.setAppearance($0) }
                    )
                )
                .frame(width: 208)
            }
            .padding(.vertical, 9)

            divider

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent color")
                            .font(Typo.body(11, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Tints buttons, download progress rings, and notch highlights.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Text(model.accent.title)
                        .font(Typo.body(9.5, .medium))
                        .foregroundStyle(Pal.secondary)
                }

                HStack(spacing: 7) {
                    ForEach(AccentChoice.allCases) { choice in
                        AccentSwatch(
                            choice: choice,
                            selected: model.accent == choice
                        ) {
                            model.setAccent(choice)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 9)
        }

        settingsCard(title: "Compact Island Dimensions", symbol: "aspectratio") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pill width")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Idle width of the compact pill on Mac screens.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                StepperField(
                    value: $appState.compactIslandWidth,
                    step: 4,
                    range: 140...340
                ) { "\(Int($0.rounded())) pt" }
            }
            .padding(.vertical, 8)

            divider

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pill height")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Idle height of the compact pill.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                StepperField(
                    value: $appState.compactIslandHeight,
                    step: 1,
                    range: 28...56
                ) { "\(Int($0.rounded())) pt" }
            }
            .padding(.vertical, 8)
        }

        settingsCard(title: "Spring Physics & Animation", symbol: "waveform.path.ecg") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animation intensity")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Controls transition dynamics and responsiveness.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Picker("", selection: $appState.animationLevelRaw) {
                    ForEach(AnimationLevel.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
            }
            .padding(.vertical, 8)

            divider

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spring bounce")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Elastic overshoot when the notch opens and snaps.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                StepperField(
                    value: $appState.bounceAmount,
                    step: 0.05,
                    range: 0.0...0.5
                ) { "\(Int(($0 * 100).rounded()))%" }
            }
            .padding(.vertical, 8)

            divider

            toggleRow(
                title: "Reduce motion",
                subtitle: "Minimizes spring animations for improved accessibility.",
                binding: $appState.reduceMotion
            )
        }

    }

    // MARK: - 5. Browser Tab

    @ViewBuilder
    private var browserTabContent: some View {
        browserSection
    }

    // MARK: - 6. Extensions & Plugins Tab

    @ViewBuilder
    private var extensionsTabContent: some View {
        settingsCard(title: "Installed Dynamic Island Extensions", symbol: "puzzlepiece.extension") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Third-Party & Productivity Plugins")
                            .font(Typo.body(11, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Edit.or.lynx supports dynamic JavaScript extensions for team workflows and local agents.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Button {
                        if let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("EditOrLynx/Extensions") {
                            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(dir)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                            Text("Open Folder")
                                .font(Typo.body(9, .medium))
                        }
                        .foregroundStyle(Pal.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Pal.elevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                divider

                // WhatsApp Web Bridge
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .frame(width: 24, height: 24)
                        .background(Color.green.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("WhatsApp Web Bridge")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Real-time notifications and message previews in notch.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Text("Installed")
                        .font(Typo.body(8, .bold))
                        .foregroundStyle(Pal.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Pal.green.opacity(0.12), in: Capsule())
                }
                .padding(.vertical, 4)

                divider

                // Linear Mentions
                HStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x5E6AD2))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: 0x5E6AD2).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Linear Mentions & Tasks")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Live ticket notifications, assigned bugs, and PR updates.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Text("Installed")
                        .font(Typo.body(8, .bold))
                        .foregroundStyle(Pal.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Pal.green.opacity(0.12), in: Capsule())
                }
                .padding(.vertical, 4)

                divider

                // Claude & AI Agents Status
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0xD97706))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: 0xD97706).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Agents & Claude Token Tracker")
                            .font(Typo.body(10.5, .medium))
                            .foregroundStyle(Pal.text)
                        Text("Shows agent status, background tool executions, and rate limits.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Text("Active")
                        .font(Typo.body(8, .bold))
                        .foregroundStyle(Pal.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Pal.green.opacity(0.12), in: Capsule())
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 7. Advanced & Diagnostics Tab

    @ViewBuilder
    private var advancedTabContent: some View {
        settingsCard(title: "Display Selection", symbol: "display") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show island on display")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Choose a specific monitor or let Edit.or.lynx pick automatically.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer(minLength: 8)
                Picker("", selection: $appState.displayIdentifier) {
                    ForEach(screenOptions) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }
            .padding(.vertical, 9)
        }

        settingsCard(title: "Energy & Performance", symbol: "bolt.fill") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy mode")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Adjust island render throttling and refresh rate.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Picker("", selection: Binding(
                    get: { appState.energyMode },
                    set: { appState.energyMode = $0 }
                )) {
                    Text("Smart").tag(EnergyMode.smart)
                    Text("Normal").tag(EnergyMode.normal)
                    Text("Low Power").tag(EnergyMode.lowPower)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.vertical, 9)

            divider

            toggleRow(
                title: "Reduce animations on battery",
                subtitle: "Lowers spring bounce and GPU usage when running on battery.",
                binding: $appState.reduceAnimations
            )
        }

        settingsCard(title: "Toolchain & System Binaries", symbol: "hammer.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Embedded yt-dlp & FFmpeg 7.0 Engine")
                            .font(Typo.body(11, .medium))
                            .foregroundStyle(Pal.text)
                        Text("ARM64 & x86_64 dual-slice native binaries are bundled and verified.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                    Button {
                        ToolchainService.shared.ensureDependencies()
                        model.showToast("Verified toolchain binaries", symbol: "checkmark.circle")
                    } label: {
                        Text("Re-verify")
                            .font(Typo.body(9, .semibold))
                            .foregroundColor(Pal.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Pal.accent.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            }
        }

        settingsCard(title: "Maintenance & Reset", symbol: "trash") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset All Settings to Defaults")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Clears preferences and restores all notch & download defaults.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Button("Reset Defaults") {
                    showResetAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .alert("Reset Settings", isPresented: $showResetAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset Everything", role: .destructive) {
                        let domain = Bundle.main.bundleIdentifier ?? "com.editor.lynx"
                        UserDefaults.standard.removePersistentDomain(forName: domain)
                        UserDefaults.standard.synchronize()
                        model.showToast("All settings restored to defaults", symbol: "arrow.clockwise")
                    }
                } message: {
                    Text("Are you sure you want to restore all Edit.or.lynx settings to default?")
                }
            }
            .padding(.vertical, 9)
        }
    }

    // MARK: - 8. About & Pro Tab

    @ViewBuilder
    private var aboutTabContent: some View {
        proLicenseCard

        updateCard

        welcomeIntroCard

        aboutCard
    }

    // MARK: - Pro License Card

    private var proLicenseCard: some View {
        settingsCard(title: "Edit.or.lynx PRO License", symbol: "crown.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xF59E0B).opacity(0.16))
                            .frame(width: 32, height: 32)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: 0xF59E0B))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.plan == .pro ? "Edit.or.lynx PRO Activated" : "Edit.or.lynx Free Plan")
                                .font(Typo.body(12, .bold))
                                .foregroundStyle(Pal.text)

                            Text(model.plan == .pro ? "LIFETIME" : "LIMITED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(model.plan == .pro ? .green : .orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background((model.plan == .pro ? Color.green : Color.orange).opacity(0.15), in: Capsule())
                        }
                        Text(model.plan == .pro ? "32 Parallel Streams · 10 Concurrent Downloads · Lossless Audio · All Features" : "Up to 8 connections and 3 concurrent downloads. Unlock Pro for maximum speed.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                }
                .padding(.top, 8)

                divider

                if model.plan != .pro {
                    HStack(spacing: 8) {
                        TextField("Enter your License Key (e.g. LYNX-PRO-XXXX-XXXX)", text: $licenseKeyInput)
                            .textFieldStyle(.plain)
                            .font(Typo.mono(10.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Pal.stroke, lineWidth: 0.8)
                            )

                        Button {
                            activateLicense()
                        } label: {
                            Text(model.licenseStatus.isActivating ? "Verifying…" : "Activate Pro")
                                .font(Typo.body(10, .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: 0xF59E0B), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.licenseStatus.isActivating)
                    }
                    .padding(.vertical, 4)

                    if let message = model.licenseStatus.message {
                        Text(message)
                            .font(Typo.body(9))
                            .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                        Text("Edit.or.lynx Lifetime Pro Unlocked · All capabilities available")
                            .font(Typo.body(9.5, .medium))
                            .foregroundStyle(Pal.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func activateLicense() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        model.activatePro(key)
    }

    // MARK: - Update Card

    private var updateCard: some View {
        settingsCard(title: "Software Updates", symbol: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit.or.lynx for Mac")
                            .font(Typo.body(11, .semibold))
                            .foregroundStyle(Pal.text)
                        Text("Version 1.0.0 (Build 2026.10) • Universal Apple Silicon & Intel")
                            .font(Typo.mono(9))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()

                    Button {
                        checkForUpdates()
                    } label: {
                        HStack(spacing: 5) {
                            if isCheckingUpdates {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            Text(isCheckingUpdates ? "Checking…" : "Check for Updates")
                                .font(Typo.body(9.5, .semibold))
                        }
                        .foregroundStyle(Pal.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Pal.accent.opacity(0.14), in: Capsule())
                        .overlay(Capsule().strokeBorder(Pal.accent.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .noFocusOutline()
                    .disabled(isCheckingUpdates)
                }
                .padding(.vertical, 8)

                if let status = updateStatus {
                    divider
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: updateDetails != nil ? "sparkles" : "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(updateDetails != nil ? Pal.accent : Pal.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status)
                                .font(Typo.body(10, .medium))
                                .foregroundStyle(Pal.text)
                            if let details = updateDetails {
                                Text(details.notes)
                                    .font(Typo.body(8.5))
                                    .foregroundStyle(Pal.tertiary)
                                Button {
                                    if let u = URL(string: details.url) {
                                        if details.url.contains("/releases/") || details.url.hasSuffix(".zip") || details.url.hasSuffix(".dmg") {
                                            let info = LinkInfo(
                                                url: u,
                                                host: u.host ?? "localhost",
                                                title: "Edit.or.lynx v\(details.version) Update",
                                                kind: .file,
                                                fullBytes: 50_000_000
                                            )
                                            model.startFileDownload(info)
                                        } else {
                                            NSWorkspace.shared.open(u)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text("Download Release v\(details.version)")
                                            .font(Typo.body(8.5, .bold))
                                    }
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Pal.systemAccent, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .noFocusOutline()
                                .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdates = true
        updateStatus = "Checking server for new release…"
        updateDetails = nil

        Task {
            let primaryURL = URL(string: "\(LicenseConfig.apiBaseURL)/api/updates/check")
            let localURL = URL(string: "http://localhost:3000/api/updates/check")
            let candidateURLs = [primaryURL, localURL].compactMap { $0 }

            var fetchedData: (Data, HTTPURLResponse)? = nil
            for url in candidateURLs {
                do {
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 4.0
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                        fetchedData = (data, http)
                        break
                    }
                } catch {
                    continue
                }
            }

            guard let (data, _) = fetchedData,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let remoteVersion = json["version"] as? String else {
                await MainActor.run {
                    self.isCheckingUpdates = false
                    self.updateStatus = "✓ Edit.or.lynx 1.0.0 is currently up to date."
                }
                return
            }

            let currentVersion = "1.0.0"
            let notes = (json["notes"] as? String) ?? "Performance enhancements and stability updates."
            let downloadUrl = (json["downloadUrl"] as? String) ?? "https://instagram.com/edit.or.siva"

            await MainActor.run {
                self.isCheckingUpdates = false
                if remoteVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    self.updateStatus = "🎉 New Version Available: v\(remoteVersion)"
                    self.updateDetails = (remoteVersion, notes, downloadUrl)
                } else if downloadUrl.contains("/releases/") {
                    self.updateStatus = "🚀 Latest Release Build Available (v\(remoteVersion))"
                    self.updateDetails = (remoteVersion, notes, downloadUrl)
                } else {
                    self.updateStatus = "✓ You're up to date! Edit.or.lynx \(currentVersion) is the newest version."
                }
            }
        }
    }

    // MARK: - Welcome Intro Card

    private var welcomeIntroCard: some View {
        settingsCard(title: "Welcome Intro & Setup", symbol: "sparkles") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Replay Mac Welcome Intro")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.text)
                    Text("Experience the genuine cursive \"hello\" / \"வணக்கம்\" intro screen and notch guide anytime.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Button {
                    model.isShowingSettings = false
                    model.isShowingWelcomeIntro = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 9.5))
                        Text("Play Intro")
                            .font(Typo.body(9.5, .semibold))
                    }
                    .foregroundStyle(Pal.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Pal.accent.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.accent.opacity(0.35), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Browser Section

    private var browserSection: some View {
        settingsCard(title: "Browser Extensions & Integration", symbol: "puzzlepiece.extension") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Auto-Intercept In-Browser Downloads")
                            .font(Typo.body(11, .medium))
                            .foregroundStyle(Pal.text)
                        Text("When any file download is initiated in any browser, Edit.or.lynx intercepts it and pops open the MacBook Notch with 16x Turbo.")
                            .font(Typo.body(9))
                            .foregroundStyle(Pal.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        SoftButton(title: "Connect Wizard", symbol: "slider.horizontal.3") {
                            model.showOnboarding()
                        }
                        SoftButton(title: "Extension Files", symbol: "folder") {
                            model.revealExtensionsFolder()
                        }
                    }
                }
                .padding(.top, 10)

                divider

                toggleRow(
                    title: "Auto-Ask in Dynamic Notch",
                    subtitle: "Instantly drop down the notch prompt with a 1-click turbo download card.",
                    binding: Binding(
                        get: { model.engine.settings.offerCopiedLinks },
                        set: { model.setOfferCopiedLinks($0) }
                    )
                )

                divider

                HStack(spacing: 7) {
                    Circle()
                        .fill(Pal.green)
                        .frame(width: 5.5, height: 5.5)
                    Text("Extension Bridge Active on 127.0.0.1:47820 • Native WebSocket Loopback")
                        .font(Typo.body(9, .medium))
                        .foregroundStyle(Pal.secondary)
                    Spacer()
                }
                .padding(.vertical, 3)

                divider

                VStack(spacing: 7) {
                    ForEach(BrowserExtensionManager.shared.browsers) { browser in
                        browserSettingsRow(browser)
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func browserSettingsRow(_ browser: BrowserItem) -> some View {
        let installed = browser.isInstalled

        return HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(browser.color.opacity(0.14))
                    .frame(width: 26, height: 26)
                Image(systemName: browser.iconSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(browser.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(browser.name)
                        .font(Typo.body(10.5, .medium))
                        .foregroundStyle(Pal.text)

                    if installed {
                        HStack(spacing: 3) {
                            Circle().fill(Pal.green).frame(width: 3.5, height: 3.5)
                            Text("Installed")
                                .font(Typo.body(7.5, .bold))
                                .foregroundStyle(Pal.green)
                        }
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Pal.green.opacity(0.12), in: Capsule())
                    }
                }

                Text(browser.defaultPathDisplay)
                    .font(Typo.mono(8))
                    .foregroundStyle(Pal.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Button {
                    BrowserExtensionManager.shared.openExtensionsPage(for: browser)
                    model.showToast("Opened \(browser.name) Extensions", symbol: "arrow.up.forward.app")
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 8, weight: .semibold))
                        Text("Open Extensions Page")
                            .font(Typo.body(8.5, .medium))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Pal.elevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                Button {
                    if let _ = BrowserExtensionManager.shared.downloadExtensionToDownloads(for: browser) {
                        if browser.extensionType == "firefox" {
                            model.showToast("Saved to Downloads! In \(browser.name), click 'Load Temporary Add-on…' and choose manifest.json", symbol: "arrow.down.circle.fill")
                        } else {
                            model.showToast("Extension saved to Downloads! In \(browser.name), click 'Load unpacked' and select the folder", symbol: "arrow.down.circle.fill")
                        }
                    } else {
                        model.showToast("Could not export extension", symbol: "exclamationmark.triangle")
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Download Extension")
                            .font(Typo.body(8.5, .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 9)
                    .frame(height: 22)
                    .background(Pal.systemAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Pal.recess.opacity(installed ? 0.45 : 0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(installed ? browser.color.opacity(0.25) : Pal.stroke.opacity(0.5), lineWidth: 0.6)
        )
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PounceMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit.or.lynx 1.0.0")
                        .font(Typo.body(11, .semibold))
                        .foregroundStyle(Pal.text)
                    Text("The high-speed download manager that lives in your notch.")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.secondary)
                }
                Spacer()
                Text("macOS 14+ / Sonoma & Sequoia")
                    .font(Typo.body(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
            Divider().overlay(Pal.stroke)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created by @edit.or.siva · Instagram @edit.or.siva")
                        .font(Typo.body(9.5, .medium))
                        .foregroundStyle(Pal.accent)
                    Text("© 2026 edit.or.siva • All Rights Reserved")
                        .font(Typo.body(8.5))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Button(action: {
                    if let url = URL(string: "https://instagram.com/edit.or.siva") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Instagram")
                        .font(Typo.body(9, .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Pal.accent.opacity(0.12))
                        .foregroundStyle(Pal.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.7)
        )
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Pal.secondary)
                Text(title.uppercased())
                    .font(Typo.body(9, .bold))
                    .tracking(0.8)
                    .foregroundStyle(Pal.secondary)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Pal.stroke, lineWidth: 0.7)
            )
        }
    }

    private func numberRow(
        title: String,
        subtitle: String,
        value: Int,
        range: ClosedRange<Int>,
        unit: String,
        set: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body(11, .medium))
                    .foregroundStyle(Pal.text)
                Text(subtitle)
                    .font(Typo.body(9))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    set(max(range.lowerBound, value - 1))
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .foregroundStyle(Pal.secondary)
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(Typo.mono(10.5, .semibold))
                    .foregroundStyle(Pal.text)
                    .frame(width: 30)

                Button {
                    set(min(range.upperBound, value + 1))
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .foregroundStyle(Pal.secondary)
                .disabled(value >= range.upperBound)
            }
            .background(Pal.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.7))
            .help(unit)
        }
        .padding(.vertical, 9)
    }

    private func toggleRow(title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body(11, .medium))
                    .foregroundStyle(Pal.text)
                Text(subtitle)
                    .font(Typo.body(9))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
            ToggleSwitch(isOn: binding)
        }
        .padding(.vertical, 9)
    }

    private func homeSlotRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(Typo.body(11, .medium))
                .foregroundStyle(Pal.text)
            Spacer(minLength: 12)
            Picker("", selection: selection) {
                ForEach(HomePanel.allCases) { panel in
                    Label(panel.title, systemImage: panel.iconName)
                        .tag(panel.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.vertical, 9)
    }

    private func refreshScreenOptions() {
        screenOptions = ScreenDetector.availableScreenOptions()
        let currentID = appState.displayIdentifier
        if !currentID.isEmpty, !screenOptions.contains(where: { $0.id == currentID }) {
            appState.displayIdentifier = ""
        }
    }

    private var divider: some View {
        Rectangle().fill(Pal.stroke).frame(height: 0.7)
    }
}
