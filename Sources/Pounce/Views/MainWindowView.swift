import SwiftUI
import PounceCore

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @AppStorage("dismissedWelcomeBanner") private var dismissedWelcomeBanner = false
    @State private var hoveredHeaderButton: String? = nil

    private var todayItems: [DownloadItem] {
        let items = model.filteredCompleted
        let cal = Calendar.current
        return items.filter { cal.isDateInToday($0.completedAt ?? $0.addedAt) }
    }

    private var previousItems: [DownloadItem] {
        let items = model.filteredCompleted
        let cal = Calendar.current
        return items.filter { !cal.isDateInToday($0.completedAt ?? $0.addedAt) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (Left)
            SidebarView(model: model)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Pal.stroke).frame(width: 1)
                }

            // Main Content Area & Detail Panel
            VStack(spacing: 0) {
                // Top Toolbar / Header Area: Centered Search Bar & Trailing Buttons
                topToolbar
                Divider().overlay(Pal.stroke)

                HStack(spacing: 0) {
                    if model.isShowingSettings {
                        inAppSettingsView
                            .transition(.opacity)
                    } else if model.isShowingProView {
                        inAppProView
                            .transition(.opacity)
                    } else {
                        // Main Content (Center)
                        centerContent

                        // Detail Panel (Right)
                        if let item = model.selectedDownload {
                            DownloadDetailView(item: item, model: model)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
            .background(Pal.bg)
        }
        .frame(minWidth: 860, minHeight: 520)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { toastOverlay }
        .overlay {
            if model.isShowingWelcomeIntro {
                ZStack {
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                    MacOSWelcomeIntroView(model: model) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            model.isShowingWelcomeIntro = false
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        }
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            } else if let notice = model.completedNotice {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { model.dismissCompletedNotice() }
                    CompletionOverlay(model: model, item: notice)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            } else if let info = model.activeOptionsLink {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { model.activeOptionsLink = nil }

                    if info.kind == .playlist {
                        PlaylistOptionsView(
                            model: model,
                            info: info,
                            onClose: { model.activeOptionsLink = nil }
                        )
                        .frame(maxWidth: 640, maxHeight: 600)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else {
                        DownloadOptionsView(
                            model: model,
                            info: info,
                            onClose: { model.activeOptionsLink = nil },
                            onClip: {
                                model.activeOptionsLink = nil
                                model.activeClipLink = info
                            }
                        )
                        .frame(maxWidth: 640, maxHeight: 580)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }
                }
            } else if let clipInfo = model.activeClipLink {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { model.activeClipLink = nil }

                    ClipEditorView(
                        model: model,
                        info: clipInfo,
                        onClose: { model.activeClipLink = nil }
                    )
                    .frame(maxWidth: 820, maxHeight: 720)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            } else if let folderURL = model.activeGoogleDriveFolderURL {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { model.activeGoogleDriveFolderURL = nil }

                    GoogleDriveFolderView(
                        model: model,
                        folderURL: folderURL,
                        onClose: { model.activeGoogleDriveFolderURL = nil }
                    )
                    .frame(maxWidth: 640, maxHeight: 640)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.selectedDownloadID)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.completedNotice?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.activeOptionsLink?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.activeClipLink?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.activeGoogleDriveFolderURL != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.isShowingProView)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.isShowingSettings)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.isShowingWelcomeIntro)
        .onExitCommand {
            if model.isShowingWelcomeIntro {
                model.isShowingWelcomeIntro = false
            } else if model.isShowingProView {
                model.isShowingProView = false
            } else if model.isShowingSettings {
                model.isShowingSettings = false
            } else if model.activeOptionsLink != nil {
                model.activeOptionsLink = nil
            } else if model.activeClipLink != nil {
                model.activeClipLink = nil
            } else if model.activeGoogleDriveFolderURL != nil {
                model.activeGoogleDriveFolderURL = nil
            } else {
                model.selectedDownloadID = nil
            }
        }
    }

    // MARK: - Top Toolbar / Header Area
    // Requirements: Centered, minimalist search bar.
    // On the top-right trailing edge: 3 buttons: "+ Paste Link", "Notch", and "Settings" gear icon.

    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Left spacer for window controls spacing
            Spacer()
                .frame(width: 80)

            Spacer()

            // Centered Minimalist Searchable Bar
            centeredSearchBar

            Spacer()

            // Trailing Edge: 3 Buttons (+ Paste Link, Notch, Settings)
            trailingActionButtons
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(.ultraThinMaterial)
    }

    private var centeredSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(searchFocused ? Pal.text : Pal.tertiary)

            TextField("Search downloads, paste URL, or filter…", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(Typo.body(12, .medium))
                .foregroundStyle(Pal.text)
                .focused($searchFocused)
                .onSubmit {
                    if LinkInspector.inspect(model.searchText) != nil {
                        let link = model.searchText
                        model.searchText = ""
                        model.beginLink(link)
                    }
                }

            if !model.searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        model.searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Pal.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘F")
                    .font(Typo.mono(9, .medium))
                    .foregroundStyle(Pal.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 380, height: 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Pal.recess.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    searchFocused ? Color.white.opacity(0.24) : Pal.stroke,
                    lineWidth: searchFocused ? 1.0 : 0.7
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: searchFocused)
    }

    private var trailingActionButtons: some View {
        HStack(spacing: 8) {
            // Button 0: + Torrent
            let torrentHovered = hoveredHeaderButton == "torrent"
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Torrent")
                    .font(Typo.body(11, .semibold))
            }
            .foregroundStyle(Pal.text)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                torrentHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(torrentHovered ? Pal.accent.opacity(0.6) : Pal.stroke, lineWidth: 0.8))
            .scaleEffect(torrentHovered ? 1.02 : 1.0)
            .contentShape(Capsule())
            .noFocusOutline()
            .onTapGesture {
                model.openTorrentPicker()
            }
            .onHover { hoveredHeaderButton = $0 ? "torrent" : nil }
            .help("Open .torrent file or download magnet link")
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: torrentHovered)

            // Button 1: + Paste Link
            let pasteHovered = hoveredHeaderButton == "paste"
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("Paste Link")
                    .font(Typo.body(11, .semibold))
            }
            .foregroundStyle(Pal.text)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                pasteHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.8))
            .scaleEffect(pasteHovered ? 1.02 : 1.0)
            .contentShape(Capsule())
            .noFocusOutline()
            .onTapGesture {
                if let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.beginLink(text)
                } else if let image = NSImage(pasteboard: .general) {
                    model.saveClipboardImage(image)
                } else {
                    model.showToast("Copy a link or image first", symbol: "doc.on.clipboard")
                }
            }
            .onHover { hoveredHeaderButton = $0 ? "paste" : nil }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pasteHovered)

            // Button 2: Notch
            let notchHovered = hoveredHeaderButton == "notch"
            HStack(spacing: 5) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.system(size: 10, weight: .semibold))
                Text("Notch")
                    .font(Typo.body(11, .semibold))
            }
            .foregroundStyle(Pal.text)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                notchHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.8))
            .scaleEffect(notchHovered ? 1.02 : 1.0)
            .contentShape(Capsule())
            .noFocusOutline()
            .onTapGesture {
                model.openNotch?(model.notchTab)
            }
            .onHover { hoveredHeaderButton = $0 ? "notch" : nil }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: notchHovered)

            // Button 3: Settings Gear Icon
            let settingsHovered = hoveredHeaderButton == "settings"
            let settingsActive = model.isShowingSettings
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    model.isShowingSettings.toggle()
                }
            } label: {
                Image(systemName: settingsActive ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsActive ? Pal.text : (settingsHovered ? Pal.text : Pal.secondary))
                    .frame(width: 28, height: 28)
                    .background(
                        settingsActive ? Color.white.opacity(0.16) : (settingsHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)),
                        in: Circle()
                    )
                    .overlay(Circle().strokeBorder(settingsActive ? Pal.strokeStrong : Pal.stroke, lineWidth: 0.8))
                    .scaleEffect(settingsHovered ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .noFocusOutline()
            .onHover { hoveredHeaderButton = $0 ? "settings" : nil }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: settingsHovered)
        }
    }

    private var inAppSettingsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingSettings = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Downloads")
                            .font(Typo.body(11.5, .semibold))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background(Pal.elevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                Text("Settings")
                    .font(Typo.body(13, .bold))
                    .foregroundStyle(Pal.text)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingSettings = false
                    }
                } label: {
                    Text("Done")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.accent)
                        .padding(.horizontal, 13)
                        .frame(height: 26)
                        .background(Pal.accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Pal.accent.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider().overlay(Pal.stroke)

            DownloadManagerSettingsView(model: model)
        }
        .background(Pal.bg)
    }

    private var inAppProView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingProView = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Downloads")
                            .font(Typo.body(11.5, .semibold))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background(Pal.elevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                HStack(spacing: 6) {
                    Text("Edit.or.lynx Pro")
                        .font(Typo.body(13, .bold))
                        .foregroundStyle(Pal.text)

                    if model.plan == .pro {
                        Text("PRO")
                            .font(Typo.mono(8.5, .bold))
                            .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.18), in: Capsule())
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingProView = false
                    }
                } label: {
                    Text("Done")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.accent)
                        .padding(.horizontal, 13)
                        .frame(height: 26)
                        .background(Pal.accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Pal.accent.opacity(0.3), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider().overlay(Pal.stroke)

            ProView(model: model) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    model.isShowingProView = false
                }
            }
        }
        .background(Pal.bg)
    }

    // MARK: - Center Content
    // Requirements:
    // 1. Welcome banner card using .ultraThinMaterial
    // 2. "Today" list displaying download items (e.g. MP4, 4K 60fps files)
    // 3. Status tags, smooth linear progress bar, inline hover icons, subtle 1.02 scale hover

    private var centerContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Welcome Banner Card (.ultraThinMaterial)
                if !dismissedWelcomeBanner {
                    welcomeBannerCard
                }

                // In Progress Downloads
                if !model.engine.activeDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("ACTIVE TRANSFERS")
                                .font(Typo.body(9.5, .bold))
                                .tracking(1.0)
                                .foregroundStyle(Pal.tertiary)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    model.clearAllTasks()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 9.5, weight: .semibold))
                                    Text("Clear All Tasks")
                                        .font(Typo.body(10, .semibold))
                                }
                                .foregroundStyle(Color(hex: 0xF87171))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF87171).opacity(0.1), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color(hex: 0xF87171).opacity(0.3), lineWidth: 0.6))
                            }
                            .buttonStyle(.plain)
                            .noFocusOutline()
                            .help("Cancel and remove all active and queued download tasks")

                            Button("Pause All") { model.pauseAll() }
                                .font(Typo.body(10.5, .medium))
                                .foregroundStyle(Pal.secondary)
                                .buttonStyle(.plain)
                                .noFocusOutline()
                        }

                        VStack(spacing: 6) {
                            ForEach(model.engine.activeDownloads) { item in
                                DownloadRow(
                                    item: item,
                                    isSelected: model.selectedDownloadID == item.id,
                                    model: model
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        model.selectedDownloadID = (model.selectedDownloadID == item.id ? nil : item.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // "Today" Downloads List
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("TODAY")
                            .font(Typo.body(9.5, .bold))
                            .tracking(1.0)
                            .foregroundStyle(Pal.tertiary)

                        Spacer()

                        if !todayItems.isEmpty || !previousItems.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    model.clearAll()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9.5))
                                    Text("Clear All")
                                        .font(Typo.body(10, .semibold))
                                }
                                .foregroundStyle(Pal.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.6))
                            }
                            .buttonStyle(.plain)
                            .noFocusOutline()
                            .help("Clear all completed and inactive downloads")
                        }

                        if !todayItems.isEmpty {
                            Text("\(todayItems.count) items")
                                .font(Typo.body(10.5))
                                .foregroundStyle(Pal.tertiary)
                        }
                    }

                    if todayItems.isEmpty && model.engine.activeDownloads.isEmpty {
                        emptyStateToday
                    } else {
                        VStack(spacing: 6) {
                            ForEach(todayItems) { item in
                                DownloadRow(
                                    item: item,
                                    isSelected: model.selectedDownloadID == item.id,
                                    model: model
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        model.selectedDownloadID = (model.selectedDownloadID == item.id ? nil : item.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // Previous Downloads
                if !previousItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("PREVIOUS")
                                .font(Typo.body(9.5, .bold))
                                .tracking(1.0)
                                .foregroundStyle(Pal.tertiary)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    model.clearAll()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9.5))
                                    Text("Clear All")
                                        .font(Typo.body(10, .semibold))
                                }
                                .foregroundStyle(Pal.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.6))
                            }
                            .buttonStyle(.plain)
                            .noFocusOutline()
                            .help("Clear all completed and inactive downloads")
                        }

                        VStack(spacing: 6) {
                            ForEach(previousItems) { item in
                                DownloadRow(
                                    item: item,
                                    isSelected: model.selectedDownloadID == item.id,
                                    model: model
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        model.selectedDownloadID = (model.selectedDownloadID == item.id ? nil : item.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Welcome Banner Card (.ultraThinMaterial)

    private var welcomeBannerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
            }

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 6) {
                    Text("Welcome to Edit.or.lynx")
                        .font(Typo.body(13, .bold))
                        .foregroundStyle(Pal.text)

                    Text("STUDIO PRO")
                        .font(Typo.mono(8.5, .bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.18), in: Capsule())
                }

                Text("Professional media asset & 4K video downloader for macOS.")
                    .font(Typo.body(10.5))
                    .foregroundStyle(Pal.secondary)

                HStack(spacing: 4) {
                    Text("Made by edit.or.siva")
                        .font(Typo.body(10, .medium))
                        .foregroundStyle(Pal.tertiary)
                    Text("•")
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                    Button {
                        if let url = URL(string: "https://instagram.com/edit.or.siva") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Instagram @edit.or.siva")
                            .font(Typo.body(10, .semibold))
                            .foregroundStyle(Pal.text)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dismissedWelcomeBanner = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Pal.tertiary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
    }

    private var emptyStateToday: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Pal.tertiary)
                .padding(.top, 24)

            Text("No downloads yet today")
                .font(Typo.body(13, .semibold))
                .foregroundStyle(Pal.text)

            Text("Paste a video link or copy any media URL to start downloading in 4K 60fps.")
                .font(Typo.body(11))
                .foregroundStyle(Pal.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = model.toast {
            HStack(spacing: 9) {
                Image(systemName: toast.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Pal.systemAccent)

                Text(toast.text)
                    .font(Typo.body(11.5, .medium))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
            .shadow(color: Color.black.opacity(0.4), radius: 16, y: 5)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.toast)
        }
    }
}
