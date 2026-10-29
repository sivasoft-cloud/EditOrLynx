import SwiftUI
import AppKit
import PounceCore

struct DownloadExpandedView: View {
    @ObservedObject var appState = AppState.shared
    @State private var inputURL: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                    Text("4K Studio Downloader")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                if let model = AppModel.shared {
                    if model.engine.activeCount > 0 {
                        Text("\(model.engine.activeCount) active · \(Fmt.speed(model.engine.totalSpeed))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.purple.opacity(0.9))
                    }

                    Button {
                        model.openNotchMain?()
                    } label: {
                        Text("Open Manager")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Link Offer Card or Quick Input
            if let model = AppModel.shared, let link = model.detectedLink {
                detectedLinkOfferCard(link, model: model)
            } else {
                HStack(spacing: 6) {
                    TextField("Paste YouTube, Instagram, Audio, or Direct URL…", text: $inputURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .onSubmit {
                            submitURL()
                        }

                    Button {
                        submitURL()
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(inputURL.isEmpty ? Color.white.opacity(0.1) : Color.purple, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(inputURL.isEmpty)
                }
            }

            // Active Downloads List
            if let model = AppModel.shared, !model.engine.downloads.filter({ $0.state == .downloading || $0.state == .paused }).isEmpty {
                let activeList = model.engine.downloads.filter({ $0.state == .downloading || $0.state == .paused })
                VStack(spacing: 6) {
                    ForEach(activeList.prefix(3)) { item in
                        activeDownloadRow(item, model: model)
                    }
                }
            } else if AppModel.shared?.detectedLink == nil {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No active transfers")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func detectedLinkOfferCard(_ link: LinkInfo, model: AppModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header tag
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: link.host == "BitTorrent" ? "arrow.down.doc.fill" : (link.kind == .video ? "play.rectangle.fill" : (link.kind == .audio ? "waveform" : "arrow.down.circle.fill")))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: 0xC4B5FD))
                    Text(link.host == "BitTorrent" ? "BITTORRENT / MAGNET DETECTED" : (link.kind == .video ? "YOUTUBE / VIDEO DETECTED" : (link.kind == .audio ? "AUDIO STREAM DETECTED" : "DOWNLOAD LINK DETECTED")))
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: 0xE9D5FF))
                }
                Spacer()
                Button {
                    model.dismissDetectedLink()
                    appState.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            // Title & info
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(link.host)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    if link.fullBytes > 0 {
                        Text("•  \(Fmt.bytes(Double(link.fullBytes)))")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            // Buttons
            HStack(spacing: 6) {
                if link.host == "BitTorrent" || link.url.scheme == "magnet" {
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Download Torrent (16x Swarm)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x0A84FF), Color(hex: 0x6366F1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Download torrent directly with multi-peer acceleration")
                } else if link.kind == .video || link.host.contains("youtube") || link.host.contains("youtu.be") {
                    // Button 1: Download Video (MP4/Best)
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Video (4K/Best)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(hex: 0x2563EB), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Download full resolution MP4 video")

                    // Button 2: Download Audio (MP3)
                    Button {
                        model.downloadAudio(info: link, preferFlac: false)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 9, weight: .bold))
                            Text("Audio (MP3)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(hex: 0x059669), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Extract clean MP3 audio")

                    // Button 3: Download Lossless (FLAC)
                    Button {
                        model.downloadAudio(info: link, preferFlac: true)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .bold))
                            Text("Lossless (FLAC)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.43, green: 0.16, blue: 0.85), Color(red: 0.58, green: 0.2, blue: 0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Extract Studio Lossless bit-perfect FLAC")
                } else {
                    // Button 1: Download File (16x Turbo)
                    Button {
                        model.quickDownload(link)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Download (16x Turbo)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Pal.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    // Button 2: Lossless (FLAC)
                    Button {
                        model.downloadAudio(info: link, preferFlac: true)
                        model.dismissDetectedLink()
                        appState.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9, weight: .bold))
                            Text("Lossless (FLAC)")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(Color(hex: 0x38BDF8))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(hex: 0x0284C7).opacity(0.22), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(hex: 0x38BDF8).opacity(0.4), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Button 4: Quality Options
                Button {
                    model.presentOptions?(link)
                    model.dismissDetectedLink()
                    appState.dismiss()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Quality & Codec Options")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: 0x8B5CF6).opacity(0.35), lineWidth: 1)
        )
    }

    private func submitURL() {
        guard !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let model = AppModel.shared {
            model.beginLink(inputURL)
            inputURL = ""
        }
    }

    private func activeDownloadRow(_ item: DownloadItem, model: AppModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        if item.state == .downloading {
                            model.engine.pause(item.id)
                        } else {
                            model.engine.resume(item.id)
                        }
                    } label: {
                        Image(systemName: item.state == .downloading ? "pause.fill" : "play.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        model.remove(item)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                }
            }

            ProgressView(value: max(0.02, min(1.0, item.progress)))
                .tint(.purple)

            HStack {
                Text("\(Int(item.progress * 100))% of \(Fmt.bytes(Double(item.totalBytes)))")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.55))

                Spacer()

                if item.state == .downloading {
                    Text(Fmt.speed(item.currentSpeed))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.purple.opacity(0.9))
                } else {
                    Text("PAUSED")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color(hex: 0xF59E0B))
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}
