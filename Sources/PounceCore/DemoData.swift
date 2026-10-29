import Foundation

public enum DemoData {
    public static func seedDownloads(now: Date = Date()) -> [DownloadItem] {
        let zip = DownloadItem(
            title: "Northlight-Photo-Library-2026.zip",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/downloads/photo-library-2026.zip",
            kind: .file,
            formatLabel: "ZIP",
            qualityLabel: "—",
            totalBytes: 9_400_000_000,
            downloadedBytes: 3_960_000_000,
            state: .downloading,
            connectionCount: 32,
            addedAt: now.addingTimeInterval(-740),
            baseSpeedPerConnection: 3_420_000,
            currentSpeed: 109_700_000,
            seed: 41
        )

        let clip = DownloadItem(
            title: "First Light Over the Hills — Clip",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/films/first-light-over-the-hills",
            kind: .clip,
            formatLabel: "MP4",
            qualityLabel: "1080p",
            totalBytes: 22_400_000,
            downloadedBytes: 22_400_000,
            state: .completed,
            connectionCount: 8,
            addedAt: now.addingTimeInterval(-4_100),
            completedAt: now.addingTimeInterval(-4_050),
            baseSpeedPerConnection: 3_100_000,
            speedSamples: sampleCurve(seed: 7, peak: 24_000_000),
            clipSummary: "4:10–4:45 • 35 sec • Video",
            seed: 7
        )

        let video = DownloadItem(
            title: "Northern Light: The Making Of",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/films/northern-light-making-of",
            kind: .video,
            formatLabel: "MP4",
            qualityLabel: "1080p",
            totalBytes: 255_000_000,
            downloadedBytes: 255_000_000,
            state: .completed,
            connectionCount: 16,
            addedAt: now.addingTimeInterval(-7_900),
            completedAt: now.addingTimeInterval(-7_860),
            baseSpeedPerConnection: 3_200_000,
            speedSamples: sampleCurve(seed: 3, peak: 52_000_000),
            seed: 3
        )

        let wallpapers = DownloadItem(
            title: "Northlight-Wallpapers-6K.zip",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/downloads/wallpapers-6k.zip",
            kind: .file,
            formatLabel: "ZIP",
            qualityLabel: "—",
            totalBytes: 1_240_000_000,
            downloadedBytes: 1_240_000_000,
            state: .completed,
            connectionCount: 24,
            addedAt: now.addingTimeInterval(-91_000),
            completedAt: now.addingTimeInterval(-90_900),
            baseSpeedPerConnection: 3_000_000,
            speedSamples: sampleCurve(seed: 11, peak: 71_000_000),
            seed: 11
        )

        let audio = DownloadItem(
            title: "Morning Field Recordings",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/sound/morning-field-recordings.m4a",
            kind: .audio,
            formatLabel: "M4A",
            qualityLabel: "320 kbps",
            totalBytes: 48_000_000,
            downloadedBytes: 48_000_000,
            state: .completed,
            connectionCount: 6,
            addedAt: now.addingTimeInterval(-124_000),
            completedAt: now.addingTimeInterval(-123_950),
            baseSpeedPerConnection: 2_600_000,
            speedSamples: sampleCurve(seed: 5, peak: 15_000_000),
            seed: 5
        )

        let paused = DownloadItem(
            title: "The Watcher on the Ridge",
            sourceHost: "northlight.films",
            urlString: "https://northlight.films/films/the-watcher-on-the-ridge",
            kind: .video,
            formatLabel: "MP4",
            qualityLabel: "720p",
            totalBytes: 368_700_000,
            downloadedBytes: 201_000_000,
            state: .paused,
            connectionCount: 12,
            addedAt: now.addingTimeInterval(-1_800),
            baseSpeedPerConnection: 3_000_000,
            speedSamples: sampleCurve(seed: 9, peak: 35_000_000),
            seed: 9
        )

        return [zip, paused, clip, video, wallpapers, audio]
    }

    public static func seedClipboard(now: Date = Date()) -> [ClipboardEntry] {
        [
            ClipboardEntry(
                text: "Thursday 3 pm: bring the trailer cut and the logo files.",
                kind: .text,
                sourceApp: "Messages",
                sourceBundleID: "com.apple.MobileSMS",
                capturedAt: now.addingTimeInterval(-560)
            ),
            ClipboardEntry(
                text: "#FF9F0A",
                kind: .color,
                sourceApp: "Figma",
                sourceBundleID: "com.figma.Desktop",
                capturedAt: now.addingTimeInterval(-1_440)
            ),
            ClipboardEntry(
                text: "https://northlight.films/films/northern-light-making-of",
                kind: .link,
                sourceApp: "Safari",
                sourceBundleID: "com.apple.Safari",
                capturedAt: now.addingTimeInterval(-2_700)
            ),
            ClipboardEntry(
                text: "Order #4512 ships Tuesday. Tracking 1Z 999 AA1 0123 4567 84",
                kind: .text,
                sourceApp: "Mail",
                sourceBundleID: "com.apple.mail",
                capturedAt: now.addingTimeInterval(-3_700)
            )
        ]
    }

    private static func sampleCurve(seed: Int, peak: Double) -> [Double] {
        (0..<36).map { index in
            let phase = Double(index + seed) * 0.42
            let envelope = sin(Double(index) / 35.0 * Double.pi)
            let wobble = 0.78 + 0.22 * sin(phase * 1.7)
            return max(0, peak * envelope * wobble)
        }
    }
}
