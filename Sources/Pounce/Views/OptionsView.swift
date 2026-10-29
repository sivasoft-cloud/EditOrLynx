import SwiftUI
import PounceCore

struct PanelChrome<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .background(Color(hex: 0x0D0D12).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.55), radius: 32, y: 16)
            .noFocusOutline()
    }
}

struct OptionsHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var seed: Int
    var kind: DownloadKind
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FilmThumb(seed: seed, kind: kind, size: 56, corner: 10, showBadge: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow.uppercased())
                    .font(Typo.body(8, .bold))
                    .tracking(0.9)
                    .foregroundStyle(Pal.accent)
                Text(title)
                    .font(Typo.display(16, .semibold))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Typo.body(9.5))
                    .foregroundStyle(Pal.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            CircleIconButton(symbol: "xmark", size: 26, help: "Close", action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

struct DownloadOptionsView: View {
    @ObservedObject var model: AppModel
    let info: LinkInfo
    let onClose: () -> Void
    let onClip: () -> Void

    enum MediaOptionMode: String, CaseIterable, Identifiable {
        case video = "video"
        case flac = "flac"
        case audio = "audio"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .video: return "Video (MP4)"
            case .flac: return "Studio Master (Lossless)"
            case .audio: return "Standard Audio (M4A)"
            }
        }

        var symbol: String {
            switch self {
            case .video: return "film"
            case .flac: return "sparkles"
            case .audio: return "waveform"
            }
        }
    }

    @State private var formatMode: MediaOptionMode
    @State private var selectedQuality: String
    @State private var subtitles = false

    init(model: AppModel, info: LinkInfo, onClose: @escaping () -> Void, onClip: @escaping () -> Void) {
        self.model = model
        self.info = info
        self.onClose = onClose
        self.onClip = onClip
        _formatMode = State(initialValue: info.kind == .audio ? .flac : .video)
        let initialQuality: String = {
            if model.plan == .pro {
                return info.qualities.first(where: { $0.recommended })?.label ?? info.qualities.first?.label ?? "1080p"
            } else {
                return info.qualities.first(where: { PlanPolicy.allows(height: PlanPolicy.height(ofQuality: $0.label), plan: model.plan) })?.label ?? "1080p"
            }
        }()
        _selectedQuality = State(initialValue: initialQuality)
    }

    private var quality: QualityOption? {
        info.qualities.first { $0.label == selectedQuality } ?? info.qualities.first
    }

    private var estimatedBytes: Int64 {
        switch formatMode {
        case .flac:
            return 36_000_000
        case .audio:
            return max(5_000_000, Int64(Double(info.fullBytes) * 0.08))
        case .video:
            return quality?.bytes ?? info.fullBytes
        }
    }

    var body: some View {
        PanelChrome {
            VStack(spacing: 0) {
                OptionsHeader(
                    eyebrow: "Download Quality & Format",
                    title: info.title,
                    subtitle: subtitle,
                    seed: info.thumbSeed,
                    kind: formatMode == .video ? .video : .audio,
                    onClose: onClose
                )

                Rectangle().fill(Pal.stroke).frame(height: 0.8)

                VStack(alignment: .leading, spacing: 14) {
                    modeRow

                    // Segmented Format Mode Choice
                    VStack(alignment: .leading, spacing: 7) {
                        optionLabel("Output Format", trailing: formatMode.title)
                        HStack(spacing: 8) {
                            formatModeButton(mode: .video, title: "Video", subtitle: "MP4 • up to 4K", symbol: "film")
                            formatModeButton(mode: .flac, title: "Lossless Audio", subtitle: "Bit-Perfect Studio Master", symbol: "sparkles")
                            formatModeButton(mode: .audio, title: "Audio Only", subtitle: "AAC 320k (YouTube)", symbol: "waveform")
                        }
                    }

                    // Content based on selected mode
                    if formatMode == .flac {
                        flacExplanationCard
                    } else if formatMode == .audio {
                        youtubeAudioCard
                    } else {
                        videoQualityCards
                    }

                    // Extra Settings
                    VStack(spacing: 0) {
                        if formatMode == .video {
                            extraRow(
                                symbol: "captions.bubble",
                                title: "Subtitles",
                                subtitle: "Embed available CC tracks",
                                isOn: $subtitles
                            )
                            Rectangle().fill(Pal.stroke).frame(height: 0.7)
                        }
                        extraRow(
                            symbol: "bolt.fill",
                            title: "Turbo Bond Acceleration",
                            subtitle: "16 concurrent multi-stream connections",
                            isOn: Binding(
                                get: { model.engine.settings.turboEnabled },
                                set: { model.setTurbo($0) }
                            )
                        )
                    }
                    .padding(.horizontal, 11)
                    .background(Pal.recess, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Pal.stroke, lineWidth: 0.7)
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                footer
            }
        }
    }

    private var subtitle: String {
        var parts = [info.host]
        if let duration = info.duration { parts.append(Fmt.duration(duration)) }
        if info.kind == .playlist { parts.append("Playlist") }
        return parts.joined(separator: " • ")
    }

    private var modeRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10, weight: .semibold))
                Text("Full Track / Video")
                    .font(Typo.body(11, .semibold))
            }
            .foregroundStyle(Pal.text)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Pal.veil(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Pal.strokeStrong, lineWidth: 0.7))

            Button(action: onClip) {
                HStack(spacing: 6) {
                    Image(systemName: "scissors")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Clip & Trim")
                        .font(Typo.body(11, .semibold))
                }
                .foregroundStyle(Pal.secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Pal.veil(0.03), in: Capsule())
                .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .noFocusOutline()

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("Up to 32 connections")
                    .font(Typo.body(9, .medium))
            }
            .foregroundStyle(Pal.tertiary)
        }
    }

    private func formatModeButton(mode: MediaOptionMode, title: String, subtitle: String, symbol: String) -> some View {
        let active = formatMode == mode
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                formatMode = mode
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? Pal.systemAccent : Pal.tertiary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Typo.body(10.5, .semibold))
                        .foregroundStyle(active ? Pal.text : Pal.secondary)
                    Text(subtitle)
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Pal.systemAccent.opacity(0.12) : Pal.veil(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(active ? Pal.systemAccent.opacity(0.35) : Pal.stroke, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .noFocusOutline()
    }

    // --- Sub-View: Open Source FLAC Explanation Card ---
    private var flacExplanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Pal.systemAccent.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Pal.systemAccent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Bit-Perfect Lossless Studio Audio")
                            .font(Typo.body(11, .bold))
                            .foregroundStyle(Pal.text)
                        Text("24-BIT / 96kHz")
                            .font(Typo.body(7.5, .bold))
                            .foregroundStyle(Pal.onAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Pal.systemAccent, in: Capsule())
                    }
                    Text("JioSaavn Studio Master & Apple Music / Deezer Hi-Fi")
                        .font(Typo.body(8.5))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
            }

            Text("Edit.or.lynx will search lossless streaming sources for a bit-perfect studio master. If this specific track is not found in Lossless, it automatically falls back to pristine YouTube 320k source audio.")
                .font(Typo.body(9.5))
                .foregroundStyle(Pal.secondary)
                .lineSpacing(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Pal.recess)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.systemAccent.opacity(0.24), lineWidth: 0.8)
        )
    }

    // --- Sub-View: YouTube Audio Stream Card ---
    private var youtubeAudioCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))

                VStack(alignment: .leading, spacing: 1) {
                    Text("YouTube Source Audio")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.text)
                    Text("Direct AAC 320 kbps in M4A container")
                        .font(Typo.body(8.5))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer()
                Text("Universal • Fast")
                    .font(Typo.body(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Pal.recess)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // --- Sub-View: Video Quality Cards ---
    private var videoQualityCards: some View {
        VStack(alignment: .leading, spacing: 7) {
            optionLabel("Resolution", trailing: info.durationText)
            HStack(spacing: 7) {
                ForEach(info.qualities) { q in
                    qualityCard(q)
                }
            }
        }
    }

    private func qualityCard(_ option: QualityOption) -> some View {
        let active = option.label == selectedQuality
        let locked = !PlanPolicy.allows(height: PlanPolicy.height(ofQuality: option.label), plan: model.plan)
        return Button {
            if locked {
                model.openPro?()
            } else {
                selectedQuality = option.label
            }
        } label: {
            VStack(spacing: 2) {
                Text(option.label)
                    .font(Typo.body(11.5, .semibold))
                    .foregroundStyle(active ? Pal.text : (locked ? Pal.tertiary : Pal.secondary))
                Text(option.sublabel)
                    .font(Typo.body(7.5))
                    .foregroundStyle(Pal.tertiary)
                Text(Fmt.bytes(Double(option.bytes)))
                    .font(Typo.mono(8, .medium))
                    .foregroundStyle(active ? Pal.accentText : Pal.tertiary)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Pal.systemAccent.opacity(0.12) : Pal.veil(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(active ? Pal.systemAccent.opacity(0.55) : Pal.stroke, lineWidth: active ? 1 : 0.7)
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    ProFlag()
                } else if option.recommended {
                    Circle().fill(Pal.systemAccent).frame(width: 4, height: 4).padding(6)
                }
            }
            .opacity(locked && !active ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .help(locked ? "4K and 1440p are Pro — click to activate" : option.label)
    }

    private func optionLabel(_ text: String, trailing: String?) -> some View {
        HStack {
            Text(text.uppercased())
                .font(Typo.body(8.5, .bold))
                .tracking(0.7)
                .foregroundStyle(Pal.tertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Typo.body(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
        }
    }

    private func extraRow(symbol: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Pal.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Typo.body(10.5, .medium))
                    .foregroundStyle(Pal.text)
                Text(subtitle)
                    .font(Typo.body(8))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
            ToggleSwitch(isOn: isOn)
        }
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.bytes(Double(estimatedBytes)))
                    .font(Typo.mono(11, .semibold))
                    .foregroundStyle(Pal.text)
                Text("\(min(32, model.engine.settings.connections)) connections • \(formatMode == .flac ? "Lossless Audio" : (formatMode == .audio ? "M4A 320k" : selectedQuality))")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()

            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(Typo.body(10.5))
                    .foregroundStyle(Pal.tertiary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .noFocusOutline()

            Button {
                if formatMode == .flac {
                    model.downloadAudio(info: info, preferFlac: true)
                } else if formatMode == .audio {
                    model.downloadAudio(info: info, preferFlac: false)
                } else if let quality {
                    model.downloadVideo(info: info, quality: quality, audioOnly: false, subtitles: subtitles)
                }
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: formatMode == .flac ? "sparkles" : (formatMode == .audio ? "waveform" : "bolt.fill"))
                        .font(.system(size: 9, weight: .bold))
                    Text(formatMode == .flac ? "Download Lossless (16x Turbo)" : (formatMode == .audio ? "Download Audio (320k)" : "Download Video (16x Turbo)"))
                        .font(Typo.body(11, .semibold))
                }
                .foregroundStyle(Pal.onAccent)
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Pal.systemAccent, in: Capsule())
            }
            .buttonStyle(.plain)
            .noFocusOutline()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Pal.recess)
        .overlay(alignment: .top) {
            Rectangle().fill(Pal.stroke).frame(height: 0.8)
        }
    }
}

// MARK: - Playlist

struct PlaylistOptionsView: View {
    @ObservedObject var model: AppModel
    let info: LinkInfo
    let onClose: () -> Void

    @State private var audioOnly = false
    @State private var selectedQuality: String
    @State private var subtitles = false
    @State private var selected: Set<UUID>

    init(model: AppModel, info: LinkInfo, onClose: @escaping () -> Void) {
        self.model = model
        self.info = info
        self.onClose = onClose
        _selectedQuality = State(initialValue: info.qualities.first(where: { $0.recommended })?.label ?? info.qualities.first?.label ?? "")
        _selected = State(initialValue: Set(info.playlist?.videos.map(\.id) ?? []))
    }

    private var playlist: PlaylistInfo? { info.playlist }

    private var quality: QualityOption? {
        info.qualities.first { $0.label == selectedQuality } ?? info.qualities.first
    }

    private var selectedVideos: [PlaylistVideo] {
        (playlist?.videos ?? []).filter { selected.contains($0.id) }
    }

    private var totalBytes: Int64 {
        guard let quality, let playlist, playlist.totalBytes > 0 else { return 0 }
        let scale = Double(quality.bytes) / Double(playlist.totalBytes)
        let bytes = selectedVideos.reduce(Int64(0)) { $0 + Int64(Double($1.bytes) * scale) }
        return audioOnly ? Int64(Double(bytes) * 0.075) : bytes
    }

    var body: some View {
        PanelChrome {
            VStack(spacing: 0) {
                OptionsHeader(
                    eyebrow: "Playlist • \(info.host)",
                    title: playlist?.title ?? info.title,
                    subtitle: "\(playlist?.creator ?? "Playlist") • \(playlist?.videos.count ?? 0) videos • \(playlist?.durationText ?? "")",
                    seed: info.thumbSeed,
                    kind: .video,
                    onClose: onClose
                )

                Rectangle().fill(Pal.stroke).frame(height: 0.8)

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        saveOption(title: "Videos", subtitle: "MP4", symbol: "film", active: !audioOnly) {
                            audioOnly = false
                        }
                        saveOption(title: "Audio Only", subtitle: "M4A", symbol: "waveform", active: audioOnly) {
                            audioOnly = true
                        }
                        Spacer()
                        Text("Up to \(selectedQuality)")
                            .font(Typo.body(9, .medium))
                            .foregroundStyle(Pal.tertiary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Pal.veil(0.05), in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("QUALITY")
                                .font(Typo.body(8.5, .bold))
                                .tracking(0.7)
                                .foregroundStyle(Pal.tertiary)
                            Spacer()
                            ToggleSwitch(isOn: $subtitles)
                                .scaleEffect(0.8)
                                .frame(width: 28)
                            Text("Subtitles")
                                .font(Typo.body(8.5, .medium))
                                .foregroundStyle(Pal.tertiary)
                        }
                        HStack(spacing: 7) {
                            ForEach(info.qualities) { q in
                                qualityChip(q)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            if selected.count == (playlist?.videos.count ?? 0) {
                                selected.removeAll()
                            } else {
                                selected = Set(playlist?.videos.map(\.id) ?? [])
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: selected.count == (playlist?.videos.count ?? 0) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Pal.accent)
                                Text("Select All")
                                    .font(Typo.body(9.5, .medium))
                                    .foregroundStyle(Pal.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text("\(selected.count) of \(playlist?.videos.count ?? 0) selected")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }

                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array((playlist?.videos ?? []).enumerated()), id: \.element.id) { index, video in
                                playlistRow(video, index: index)
                            }
                        }
                    }
                    .compatScrollIndicatorsHidden()
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Pal.tertiary)
                        Text("Every selected video downloads separately. Edit.or.lynx runs up to \(model.engine.settings.maxConcurrent) at once.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity)

                footer
            }
        }
    }

    private func qualityChip(_ q: QualityOption) -> some View {
        let active = q.label == selectedQuality
        let locked = !PlanPolicy.allows(height: PlanPolicy.height(ofQuality: q.label), plan: model.plan)
        return Button {
            if locked {
                model.openPro?()
            } else {
                selectedQuality = q.label
            }
        } label: {
            VStack(spacing: 1) {
                Text(q.label)
                    .font(Typo.body(10, .semibold))
                    .foregroundStyle(active ? Pal.text : (locked ? Pal.tertiary : Pal.secondary))
                Text(q.sublabel)
                    .font(Typo.body(7))
                    .foregroundStyle(Pal.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Pal.accent.opacity(0.1) : Pal.veil(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(active ? Pal.accent.opacity(0.5) : Pal.stroke, lineWidth: 0.7)
            )
            .overlay(alignment: .topTrailing) {
                if locked { ProFlag() }
            }
            .opacity(locked && !active ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }

    private func playlistRow(_ video: PlaylistVideo, index: Int) -> some View {
        let isOn = selected.contains(video.id)
        return Button {
            if isOn { selected.remove(video.id) } else { selected.insert(video.id) }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOn ? Pal.accent : Pal.tertiary)
                Text(String(format: "%02d", index + 1))
                    .font(Typo.mono(8, .medium))
                    .foregroundStyle(Pal.tertiary)
                    .frame(width: 15, alignment: .leading)
                Text(video.title)
                    .font(Typo.body(10, .medium))
                    .foregroundStyle(isOn ? Pal.text : Pal.secondary)
                    .lineLimit(1)
                Spacer()
                Text(video.durationText)
                    .font(Typo.mono(8, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
            .padding(.horizontal, 9)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? Pal.veil(0.045) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.bytes(Double(totalBytes)))
                    .font(Typo.mono(11, .semibold))
                    .foregroundStyle(Pal.text)
                Text("\(selected.count) videos • \(selectedQuality)\(audioOnly ? " • Audio only" : "")")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
            Button {
                if let quality {
                    model.downloadPlaylist(
                        info: info,
                        videoIDs: selected,
                        quality: quality,
                        audioOnly: audioOnly,
                        subtitles: subtitles
                    )
                }
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text("Download \(selected.count)")
                        .font(Typo.body(11.5, .semibold))
                }
                .foregroundStyle(Color(hex: 0x1B1205))
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(
                    LinearGradient(colors: [Pal.accentSoft, Pal.accent], startPoint: .top, endPoint: .bottom),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .opacity(selected.isEmpty ? 0.45 : 1)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(Pal.recess)
        .overlay(alignment: .top) {
            Rectangle().fill(Pal.stroke).frame(height: 0.8)
        }
    }

    private func saveOption(title: String, subtitle: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? Pal.accent : Pal.tertiary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Typo.body(10.5, .semibold))
                        .foregroundStyle(active ? Pal.text : Pal.secondary)
                    Text(subtitle)
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Pal.accent.opacity(0.1) : Pal.veil(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(active ? Pal.accent.opacity(0.28) : Pal.stroke, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }
}
