import SwiftUI

public struct DownloadTaskRow: View {
    @EnvironmentObject var engine: DownloadEngine
    public let item: DownloadItem

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.category.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: item.category.iconName)
                    .font(.system(size: 15))
                    .foregroundColor(item.category.color)
            }

            // Info & Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.filename)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if item.state.isActive {
                        Text(Formatters.speed(item.speed))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                    } else {
                        Text(item.state.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.state == .completed ? AppTheme.success : AppTheme.textTertiary)
                    }
                }

                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(Formatters.bytes(item.downloadedBytes)) of \(Formatters.bytes(item.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    if item.state.isActive {
                        Text("ETA: \(Formatters.eta(item.etaSeconds))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let error = item.errorMessage {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.danger)
                            .lineLimit(1)
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 8) {
                if item.state == .downloading {
                    Button {
                        engine.pauseDownload(id: item.id)
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                } else if item.state == .paused || item.state == .failed {
                    Button {
                        engine.resumeDownload(id: item.id)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                if item.state == .completed {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.destinationURL])
                    } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        engine.cancelDownload(id: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.stroke, lineWidth: 1)
        )
    }
}
