import AppKit
import Foundation
import SwiftUI

// MARK: - Notch Root View (100% Stock Notch Design)

public struct NotchRootView: View {
    @ObservedObject var state = NotchState.shared
    @EnvironmentObject var engine: DownloadEngine
    let onHoverChange: (Bool) -> Void

    public init(onHoverChange: @escaping (Bool) -> Void = { _ in }) {
        self.onHoverChange = onHoverChange
    }

    public var body: some View {
        VStack(spacing: 8) {
            if !state.isExpanded {
                // Stock Compact Notch Pill
                NotchCompactPillView()
                    .environmentObject(engine)
                    .environmentObject(state)
            } else {
                // Expanded Island Card
                VStack(spacing: 0) {
                    Group {
                        switch state.mode {
                        case .compact, .music:
                            NotchMusicCardView()
                                .environmentObject(state)
                        case .hud:
                            NotchHUDCardView()
                                .environmentObject(engine)
                                .environmentObject(state)
                        case .offer:
                            NotchOfferCardView()
                                .environmentObject(engine)
                                .environmentObject(state)
                        case .shelf:
                            NotchShelfCardView()
                                .environmentObject(state)
                        case .clipboard:
                            NotchClipboardCardView()
                                .environmentObject(state)
                        case .notes:
                            NotchNotesCardView()
                                .environmentObject(state)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(
                    width: state.mode == .offer ? 480 : state.expandedWidth,
                    height: state.mode == .offer ? 180 : state.expandedHeight
                )
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.65), radius: 20, x: 0, y: 10)
                )

                // Stock 5-Icon Floating Dock Bar
                NotchFloatingDockBar()
                    .environmentObject(state)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: state.isExpanded)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: state.mode)
        .onHover { hovering in
            state.isHovered = hovering
            onHoverChange(hovering)
        }
    }
}

// MARK: - Stock Compact Notch Pill (Flush to top, orange dot, sparkle)

public struct NotchCompactPillView: View {
    @EnvironmentObject var engine: DownloadEngine
    @EnvironmentObject var state: NotchState

    private var activeDownload: DownloadItem? {
        engine.activeDownloads.values.first(where: { $0.state.isActive })
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Left: Orange Dot + App Name
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 1.0, green: 0.33, blue: 0.0)) // #FF5500
                    .frame(width: 7.5, height: 7.5)

                Text("Edit.or.lynx")
                    .font(.system(size: 12.5, weight: .bold, design: .default))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 14)

            Spacer()

            // Dynamic Center / Right indicators
            if let download = activeDownload {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(download.progress))
                            .stroke(Color(red: 0.0, green: 0.64, blue: 1.0), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 13, height: 13)

                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.0, green: 0.64, blue: 1.0))

                    Text(Formatters.speed(download.speed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            } else if state.isPlayingMusic {
                HStack(spacing: 2.5) {
                    ForEach(0..<4) { idx in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                            .frame(width: 2.5, height: 4 + 9 * state.spectrumHeights[idx % state.spectrumHeights.count])
                    }
                }
                .frame(height: 13)
            }

            Spacer()

            // Right: Sparkle Star Icon
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.trailing, 14)
        }
        .frame(width: state.compactWidth, height: state.compactHeight)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            state.toggleExpand()
        }
    }
}

// MARK: - Stock Floating Dock Bar (5 Icons: Waveform, Clipboard, Shelf, Settings, Open App)

public struct NotchFloatingDockBar: View {
    @EnvironmentObject var state: NotchState

    public var body: some View {
        HStack(spacing: 12) {
            // 1. Waveform / Music Button
            Button {
                state.selectMode(.music)
            } label: {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(state.mode == .music ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(state.mode == .music ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Now Playing Music")

            // 2. Clipboard Button
            Button {
                state.selectMode(.clipboard)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.mode == .clipboard ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(state.mode == .clipboard ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Clipboard History")

            // 3. Shelf Button
            Button {
                state.selectMode(.shelf)
            } label: {
                Image(systemName: "tray.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.mode == .shelf ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(state.mode == .shelf ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Shelf Drop Zone")

            // 4. Settings Button
            Button {
                SettingsWindowController.shared.show()
                state.toggleExpand()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Notch & App Settings")

            // 5. Open App Button
            Button {
                MainWindowController.shared.show()
                state.toggleExpand()
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Open Edit.or.lynx")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(red: 0.10, green: 0.11, blue: 0.12).opacity(0.94))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7))
                .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Stock Offering UI (Matching Lynx: Download [Quality], Download MP3, Download Clip)

public struct NotchOfferCardView: View {
    @EnvironmentObject var engine: DownloadEngine
    @EnvironmentObject var state: NotchState

    private var offer: LinkInfo? {
        state.detectedOffer
    }

    private var selectedQualityLabel: String {
        state.selectedQuality?.label ?? offer?.qualities.first?.label ?? "1080p"
    }

    public var body: some View {
        VStack(spacing: 12) {
            if let link = offer {
                // Top Row: Media Icon + Title + Host + Dismiss
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 0.13, green: 0.14, blue: 0.16))
                        Image(systemName: link.kind == .video ? "video.fill" : (link.kind == .audio ? "music.note" : "doc.fill"))
                            .font(.system(size: 18))
                            .foregroundStyle(Color(red: 1.0, green: 0.33, blue: 0.0))
                    }
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(link.title.isEmpty ? link.url.absoluteString : link.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(link.host)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.65))

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.4))

                            Text(link.durationText)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    Button {
                        state.dismissOffer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Not Now")
                }

                // Middle: Resolution Pills Bar
                if !link.qualities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(link.qualities) { q in
                                Button {
                                    state.selectedQuality = q
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(q.label)
                                            .font(.system(size: 11, weight: .bold))
                                        if q.bytes > 0 {
                                            Text(Formatters.bytes(q.bytes))
                                                .font(.system(size: 9.5))
                                                .foregroundStyle(Color.white.opacity(0.75))
                                        }
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(state.selectedQuality?.id == q.id ? Color(red: 1.0, green: 0.33, blue: 0.0) : Color.white.opacity(0.12))
                                    )
                                    .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Bottom Action Buttons
                HStack(spacing: 8) {
                    // Primary Action: Download [Quality]
                    Button {
                        triggerDownload(link: link, audioOnly: false)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 11, weight: .bold))
                            Text("Download \(selectedQualityLabel)")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.33, blue: 0.0)))
                    }
                    .buttonStyle(.plain)

                    // Secondary Action: Download MP3
                    Button {
                        triggerDownload(link: link, audioOnly: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Download MP3")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Toggle("Auto-Delete", isOn: $state.offerAutoDelete)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 1.0, green: 0.33, blue: 0.0))
                    Text("Copy any media link to download in 1 click")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }

    private func triggerDownload(link: LinkInfo, audioOnly: Bool) {
        _ = engine.startDownload(url: link.url, customFilename: link.title)
        state.dismissOffer()
        state.selectMode(.hud)
    }
}

// MARK: - Stock Now Playing Music Card

public struct NotchMusicCardView: View {
    @EnvironmentObject var state: NotchState

    public var body: some View {
        VStack(spacing: 14) {
            // Top Row: Album Art + Track / Artist
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.23, green: 0.24, blue: 0.25), Color(red: 0.12, green: 0.13, blue: 0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.6)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.nowPlayingTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(state.nowPlayingArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()
            }

            // Controls Row: Prev, Play/Pause, Next
            HStack(spacing: 24) {
                Button {
                    NotchNowPlayingService.shared.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button {
                    NotchNowPlayingService.shared.togglePlayPause()
                } label: {
                    Image(systemName: state.isPlayingMusic ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    NotchNowPlayingService.shared.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}

// MARK: - Stock Active Transfer HUD Card

public struct NotchHUDCardView: View {
    @EnvironmentObject var engine: DownloadEngine
    @EnvironmentObject var state: NotchState

    private var activeDownload: DownloadItem? {
        engine.activeDownloads.values.first(where: { $0.state.isActive })
    }

    public var body: some View {
        VStack(spacing: 12) {
            if let download = activeDownload {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(download.progress))
                            .stroke(Color(red: 0.0, green: 0.64, blue: 1.0), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(download.progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(download.filename)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(Formatters.speed(download.speed))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.0, green: 0.64, blue: 1.0))

                            Text("•")
                                .foregroundStyle(Color.white.opacity(0.3))

                            Text("\(Formatters.bytes(download.downloadedBytes)) / \(Formatters.bytes(download.totalBytes))")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    Button {
                        engine.pauseDownload(id: download.id)
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.0, green: 0.64, blue: 1.0))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text("No active transfers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }
}

// MARK: - Stock Shelf Card

public struct NotchShelfCardView: View {
    @EnvironmentObject var state: NotchState

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.white.opacity(0.5))

            Text("Shelf Drop Zone")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("Drag and drop files, images, or links here to hold them")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Stock Clipboard Card

public struct NotchClipboardCardView: View {
    @EnvironmentObject var state: NotchState

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.white.opacity(0.5))

            Text("Clipboard Tracker")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("Recent copied links and snippets are staged here automatically")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Stock Notes Card

public struct NotchNotesCardView: View {
    @EnvironmentObject var state: NotchState

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Notch Notes")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))

            TextEditor(text: $state.quickNotes)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
    }
}
