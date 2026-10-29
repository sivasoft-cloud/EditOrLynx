import SwiftUI
import AppKit

struct NowPlayingExpandedView: View {
    @ObservedObject private var manager = NowPlayingManager.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if manager.title.isEmpty {
                idleMusicLauncherView
            } else if appState.currentState == .fullExpanded {
                fullView
            } else {
                compactExpandedView
            }
        }
    }

    // MARK: - Idle State / Music Launcher

    private var idleMusicLauncherView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.11, green: 0.84, blue: 0.38), Color(red: 0.08, green: 0.62, blue: 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(red: 0.11, green: 0.84, blue: 0.38).opacity(0.35), radius: 8, y: 2)

                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Now Playing & Spotify")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("LOSSLESS")
                        .font(.system(size: 8, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Text("Play tracks on Spotify or Apple Music to control & rip bit-perfect FLAC.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Button {
                    openSpotify()
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.84, blue: 0.38))
                            .frame(width: 6, height: 6)
                        Text("Spotify")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    openMusic()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("Music")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Compact Expanded (360x80)

    private var compactExpandedView: some View {
        HStack(spacing: 12) {
            // Album art with glow
            AlbumArtView(image: manager.albumArt, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(manager.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    sourceBadge
                }

                Text(manager.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                // Progress bar
                ProgressBar(
                    progress: manager.progress,
                    trackHeight: 3,
                    knobSize: 8
                ) { newProgress in
                    manager.seek(to: manager.duration * newProgress)
                }

                // Timestamps
                HStack {
                    Text(manager.formattedElapsedTime)
                    Spacer()
                    Text(manager.formattedDuration)
                }
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
            }

            // Direct playing music controls in the expanded notch
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    // Previous Track Button
                    Button {
                        manager.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .hoverPointer()
                    .help("Previous Track")

                    // Play/Pause Button
                    Button {
                        manager.togglePlayPause()
                    } label: {
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Pal.accent, in: Circle())
                            .shadow(color: Pal.accent.opacity(0.4), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                    .hoverPointer()
                    .help(manager.isPlaying ? "Pause" : "Play")

                    // Next Track Button
                    Button {
                        manager.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .hoverPointer()
                    .help("Next Track")
                }

                // Download Lossless FLAC Button
                Button {
                    downloadCurrentLossless()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 8, weight: .bold))
                        Text("FLAC")
                            .font(.system(size: 8, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .hoverPointer()
                .help("Download Studio Lossless FLAC")
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Full Expanded

    private var fullView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                AlbumArtView(image: manager.albumArt, size: 52)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        sourceBadge
                        losslessBadge
                    }

                    Text(manager.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(manager.artist)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)

                    if !manager.album.isEmpty {
                        Text(manager.album)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 5) {
                    Button {
                        downloadCurrentLossless()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8, weight: .bold))
                            Text("FLAC")
                                .font(.system(size: 8.5, weight: .heavy))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Download track in bit-perfect Studio Lossless FLAC")

                    Button {
                        if isSpotify {
                            openSpotify()
                        } else {
                            openMusic()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 8))
                            Text(isSpotify ? "Spotify" : "Music")
                                .font(.system(size: 8.5, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Progress bar with times
            VStack(spacing: 2) {
                ProgressBar(
                    progress: manager.progress,
                    trackHeight: 3,
                    knobSize: 8
                ) { newProgress in
                    manager.seek(to: manager.duration * newProgress)
                }

                HStack {
                    Text(manager.formattedElapsedTime)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text(manager.formattedDuration)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
            }

            // Compact Playback controls
            HStack(spacing: 16) {
                Button {
                    manager.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    manager.togglePlayPause()
                } label: {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Pal.accent, in: Circle())
                        .shadow(color: Pal.accent.opacity(0.4), radius: 4, y: 1)
                }
                .buttonStyle(.plain)

                Button {
                    manager.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Badges

    private var isSpotify: Bool {
        manager.sourceName.localizedCaseInsensitiveContains("spotify")
    }

    private var sourceBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isSpotify ? Color(red: 0.11, green: 0.84, blue: 0.38) : Pal.accent)
                .frame(width: 5, height: 5)

            Text(isSpotify ? "SPOTIFY" : (manager.sourceName.isEmpty ? "MUSIC" : manager.sourceName.uppercased()))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private var losslessBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "waveform")
                .font(.system(size: 7, weight: .bold))
            Text("LOSSLESS FLAC")
                .font(.system(size: 8, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            LinearGradient(
                colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func downloadCurrentLossless() {
        guard !manager.title.isEmpty else { return }
        AppModel.shared?.downloadCurrentlyPlayingLossless(
            title: manager.title,
            artist: manager.artist,
            album: manager.album
        )
    }

    private func openSpotify() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(URL(string: "spotify:")!)
        }
    }

    private func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(URL(string: "music:")!)
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double
    var trackHeight: CGFloat = 4
    var knobSize: CGFloat = 10
    var onSeek: ((Double) -> Void)? = nil

    @State private var dragProgress: Double?
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            let displayedProgress = min(max(dragProgress ?? progress, 0), 1)
            let knobCenterX = min(
                max(CGFloat(displayedProgress) * geometry.size.width, knobSize / 2),
                max(knobSize / 2, geometry.size.width - (knobSize / 2))
            )
            let knobVisible = onSeek != nil && (isHovering || dragProgress != nil)
            let knobScale = (isHovering || dragProgress != nil) ? 1.08 : 1

            ZStack {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: trackHeight)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: [Pal.accent, Pal.accent.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * CGFloat(displayedProgress)), height: trackHeight)
                        .animation(Constants.progressBar, value: displayedProgress)

                    Circle()
                        .fill(.white)
                        .frame(width: knobSize, height: knobSize)
                        .scaleEffect(knobScale)
                        .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                        .offset(x: knobCenterX - (knobSize / 2))
                        .opacity(knobVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.14), value: knobVisible)
                        .animation(.easeOut(duration: 0.14), value: knobScale)
                }
                .frame(height: knobSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard onSeek != nil, geometry.size.width > 0 else { return }
                        let nextProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = nextProgress
                    }
                    .onEnded { value in
                        guard let onSeek, geometry.size.width > 0 else { return }
                        let nextProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                        dragProgress = nil
                        onSeek(nextProgress)
                    }
            )
        }
        .frame(height: max(knobSize, 16))
    }
}
