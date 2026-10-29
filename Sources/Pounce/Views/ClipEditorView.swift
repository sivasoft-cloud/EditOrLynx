import SwiftUI
import Combine
import PounceCore

struct ClipEditorView: View {
    @ObservedObject var model: AppModel
    let info: LinkInfo
    let onClose: () -> Void

    @State private var parts: [ClipPart]
    @State private var format: ClipFormat = .video
    @State private var quality: String = "1080p"
    @State private var subtitles = false
    @State private var isPlaying = false
    @State private var playhead: Double = 0

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(model: AppModel, info: LinkInfo, onClose: @escaping () -> Void) {
        self.model = model
        self.info = info
        self.onClose = onClose
        let duration = info.duration ?? 1_528
        let start = min(max(0, duration * 0.164), max(0, duration - 36))
        _parts = State(initialValue: [ClipPart(start: start, end: min(duration, start + 35))])
        _playhead = State(initialValue: start)
    }

    private var duration: Double { info.duration ?? 1_528 }

    private var selection: ClipSelection {
        ClipSelection(parts: parts, format: format, qualityLabel: quality, subtitles: subtitles, audioOnly: format == .audio)
    }

    private var estimate: Int64 {
        let multipliers: [String: Double] = [
            "4K 60": 1.0,
            "1440p60": 0.598,
            "1080p": 0.37,
            "720p": 0.222,
            "480p": 0.103
        ]
        return selection.estimatedBytes(
            fullBytes: info.fullBytes,
            fullDuration: duration,
            qualityMultiplier: multipliers[quality] ?? 0.37
        )
    }

    var body: some View {
        PanelChrome {
            VStack(spacing: 0) {
                header
                Rectangle().fill(Pal.stroke).frame(height: 0.8)

                VStack(spacing: 10) {
                    ClipPreview(info: info, format: format, playhead: playhead, isPlaying: isPlaying) {
                        togglePlayback()
                    }
                    .frame(height: 208)

                    transport
                    ClipTimeline(
                        duration: duration,
                        parts: $parts,
                        playhead: $playhead
                    )
                    .frame(height: 76)
                    .padding(.horizontal, 2)

                    HStack(spacing: 7) {
                        Button {
                            addPart()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8, weight: .bold))
                                Text("Add Another Part")
                                    .font(Typo.body(9, .semibold))
                            }
                            .foregroundStyle(Pal.accent)
                            .padding(.horizontal, 9)
                            .frame(height: 23)
                            .background(Pal.accent.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if parts.count > 1 {
                            Button {
                                parts.removeLast()
                            } label: {
                                Text("Remove Last")
                                    .font(Typo.body(9, .medium))
                                    .foregroundStyle(Pal.tertiary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Drag the handles, or play and set a range. Space plays.")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                        Spacer()
                        Text("\(parts.count) part\(parts.count == 1 ? "" : "s") • \(Fmt.shortDuration(selection.totalSeconds))")
                            .font(Typo.mono(8.5, .medium))
                            .foregroundStyle(Pal.secondary)
                    }

                    Rectangle().fill(Pal.stroke).frame(height: 0.7).padding(.vertical, 2)

                    saveAs
                    qualityRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer(minLength: 0)
                footer
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            playhead += 0.1
            if playhead >= duration { playhead = 0 }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Pal.accent.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "scissors")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Pal.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("CLIP EDITOR")
                    .font(Typo.body(8, .bold))
                    .tracking(0.9)
                    .foregroundStyle(Pal.accent)
                Text(info.title)
                    .font(Typo.display(16, .semibold))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)
                Text("\(info.host) • \(Fmt.duration(duration)) • Only the part you pick is downloaded")
                    .font(Typo.body(9))
                    .foregroundStyle(Pal.tertiary)
            }
            Spacer()
            Button {
                model.presentOptions?(info)
                onClose()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Full video")
                        .font(Typo.body(9, .semibold))
                }
                .foregroundStyle(Pal.secondary)
                .padding(.horizontal, 10)
                .frame(height: 27)
                .background(Pal.veil(0.05), in: Capsule())
                .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            CircleIconButton(symbol: "xmark", size: 27, help: "Close", action: onClose)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var transport: some View {
        HStack(spacing: 10) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: 0x1B1205))
                    .frame(width: 24, height: 24)
                    .background(Pal.accent, in: Circle())
            }
            .buttonStyle(.plain)

            Text("\(Fmt.clock(playhead)) / \(Fmt.clock(duration))")
                .font(Typo.mono(9.5, .medium))
                .foregroundStyle(Pal.secondary)

            HStack(spacing: 5) {
                Text("Start")
                    .font(Typo.body(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
                Text(timeString(parts.first?.start ?? 0))
                    .font(Typo.mono(9, .medium))
                    .foregroundStyle(Pal.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Pal.veil(0.055), in: RoundedRectangle(cornerRadius: 5))
                Text("End")
                    .font(Typo.body(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
                Text(timeString(parts.first?.end ?? 0))
                    .font(Typo.mono(9, .medium))
                    .foregroundStyle(Pal.text)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Pal.veil(0.055), in: RoundedRectangle(cornerRadius: 5))
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 8, weight: .semibold))
                Text("1x")
                    .font(Typo.body(8.5, .medium))
            }
            .foregroundStyle(Pal.tertiary)

            Text("\(Fmt.shortDuration(selection.totalSeconds)) selected")
                .font(Typo.body(8.5, .medium))
                .foregroundStyle(Pal.accentText)
        }
    }

    private var saveAs: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SAVE AS")
                    .font(Typo.body(8.5, .bold))
                    .tracking(0.7)
                    .foregroundStyle(Pal.tertiary)
                Spacer()
                Text("\(selection.totalSeconds > 0 ? Fmt.shortDuration(selection.totalSeconds) : "0 sec") • \(format.subtitleLabel)")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }
            HStack(spacing: 7) {
                ForEach(ClipFormat.allCases) { option in
                    formatCard(option)
                }
            }
        }
    }

    private func formatCard(_ option: ClipFormat) -> some View {
        let active = format == option
        let locked = !model.entitlements.allowsAllClipFormats && option != .video && option != .audio
        return Button {
            if locked {
                model.openPro?()
                return
            }
            format = option
            if option == .audio { subtitles = false }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: option.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? Pal.accent : Pal.tertiary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(option.title)
                        .font(Typo.body(10, .semibold))
                        .foregroundStyle(active ? Pal.text : Pal.secondary)
                    Text(option.sublabel)
                        .font(Typo.body(7.5))
                        .foregroundStyle(Pal.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Pal.accent.opacity(0.1) : Pal.veil(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(active ? Pal.accent.opacity(0.5) : Pal.stroke, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    private var qualityRow: some View {
        HStack(spacing: 8) {
            Text("QUALITY")
                .font(Typo.body(8, .bold))
                .tracking(0.7)
                .foregroundStyle(Pal.tertiary)

            HStack(spacing: 4) {
                ForEach(["4K 60", "1440p60", "1080p", "720p", "480p"], id: \.self) { label in
                    let active = quality == label
                    Button {
                        quality = label
                    } label: {
                        Text(label)
                            .font(Typo.body(9, active ? .semibold : .regular))
                            .foregroundStyle(active ? Pal.text : Pal.tertiary)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(
                                Capsule().fill(active ? Pal.accent.opacity(0.14) : Pal.veil(0.035))
                            )
                            .overlay(
                                Capsule().strokeBorder(active ? Pal.accent.opacity(0.35) : Pal.stroke, lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "captions.bubble")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(subtitles ? Pal.accent : Pal.tertiary)
                Text("Subtitles")
                    .font(Typo.body(9, .medium))
                    .foregroundStyle(subtitles ? Pal.secondary : Pal.tertiary)
                ToggleSwitch(isOn: $subtitles)
                    .scaleEffect(0.82)
                    .frame(width: 28)
                    .opacity(format == .audio ? 0.4 : 1)
                    .disabled(format == .audio)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Pal.tertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Only the part you pick is downloaded, not the whole \(Fmt.duration(duration)).")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.secondary)
                    Text("\(format.title) • \(quality) • \(format.fileExtension.uppercased()) • \(parts.count) part\(parts.count == 1 ? "" : "s")")
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                }
            }

            Spacer()

            Text("~ \(Fmt.bytes(Double(estimate)))")
                .font(Typo.mono(11.5, .semibold))
                .foregroundStyle(Pal.text)

            Button {
                model.downloadClip(info: info, selection: selection)
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scissors")
                        .font(.system(size: 9, weight: .bold))
                    Text("Download Clip")
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Pal.recess)
        .overlay(alignment: .top) {
            Rectangle().fill(Pal.stroke).frame(height: 0.8)
        }
    }

    private func togglePlayback() {
        if !isPlaying, let first = parts.first, playhead < first.start || playhead > first.end {
            playhead = first.start
        }
        isPlaying.toggle()
    }

    private func addPart() {
        guard parts.count < 4 else { return }
        let lastEnd = parts.map(\.end).max() ?? 0
        var start = min(duration - 10, lastEnd + 3)
        if start < 0 { start = 0 }
        var end = min(duration, start + 30)
        if end - start < 3 {
            start = max(0, duration - 12)
            end = duration
        }
        parts.append(ClipPart(start: start, end: end))
    }

    private func timeString(_ value: Double) -> String {
        let total = max(0, value)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let tenths = Int((total - floor(total)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private extension ClipFormat {
    var subtitleLabel: String {
        self == .audio ? "MP3" : (self == .gif ? "15 fps" : "MP4")
    }
}

// MARK: - Preview

struct ClipPreview: View {
    let info: LinkInfo
    let format: ClipFormat
    let playhead: Double
    let isPlaying: Bool
    let onToggle: () -> Void

    private var palette: [Color] {
        let sets: [[UInt32]] = [
            [0x26334F, 0x080B12, 0x6E8DC7],
            [0x4A2A24, 0x160B08, 0xE09A5B],
            [0x1E403B, 0x06100D, 0x6FC7A8],
            [0x3D2A4A, 0x120A16, 0xB58CFF]
        ]
        return sets[abs(info.thumbSeed) % sets.count].map { Color(hex: $0) }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x050506)

            frameContent
                .frame(width: frameWidth, height: frameHeight)
                .clipShape(RoundedRectangle(cornerRadius: format == .audio ? 12 : 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: format == .audio ? 12 : 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.5), radius: 18, y: 4)

            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.4), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .opacity(isPlaying ? 0.6 : 1)

            VStack {
                HStack {
                    Text("PREVIEW")
                        .font(Typo.body(7.5, .bold))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Text("\(format.sublabel) • \(Fmt.clock(playhead))")
                        .font(Typo.mono(8, .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
            }
            .padding(10)

            if format == .vertical || format == .square {
                Text(format == .vertical ? "9:16" : "1:1")
                    .font(Typo.body(7.5, .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.7)
        )
    }

    private var frameWidth: CGFloat {
        switch format {
        case .video, .gif, .audio: return 326
        case .vertical: return 104
        case .square: return 168
        }
    }

    private var frameHeight: CGFloat {
        switch format {
        case .video, .gif, .audio: return 184
        case .vertical: return 184
        case .square: return 168
        }
    }

    @ViewBuilder
    private var frameContent: some View {
        if format == .audio {
            ZStack {
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: 3) {
                    ForEach(0..<44, id: \.self) { index in
                        let value = 0.18 + 0.82 * abs(sin(Double(index) * 0.55 + playhead * 1.2))
                        Capsule()
                            .fill(Pal.accent.opacity(0.7))
                            .frame(width: 2.5, height: 10 + 44 * value)
                    }
                }
                .padding(.horizontal, 26)
                VStack {
                    Spacer()
                    HStack {
                        Text(info.title)
                            .font(Typo.body(9, .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("MP3")
                            .font(Typo.body(7, .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(10)
                }
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(palette[2].opacity(0.55))
                    .frame(width: 130)
                    .blur(radius: 28)
                    .offset(
                        x: 40 + sin(playhead * 0.06) * 14,
                        y: -22 + cos(playhead * 0.04) * 10
                    )
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                    .frame(width: 110)
                    .offset(x: -60, y: 40)

                VStack(alignment: .leading) {
                    Spacer()
                    Text("NORTHLIGHT STUDIO")
                        .font(Typo.body(6.5, .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.white.opacity(0.55))
                    Text(info.title)
                        .font(Typo.display(12, .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                        .frame(maxWidth: format == .vertical ? 92 : 210, alignment: .leading)
                    Text("A slow film about light")
                        .font(Typo.body(7.5))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }
}

// MARK: - Timeline

struct ClipTimeline: View {
    let duration: Double
    @Binding var parts: [ClipPart]
    @Binding var playhead: Double

    private var labels: [Double] {
        (0..<6).map { duration * Double($0) / 5.0 }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackY: CGFloat = 31
            let trackHeight: CGFloat = 30

            ZStack(alignment: .topLeading) {
                timeLabels(width: width)
                trackBackground(width: width, trackY: trackY, trackHeight: trackHeight)
                partBoxes(width: width, trackY: trackY, trackHeight: trackHeight)
                handles(width: width, trackY: trackY, trackHeight: trackHeight)
                playheadIndicator(width: width, trackY: trackY, trackHeight: trackHeight)
                rangesSummary(trackY: trackY, trackHeight: trackHeight)
            }
        }
    }

    @ViewBuilder
    private func timeLabels(width: CGFloat) -> some View {
        ForEach(Array(labels.enumerated()), id: \.offset) { _, value in
            let denom = max(1, duration)
            let xPos = max(12, min(width - 12, width * CGFloat(value / denom)))
            Text(Fmt.clock(value))
                .font(Typo.mono(7.5, .medium))
                .foregroundStyle(Pal.tertiary)
                .position(x: xPos, y: 6)
        }
    }

    @ViewBuilder
    private func trackBackground(width: CGFloat, trackY: CGFloat, trackHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Pal.veil(0.055))
            .frame(width: width, height: trackHeight)
            .offset(y: trackY)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Pal.stroke, lineWidth: 0.7)
                    .frame(width: width, height: trackHeight)
                    .offset(y: trackY)
            )
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                playhead = min(duration, max(0, Double(value.location.x / width) * duration))
            })
    }

    @ViewBuilder
    private func partBoxes(width: CGFloat, trackY: CGFloat, trackHeight: CGFloat) -> some View {
        let denom = max(1, duration)
        ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
            let x = width * CGFloat(part.start / denom)
            let w = width * CGFloat(max(0.004, (part.end - part.start) / denom))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Pal.accent.opacity(index == 0 ? 0.28 : 0.19))
                .frame(width: max(6, w), height: trackHeight - 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Pal.accent.opacity(0.7), lineWidth: 1)
                )
                .offset(x: x, y: trackY + 4)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func handles(width: CGFloat, trackY: CGFloat, trackHeight: CGFloat) -> some View {
        let denom = max(1, duration)
        ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
            TimelineHandle(
                x: width * CGFloat(part.start / denom),
                y: trackY,
                height: trackHeight
            ) { deltaX in
                let delta = Double(deltaX / width) * duration
                let current = parts[index]
                parts[index].start = min(max(0, current.start + delta), current.end - 1)
            }

            TimelineHandle(
                x: width * CGFloat(part.end / denom),
                y: trackY,
                height: trackHeight
            ) { deltaX in
                let delta = Double(deltaX / width) * duration
                let current = parts[index]
                parts[index].end = max(min(duration, current.end + delta), current.start + 1)
            }
        }
    }

    @ViewBuilder
    private func playheadIndicator(width: CGFloat, trackY: CGFloat, trackHeight: CGFloat) -> some View {
        let denom = max(1, duration)
        Rectangle()
            .fill(Pal.veil(0.9))
            .frame(width: 1, height: trackHeight + 10)
            .offset(x: width * CGFloat(playhead / denom), y: trackY - 5)
            .allowsHitTesting(false)

        Circle()
            .fill(Color.white)
            .frame(width: 5, height: 5)
            .offset(x: width * CGFloat(playhead / denom) - 2, y: trackY - 7)
    }

    @ViewBuilder
    private func rangesSummary(trackY: CGFloat, trackHeight: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.element.id) { index, part in
                Text("\(Fmt.clock(part.start))–\(Fmt.clock(part.end))")
                    .font(Typo.mono(7, .medium))
                    .foregroundStyle(Pal.tertiary)
                if index < parts.count - 1 {
                    Text("•").foregroundStyle(Pal.tertiary.opacity(0.5))
                }
            }
        }
        .offset(y: trackY + trackHeight + 5)
    }
}

struct TimelineHandle: View {
    let x: CGFloat
    let y: CGFloat
    let height: CGFloat
    let onDrag: (CGFloat) -> Void

    @State private var lastTranslation: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Pal.accent)
            .frame(width: 7, height: height + 6)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .offset(x: x - 3.5, y: y - 3)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let delta = value.translation.width - lastTranslation
                        lastTranslation = value.translation.width
                        onDrag(delta)
                    }
                    .onEnded { _ in lastTranslation = 0 }
            )
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
    }
}
