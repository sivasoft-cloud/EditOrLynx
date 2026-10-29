import AppKit
import SwiftUI

// MARK: - Notch Equalizer Spectrum Wave (Pic 2 Design)

struct NotchEqualizerWaveView: View {
    let isPlaying: Bool
    @State private var timer: Timer? = nil
    @State private var scales: [CGFloat] = [
        0.35, 0.5, 0.7, 0.85, 0.95, 1.0, 0.9, 0.8, 0.9, 1.0, 0.85, 0.7, 0.85, 0.65, 0.5, 0.45, 0.35, 0.25
    ]

    private let baseEnvelope: [CGFloat] = [
        4.5, 6.5, 8.5, 11.5, 13.5, 15.0, 14.0, 12.5, 13.5, 15.0, 13.5, 12.0, 10.5, 8.5, 7.0, 5.5, 4.5, 3.5
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<baseEnvelope.count, id: \.self) { idx in
                let targetH = max(2.5, baseEnvelope[idx] * (isPlaying ? scales[idx] : 0.35))
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .frame(width: 2, height: targetH)
            }
        }
        .foregroundStyle(
            LinearGradient(
                colors: [Color(hex: 0x38BDF8), Color(hex: 0xEC4899)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(height: 16, alignment: .center)
        .onAppear {
            if isPlaying { startAnimating() }
        }
        .onDisappear {
            stopAnimating()
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }

    private func startAnimating() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            var newScales = scales
            for i in 0..<newScales.count {
                newScales[i] = CGFloat.random(in: 0.35...1.05)
            }
            withAnimation(.easeInOut(duration: 0.12)) {
                scales = newScales
            }
        }
    }

    private func stopAnimating() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            scales = Array(repeating: 0.35, count: baseEnvelope.count)
        }
    }
}

// MARK: - Leading Artwork + Title / Artist View (Pic 2 Left Wing)

struct NowPlayingCompactLeadingArtView: View {
    @ObservedObject private var manager = NowPlayingManager.shared
    var maxTextWidth: CGFloat = 130

    var body: some View {
        HStack(spacing: 7) {
            if let art = manager.albumArt {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(manager.title.isEmpty ? "Edit.or.lynx Music" : manager.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(manager.artist.isEmpty ? (manager.sourceName.isEmpty ? "Now Playing" : manager.sourceName) : manager.artist)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: maxTextWidth, alignment: .leading)
        }
    }
}

// MARK: - Trailing Equalizer + Time View (Pic 2 Right Wing)

struct NowPlayingCompactTrailingWaveView: View {
    @ObservedObject private var manager = NowPlayingManager.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            NotchEqualizerWaveView(isPlaying: manager.isPlaying && !appState.shouldReduceAnimations)

            if !remainingTimeString.isEmpty {
                Text(remainingTimeString)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            manager.togglePlayPause()
        }
    }

    private var remainingTimeString: String {
        if manager.duration > 0 {
            let remaining = max(0, manager.duration - manager.elapsedTime)
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            return String(format: "%d:%02d", m, s)
        } else if manager.elapsedTime > 0 {
            let m = Int(manager.elapsedTime) / 60
            let s = Int(manager.elapsedTime) % 60
            return String(format: "%d:%02d", m, s)
        } else {
            return ""
        }
    }
}

// MARK: - Main NowPlayingCompactView (Single Pill / Non-Notch Mode)

struct NowPlayingCompactView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var manager = NowPlayingManager.shared

    var body: some View {
        HStack(spacing: 8) {
            NowPlayingCompactLeadingArtView(maxTextWidth: appState.usesWideCompactLayout ? 140 : 90)

            Spacer(minLength: 6)

            NowPlayingCompactTrailingWaveView()
        }
    }
}

// MARK: - Backwards Compatibility Wrappers

struct NowPlayingPlaybackCompactButton: View {
    var body: some View {
        NowPlayingCompactTrailingWaveView()
    }
}

struct EqualizerBarsView: View {
    let isPlaying: Bool
    var barColor: NSColor = .white

    var body: some View {
        NotchEqualizerWaveView(isPlaying: isPlaying)
    }
}
