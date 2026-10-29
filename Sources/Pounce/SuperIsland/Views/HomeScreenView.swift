import SwiftUI
import EventKit
import PounceCore

struct HomeScreenView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        let panels = visiblePanels

        VStack(spacing: 0) {
            Group {
                switch panels.count {
                case 0:
                    HomeEmptyState(
                        icon: "square.grid.2x2",
                        title: "No home modules enabled",
                        subtitle: "Enable modules in Settings to show them here.",
                        fillsAvailableSpace: true
                    )
                case 3:
                    threePanelLayout
                default:
                    evenLayout(panels: panels)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var visiblePanels: [HomePanel] {
        appState.homePanels
    }

    private var threePanelLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(Array(visiblePanels.enumerated()), id: \.element.id) { index, panel in
                panelView(for: panel)
                    .frame(width: preferredWidth(for: panel), alignment: .topLeading)
                    .frame(maxWidth: panel == .downloads ? .infinity : nil, alignment: .topLeading)

                if index < visiblePanels.count - 1 {
                    homeDivider
                }
            }
        }
    }

    private func evenLayout(panels: [HomePanel]) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(Array(panels.enumerated()), id: \.element.id) { index, panel in
                panelView(for: panel)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                if index < panels.count - 1 {
                    homeDivider
                }
            }
        }
    }

    @ViewBuilder
    private func panelView(for panel: HomePanel) -> some View {
        switch panel {
        case .none:
            EmptyView()
        case .nowPlaying:
            HomeNowPlayingPanel()
        case .downloads:
            HomeDownloadsPanel()
        case .clipboard:
            HomeClipboardPanel()
        case .quickNote:
            QuickNoteView()
        }
    }

    private var homeDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func preferredWidth(for panel: HomePanel) -> CGFloat? {
        switch panel {
        case .nowPlaying:
            return 248
        case .none:
            return nil
        case .downloads:
            return 210
        case .clipboard, .quickNote:
            return 210
        }
    }
}

private struct HomeNowPlayingPanel: View {
    @ObservedObject private var manager = NowPlayingManager.shared
    @ObservedObject private var model = AppModel.shared ?? AppModel()

    var body: some View {
        ZStack {
            // Full-bleed Blurred Album Art Backdrop
            if let art = manager.albumArt, !manager.title.isEmpty {
                GeometryReader { geo in
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 20)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.35),
                                    Color.black.opacity(0.72)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            }

            VStack(alignment: .leading, spacing: 10) {
                // Top: Track Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.title.isEmpty ? "No Media Playing" : manager.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(manager.artist.isEmpty ? "Spotify & Apple Music Ready" : manager.artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                }

                // Middle: Album Art (left) + Transport Controls (right)
                HStack(spacing: 16) {
                    if let art = manager.albumArt {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.55), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.white.opacity(0.45))
                            )
                    }

                    // Transport controls centered vertically next to art
                    HStack(spacing: 12) {
                        Button {
                            manager.previousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)

                        Button {
                            manager.togglePlayPause()
                        } label: {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.18), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            manager.nextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // Bottom: Progress Scrub Bar & Time
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                                .frame(height: 3)

                            Capsule()
                                .fill(Color.white)
                                .frame(
                                    width: max(0, min(geo.size.width, geo.size.width * CGFloat(manager.progress))),
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text(manager.duration > 0 ? manager.formattedElapsedTime : "0:00")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))

                        Spacer()

                        Text(manager.duration > 0 ? manager.formattedDuration : "--:--")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}

private struct HomeDownloadsPanel: View {
    @ObservedObject private var model = AppModel.shared ?? AppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
            Button {
                AppState.shared.selectFullExpandedTab(.module(.builtIn(.downloads)))
            } label: {
                HStack(spacing: 4) {
                    Text("Studio Downloader")
                        .font(HomeTypography.panelTitleFont)
                        .foregroundStyle(HomeTypography.primaryText)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

                if model.engine.activeCount > 0 {
                    Text("\(model.engine.activeCount) active transfers · \(Fmt.speed(model.engine.totalSpeed))")
                        .font(HomeTypography.secondaryFont)
                        .foregroundStyle(Color(hex: 0xA78BFA))
                        .lineLimit(1)
                } else {
                    Text("16x Multi-threaded Engine Ready")
                        .font(HomeTypography.secondaryFont)
                        .foregroundStyle(HomeTypography.secondaryText)
                        .lineLimit(1)
                }
            }

            if let link = model.detectedLink {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detected: \(link.title)")
                        .font(HomeTypography.secondaryFont)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if link.kind == .video || link.host.contains("youtube") || link.host.contains("youtu.be") {
                            Button("🎬 Video") {
                                model.quickDownload(link)
                                model.dismissDetectedLink()
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0x2563EB), in: Capsule())

                            Button("🎵 Audio") {
                                model.downloadAudio(info: link, preferFlac: false)
                                model.dismissDetectedLink()
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0x059669), in: Capsule())

                            Button("💎 FLAC") {
                                model.downloadAudio(info: link, preferFlac: true)
                                model.dismissDetectedLink()
                            }
                            .font(.system(size: 9.5, weight: .heavy))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                        } else {
                            Button("⚡ Download") {
                                model.quickDownload(link)
                                model.dismissDetectedLink()
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Pal.accent, in: Capsule())

                            Button("💎 Lossless") {
                                model.downloadAudio(info: link, preferFlac: true)
                                model.dismissDetectedLink()
                            }
                            .font(.system(size: 9.5, weight: .bold))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            } else if let firstActive = model.engine.downloads.first(where: { $0.state == .downloading }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(firstActive.title)
                        .font(HomeTypography.secondaryFont)
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    ProgressView(value: max(0.02, min(1.0, firstActive.progress)))
                        .tint(.purple)
                    HStack {
                        Text("\(Int(firstActive.progress * 100))%")
                            .font(HomeTypography.metaFont)
                            .foregroundStyle(HomeTypography.secondaryText)
                        Spacer()
                        Text(Fmt.speed(firstActive.currentSpeed))
                            .font(HomeTypography.metaFont)
                            .foregroundStyle(Color(hex: 0xC4B5FD))
                    }
                }
            } else {
                HomeEmptyState(
                    icon: "arrow.down.circle",
                    title: "Ready to Download",
                    subtitle: "Copy any YouTube or file link to download."
                )
            }
        }
    }
}

private struct HomeClipboardPanel: View {
    @ObservedObject private var model = AppModel.shared ?? AppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    AppState.shared.selectFullExpandedTab(.module(.builtIn(.clipboard)))
                } label: {
                    HStack(spacing: 4) {
                        Text("Clipboard History")
                            .font(HomeTypography.panelTitleFont)
                            .foregroundStyle(HomeTypography.primaryText)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)

                Text("\(model.clipboard.count) clips saved")
                    .font(HomeTypography.secondaryFont)
                    .foregroundStyle(HomeTypography.secondaryText)
            }

            if let latest = model.clipboard.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(latest.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(HomeTypography.secondaryFont)
                        .foregroundStyle(HomeTypography.primaryText)
                        .lineLimit(2)

                    HStack {
                        Text(latest.sourceApp ?? "Copied")
                            .font(HomeTypography.metaFont)
                            .foregroundStyle(HomeTypography.tertiaryText)
                        Spacer()
                        Button("Copy") {
                            model.copyEntry(latest)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            } else {
                HomeEmptyState(
                    icon: "doc.on.clipboard",
                    title: "Clipboard Empty",
                    subtitle: "Copied snippets appear here."
                )
            }
        }
    }
}

private struct HomeEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var fillsAvailableSpace = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(HomeTypography.tertiaryText)
                .padding(.bottom, 2)

            Text(title)
                .font(HomeTypography.bodyTitleFont)
                .foregroundStyle(HomeTypography.primaryText.opacity(0.9))

            Text(subtitle)
                .font(HomeTypography.secondaryFont)
                .foregroundStyle(HomeTypography.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsAvailableSpace ? .infinity : nil,
            alignment: .center
        )
    }
}

private enum HomeTypography {
    static let heroFont = Font.system(size: 18, weight: .semibold)
    static let temperatureFont = Font.system(size: 24, weight: .semibold)
    static let panelTitleFont = Font.system(size: 15, weight: .semibold)
    static let bodyTitleFont = Font.system(size: 14, weight: .semibold)
    static let valueFont = Font.system(size: 14, weight: .semibold)
    static let secondaryFont = Font.system(size: 11, weight: .medium)
    static let badgeFont = Font.system(size: 10, weight: .semibold)
    static let metaFont = Font.system(size: 10, weight: .medium, design: .monospaced)

    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.36)
}
