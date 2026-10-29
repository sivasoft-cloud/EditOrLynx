import Foundation

public final class AudioExtractor {
    public static let shared = AudioExtractor()
    private init() {}

    public static var ytdlpPath: String? {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            Bundle.main.bundlePath + "/Contents/Resources/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static var ffmpegPath: String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            Bundle.main.bundlePath + "/Contents/Resources/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func extractAudio(
        mediaURL: URL,
        destinationFolder: URL,
        format: String = "mp3",
        quality: String = "320k"
    ) async throws -> URL {
        guard let ytdlp = Self.ytdlpPath else {
            throw NSError(domain: "AudioExtractor", code: 404, userInfo: [NSLocalizedDescriptionKey: "yt-dlp not found"])
        }

        let outputTemplate = destinationFolder.appendingPathComponent("%(title)s.%(ext)s").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlp)
        process.arguments = [
            "-x",
            "--audio-format", format,
            "--audio-quality", quality,
            "-o", outputTemplate,
            mediaURL.absoluteString
        ]

        if let ffmpeg = Self.ffmpegPath {
            process.arguments?.append(contentsOf: ["--ffmpeg-location", ffmpeg])
        }

        try process.run()
        process.waitUntilExit()

        return destinationFolder
    }
}
