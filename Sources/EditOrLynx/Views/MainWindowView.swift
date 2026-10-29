import SwiftUI

public enum FilterTab: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Downloading"
    case completed = "Completed"

    public var id: String { rawValue }
}

public struct MainWindowView: View {
    @EnvironmentObject var engine: DownloadEngine
    @State private var filter: FilterTab = .all
    @State private var showAddSheet: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                    Text("Edit.or.lynx")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.leading, 64)

                Spacer()

                // Filter Picker
                Picker("", selection: $filter) {
                    ForEach(FilterTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Spacer()

                // Add Download Button
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("Add URL")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)

                // Settings Button
                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.cardBg)

            Divider()
                .background(AppTheme.divider)

            // Downloads List
            let allItems = Array(engine.activeDownloads.values) + engine.completedDownloads
            let filteredItems = allItems.filter { item in
                switch filter {
                case .all: return true
                case .active: return item.state.isActive || item.state == .paused
                case .completed: return item.state == .completed
                }
            }

            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No Downloads Yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Copy any download link, Google Drive folder, or magnet link to begin.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            DownloadTaskRow(item: item)
                        }
                    }
                    .padding(16)
                }
            }

            Divider()
                .background(AppTheme.divider)

            // Bottom Status Bar
            HStack {
                let activeCount = engine.activeDownloads.values.filter { $0.state.isActive }.count
                let totalSpeed = engine.activeDownloads.values.reduce(0.0) { $0 + $1.speed }

                Text("\(activeCount) active task\(activeCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                if totalSpeed > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(Formatters.speed(totalSpeed))
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                }

                if !engine.completedDownloads.isEmpty {
                    Button("Clear Completed") {
                        engine.clearAllCompleted()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.leading, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.cardBg)
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(AppTheme.bg)
        .sheet(isPresented: $showAddSheet) {
            AddDownloadSheet(isPresented: $showAddSheet)
                .environmentObject(engine)
        }
    }
}
