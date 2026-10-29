import SwiftUI
import PounceCore

struct DownloadCompactView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack(spacing: 6) {
            if let model = AppModel.shared, let link = model.detectedLink {
                Image(systemName: link.kind == .video ? "play.rectangle.fill" : (link.kind == .audio ? "waveform" : "arrow.down.circle.fill"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Pal.accent)

                Text(link.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: appState.usesWideCompactLayout ? 90 : 60, alignment: .leading)

                if link.host == "BitTorrent" || link.url.scheme == "magnet" {
                    // Torrent download button
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Torrent")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x0A84FF), Color(hex: 0x6366F1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download Torrent with 16x Swarm")
                } else if link.kind == .video || link.host.contains("youtube") || link.host.contains("youtu.be") {
                    // Video download button
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "video.fill")
                            Text("Video")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0x0A84FF), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download 4K / Best Video")

                    // Audio download button
                    Button {
                        model.downloadAudio(info: link, preferFlac: false)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "music.note")
                            Text("Audio")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0x059669), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download Audio (MP3/M4A)")

                    // Lossless format button
                    Button {
                        model.downloadAudio(info: link, preferFlac: true)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform")
                            Text("FLAC")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x0A84FF), Color(hex: 0x38BDF8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download Studio Lossless FLAC")
                } else {
                    // Generic file download buttons
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                            Text("Download")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Pal.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download File (16x Turbo)")

                    Button {
                        model.downloadAudio(info: link, preferFlac: true)
                        model.dismissDetectedLink()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform")
                            Text("FLAC")
                                .lineLimit(1)
                        }
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("Download Lossless FLAC")
                }

                // Dismiss button
                Button {
                    model.dismissDetectedLink()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help("Dismiss link")
            } else if let model = AppModel.shared, model.engine.activeCount > 0 {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Pal.accent)

                let count = model.engine.activeCount
                let speed = Fmt.speed(model.engine.totalSpeed)
                Text("\(count) downloading · \(speed)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Pal.accent)

                Text("Downloader Ready")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
}
