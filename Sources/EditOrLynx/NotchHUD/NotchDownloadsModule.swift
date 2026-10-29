import SwiftUI

public struct NotchDownloadsModule: View {
    @EnvironmentObject var engine: DownloadEngine

    public var body: some View {
        VStack(spacing: 8) {
            let active = Array(engine.activeDownloads.values.filter { $0.state.isActive }.prefix(2))

            if active.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Text("No Active Downloads")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))

                    Button {
                        MainWindowController.shared.show()
                        NotchWindowController.shared.collapse()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "macwindow.on.rectangle")
                            Text("Open Downloader")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(active) { item in
                    downloadRow(item)
                }

                Button {
                    MainWindowController.shared.show()
                    NotchWindowController.shared.collapse()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow.on.rectangle")
                        Text("Open Full Dashboard")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func downloadRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.category.iconName)
                    .foregroundColor(item.category.color)
                    .font(.system(size: 12))

                Text(item.filename)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(Formatters.speed(item.speed))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.accentColor)

                Button {
                    if item.state == .downloading {
                        engine.pauseDownload(id: item.id)
                    } else {
                        engine.resumeDownload(id: item.id)
                    }
                } label: {
                    Image(systemName: item.state == .downloading ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: item.progress)
                .progressViewStyle(.linear)

            HStack {
                Text("\(Formatters.bytes(item.downloadedBytes)) / \(Formatters.bytes(item.totalBytes))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Text(Formatters.eta(item.etaSeconds))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}
