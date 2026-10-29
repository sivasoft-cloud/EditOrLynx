import SwiftUI
import AppKit

public enum SidebarCategory: String, CaseIterable, Identifiable {
    case home = "Home"
    case videos = "Videos"
    case music = "Music & Audio"
    case clips = "Clips"
    case files = "Files"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .videos: return "film.fill"
        case .music: return "music.note"
        case .clips: return "scissors"
        case .files: return "doc.fill"
        }
    }
}

public enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case downloading = "Downloading"
    case completed = "Completed"

    public var id: String { rawValue }
}

public struct MainWindowView: View {
    @EnvironmentObject var engine: DownloadEngine
    @State private var selectedCategory: SidebarCategory = .home
    @State private var statusFilter: StatusFilter = .all
    @State private var isGridView: Bool = false
    @State private var urlInput: String = ""
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var turboMode: Bool = true
    @State private var isDropTarget: Bool = false

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            sidebarView
                .frame(width: 230)
                .background(Color(nsColor: NSColor(white: 0.10, alpha: 1.0)))

            // Vertical Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // Right Main Content
            mainContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: NSColor(white: 0.07, alpha: 1.0)))
        }
        .frame(minWidth: 860, minHeight: 560)
        .sheet(isPresented: $showAddSheet) {
            AddDownloadSheet(isPresented: $showAddSheet)
                .environmentObject(engine)
        }
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inset spacing for window traffic lights
            Spacer().frame(height: 38)

            // App Branding Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.18, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.0, green: 0.64, blue: 1.0))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit.or.lynx")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Text("Edit.or.lynx Pro")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.2))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(red: 1.0, green: 0.75, blue: 0.2).opacity(0.15), in: Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Turbo Mode Card
            Button {
                turboMode.toggle()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(turboMode ? Color(red: 0.0, green: 0.64, blue: 1.0).opacity(0.2) : Color.white.opacity(0.06))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(turboMode ? Color(red: 0.0, green: 0.64, blue: 1.0) : Color.white.opacity(0.4))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Turbo Mode")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(turboMode ? "16x Segmented" : "Standard Speed")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }

                    Spacer()

                    Circle()
                        .fill(turboMode ? Color(red: 0.0, green: 0.64, blue: 1.0) : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(turboMode ? Color(red: 0.0, green: 0.64, blue: 1.0).opacity(0.08) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(turboMode ? Color(red: 0.0, green: 0.64, blue: 1.0).opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 20)

            // Library Section
            Text("LIBRARY")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(spacing: 2) {
                ForEach(SidebarCategory.allCases) { category in
                    sidebarRow(category: category)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Bottom Status & Settings
            VStack(spacing: 8) {
                // Engine Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                        .frame(width: 7, height: 7)
                    Text("Download engine active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Settings Button
                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 14)
        }
    }

    private func sidebarRow(category: SidebarCategory) -> some View {
        let isSelected = selectedCategory == category
        let count = categoryCount(category)

        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.64, blue: 1.0) : Color.white.opacity(0.6))
                    .frame(width: 20)

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : Color.white.opacity(0.8))

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? .white : Color.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBarView
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)

            // Filter Tabs
            HStack {
                HStack(spacing: 6) {
                    ForEach(StatusFilter.allCases) { filter in
                        statusFilterPill(filter: filter)
                    }
                }

                Spacer()

                // Total items count
                let items = filteredItems
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.06))

            // Content Area
            if filteredItems.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 14)], spacing: 14) {
                            ForEach(filteredItems) { item in
                                DownloadTaskRow(item: item)
                            }
                        }
                        .padding(20)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredItems) { item in
                                DownloadTaskRow(item: item)
                            }
                        }
                        .padding(20)
                    }
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            // Bottom Metric Bar
            bottomMetricBar
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(nsColor: NSColor(white: 0.08, alpha: 1.0)))
        }
        .onDrop(of: ["public.url", "public.file-url", "public.utf8-plain-text"], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Top Bar View
    private var topBarView: some View {
        HStack(spacing: 12) {
            // Universal Search & Download Pill Input
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))

                TextField("Paste a link to download it, or just the part you need", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white)
                    .onSubmit {
                        submitURL()
                    }

                if !urlInput.isEmpty {
                    Button {
                        submitURL()
                    } label: {
                        Text("Download")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.0, green: 0.64, blue: 1.0), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(nsColor: NSColor(white: 0.12, alpha: 1.0)))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            // Right Action Controls
            HStack(spacing: 6) {
                // View Mode Toggle
                Button {
                    isGridView.toggle()
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle List / Grid view")

                // Add Download URL Sheet
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color(red: 0.0, green: 0.64, blue: 1.0), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Add URL or Magnet")
            }
        }
    }

    private func statusFilterPill(filter: StatusFilter) -> some View {
        let isSelected = statusFilter == filter
        return Button {
            statusFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 72, height: 72)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color(red: 0.0, green: 0.64, blue: 1.0).opacity(0.8))
            }

            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Paste any download link, YouTube 4K stream, BitTorrent, or Google Drive folder above.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 12) {
                Button {
                    if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                        urlInput = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste from Clipboard")
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }

    private var emptyTitle: String {
        switch selectedCategory {
        case .home: return "Ready to Download"
        case .videos: return "No Videos"
        case .music: return "No Music & Audio"
        case .clips: return "No Trimmed Clips"
        case .files: return "No Files & Archives"
        }
    }

    // MARK: - Bottom Metric Bar
    private var bottomMetricBar: some View {
        HStack {
            let activeTasks = engine.activeDownloads.values.filter { $0.state.isActive }
            let totalSpeed = activeTasks.reduce(0.0) { $0 + $1.speed }

            Text("\(activeTasks.count) active transfer\(activeTasks.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))

            Spacer()

            if totalSpeed > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "speedometer")
                    Text(Formatters.speed(totalSpeed))
                }
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.0, green: 0.64, blue: 1.0))
            }

            if !engine.completedDownloads.isEmpty {
                Button("Clear Completed") {
                    engine.clearAllCompleted()
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
                .buttonStyle(.plain)
                .padding(.leading, 14)
            }
        }
    }

    // MARK: - Logic & Filtering
    private var allItems: [DownloadItem] {
        Array(engine.activeDownloads.values) + engine.completedDownloads
    }

    private func categoryCount(_ category: SidebarCategory) -> Int {
        allItems.filter { itemMatchesCategory($0, category: category) }.count
    }

    private var filteredItems: [DownloadItem] {
        allItems.filter { item in
            // Category check
            guard itemMatchesCategory(item, category: selectedCategory) else { return false }

            // Status check
            switch statusFilter {
            case .all: break
            case .downloading:
                guard item.state.isActive || item.state == .paused else { return false }
            case .completed:
                guard item.state == .completed else { return false }
            }

            // Search query check
            if !searchQuery.isEmpty {
                return item.filename.localizedCaseInsensitiveContains(searchQuery) ||
                       item.url.absoluteString.localizedCaseInsensitiveContains(searchQuery)
            }

            return true
        }
    }

    private func itemMatchesCategory(_ item: DownloadItem, category: SidebarCategory) -> Bool {
        switch category {
        case .home:
            return true
        case .videos:
            return item.category == .video
        case .music:
            return item.category == .audio
        case .clips:
            return item.filename.localizedCaseInsensitiveContains("clip") || item.filename.localizedCaseInsensitiveContains("trim")
        case .files:
            return item.category == .archive || item.category == .document || item.category == .app || item.category == .other
        }
    }

    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }
        _ = engine.startDownload(url: url)
        urlInput = ""
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        Task { @MainActor in
                            _ = self.engine.startDownload(url: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
