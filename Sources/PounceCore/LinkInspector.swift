import Foundation

public enum LinkInspector {
    private static let videoExtensions: Set<String> = ["mp4", "mov", "mkv", "webm", "avi", "m4v", "mpeg", "mpg"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "aac", "ogg", "opus"]

    private static let playlistTitles = [
        "Northern Light",
        "First Light Over the Hills",
        "The Watcher on the Ridge",
        "Still Water",
        "Rivers From Above",
        "Blue Hour",
        "The Long Way Home",
        "Snow on the Pines",
        "After the Storm",
        "Quiet Frequencies",
        "Under a Pale Sky",
        "Last Light"
    ]

    private static let playlistDurations: [TimeInterval] = [
        634, 412, 538, 520, 603, 372, 598, 461, 512, 425, 488, 557
    ]

    public static func inspect(_ raw: String) -> LinkInfo? {
        guard let url = ClipboardClassifier.normalizeLink(raw) ?? extractURL(from: raw) else { return nil }
        return inspect(url: url)
    }

    public static func extractURL(from text: String) -> URL? {
        let pattern = #"(https?://[^\s<>"'{}|\\^`]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return URL(string: String(text[range]))
    }

    public static func inspect(url: URL) -> LinkInfo? {
        if url.scheme == "data" {
            return LinkInfo(
                url: url,
                host: "ChatGPT",
                title: "ChatGPT Generated Image",
                kind: .file,
                fullBytes: Int64(max(1024, url.absoluteString.count * 3 / 4)),
                thumbSeed: 42
            )
        }
        if url.scheme?.lowercased() == "magnet" || url.absoluteString.lowercased().hasPrefix("magnet:?") {
            let title = extractMagnetTitle(from: url.absoluteString)
            return LinkInfo(
                url: url,
                host: "BitTorrent",
                title: title,
                kind: .file,
                fullBytes: 0,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }
        if url.pathExtension.lowercased() == "torrent" {
            let filename = url.deletingPathExtension().lastPathComponent
            return LinkInfo(
                url: url,
                host: "BitTorrent",
                title: filename.isEmpty ? "Torrent Package" : filename,
                kind: .file,
                fullBytes: 0,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }
        guard let host = url.host?.lowercased() else { return nil }
        let cleanHost = displayHost(host)
        let lowerPath = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""

        // 1. Google Drive Links (Folders & Files)
        if isGoogleDrive(host) {
            let isFolder = lowerPath.contains("/folders/") || query.contains("folder")
            let id = extractGoogleDriveID(from: url)
            let shortID = id.isEmpty ? "" : " (\(id.prefix(8)))"
            let displayTitle = isFolder ? "Google Drive Folder\(shortID)" : "Google Drive File\(shortID)"
            let targetURL: URL
            if !isFolder, !id.isEmpty {
                targetURL = URL(string: "https://drive.usercontent.google.com/download?id=\(id)&export=download&confirm=t") ?? url
            } else {
                targetURL = url
            }
            return LinkInfo(
                url: targetURL,
                host: "drive.google.com",
                title: displayTitle,
                kind: isFolder ? .playlist : .file,
                fullBytes: isFolder ? 70_000_000_000 : 100_000_000,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }

        // 1.5 Spotify Links (Tracks, Albums, Playlists)
        if isSpotify(host) {
            let isCollection = lowerPath.contains("/album/") || lowerPath.contains("/playlist/")
            let displayTitle = isCollection ? "Spotify Collection" : "Spotify Track"
            return LinkInfo(
                url: url,
                host: "open.spotify.com",
                title: displayTitle,
                kind: isCollection ? .playlist : .audio,
                duration: 210,
                fullBytes: isCollection ? 500_000_000 : 38_000_000,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }

        // 1.8 ChatGPT / OpenAI Generated Images
        if host.contains("oaiusercontent.com") || host.contains("oaistatic.com") || host.contains("openai.com") {
            return LinkInfo(
                url: url,
                host: "ChatGPT",
                title: "ChatGPT Generated Image",
                kind: .file,
                fullBytes: 2_500_000,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }

        if query.contains("list=") || lowerPath.contains("playlist") || lowerPath.contains("/sets/") || lowerPath.contains("/album/") {
            return makePlaylist(url: url, host: cleanHost)
        }

        let ext = url.pathExtension.lowercased()
        let slug = titleFromURL(url)

        let videoPath = lowerPath.contains("/films/")
            || lowerPath.contains("/watch")
            || lowerPath.contains("/video/")
            || lowerPath.contains("/movies/")
            || lowerPath.contains("/videos/")
            || lowerPath.contains("/shorts/")
            || lowerPath.contains("/live/")
            || lowerPath.contains("/embed/")

        let isStreamingVideo = isVideoSite(host) || (videoPath && isVideoSite(host))

        if isStreamingVideo {
            let duration = demoDuration(for: url)
            let qualities = makeVideoQualities(duration: duration)
            return LinkInfo(
                url: url,
                host: cleanHost,
                title: slug,
                kind: .video,
                duration: duration,
                fullBytes: qualities.first?.bytes ?? 1_660_000_000,
                qualities: qualities,
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }

        if audioExtensions.contains(ext) || (query.contains("audio") && isVideoSite(host)) {
            let size = Int64(8_000_000 + stableHash(url.absoluteString) % 62_000_000)
            return LinkInfo(
                url: url,
                host: cleanHost,
                title: slug,
                kind: .audio,
                duration: nil,
                fullBytes: size,
                qualities: [
                    QualityOption(label: "320 kbps", sublabel: "M4A", bytes: size, recommended: true),
                    QualityOption(label: "128 kbps", sublabel: "M4A", bytes: Int64(Double(size) * 0.42))
                ],
                thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
            )
        }

        let size = fileSize(for: url)
        return LinkInfo(
            url: url,
            host: cleanHost,
            title: slug,
            kind: .file,
            fullBytes: size,
            thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
        )
    }

    public static func titleFromURL(_ url: URL) -> String {
        if url.scheme == "data" {
            return "ChatGPT Generated Image"
        }
        if let host = url.host?.lowercased(), host.contains("oaiusercontent.com") || host.contains("openai.com") {
            return "ChatGPT Generated Image"
        }
        var candidate = url.lastPathComponent
        if candidate.isEmpty || candidate == "/" {
            candidate = url.host ?? "Download"
        }
        if let decoded = candidate.removingPercentEncoding {
            candidate = decoded
        }
        let stem = (candidate as NSString).deletingPathExtension
        if stem.isEmpty { return url.host ?? "Download" }
        let minorWords: Set<String> = ["the", "of", "and", "over", "from", "a", "on", "in", "to"]
        let rawWords = stem
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)
        var words: [String] = []
        for (index, word) in rawWords.enumerated() {
            let lower = word.lowercased()
            let isEdge = index == 0 || index == rawWords.count - 1
            if minorWords.contains(lower) && !isEdge {
                words.append(lower)
            } else {
                words.append(lower.capitalized)
            }
        }
        if words.isEmpty { words = [stem] }
        var title = words.joined(separator: " ")
        if title.count > 72 { title = String(title.prefix(69)) + "…" }
        if title.lowercased() == "watch" || title.lowercased() == "index" || title.lowercased().hasPrefix("youtube") {
            if let query = url.query {
                let items = query.split(separator: "&")
                if let vParam = items.first(where: { $0.hasPrefix("v=") }) {
                    let vid = String(vParam.dropFirst(2))
                    if !vid.isEmpty {
                        return "YouTube Video (\(vid))"
                    }
                }
            }
            let host = url.host?.lowercased() ?? ""
            if host.contains("youtu.be") && !url.lastPathComponent.isEmpty && url.lastPathComponent != "/" {
                return "YouTube Video (\(url.lastPathComponent))"
            }
            title = (url.host ?? "Video") + " video"
        }
        return title
    }

    public static func displayHost(_ host: String) -> String {
        var value = host
        if value.hasPrefix("www.") { value.removeFirst(4) }
        return value
    }

    public static func isVideoSite(_ host: String) -> Bool {
        let known = [
            "youtube.com", "youtu.be", "vimeo.com", "dailymotion.com", "twitch.tv",
            "tiktok.com", "instagram.com", "facebook.com", "x.com", "twitter.com",
            "music.youtube.com", "soundcloud.com", "spotify.com", "open.spotify.com", "northlight.films"
        ]
        return known.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    public static func isSpotify(_ host: String) -> Bool {
        return host.contains("spotify.com")
    }

    public static func extractYouTubeID(from url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") {
            return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if let query = url.query {
            for pair in query.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 && parts[0].lowercased() == "v" {
                    return String(parts[1])
                }
            }
        }
        let path = url.path
        if let range = path.range(of: "/shorts/") {
            return String(path[range.upperBound...]).split(separator: "/").first.map(String.init) ?? ""
        }
        if let range = path.range(of: "/live/") {
            return String(path[range.upperBound...]).split(separator: "/").first.map(String.init) ?? ""
        }
        return ""
    }

    public static func isGoogleDrive(_ host: String) -> Bool {
        return host.contains("drive.google.com") || host.contains("docs.google.com") || host.contains("googleusercontent.com")
    }

    public static func extractGoogleDriveID(from url: URL) -> String {
        let path = url.path
        if let range = path.range(of: "/folders/") {
            let rest = String(path[range.upperBound...])
            return rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
        }
        if let range = path.range(of: "/file/d/") {
            let rest = String(path[range.upperBound...])
            return rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
        }
        if let query = url.query {
            for pair in query.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 && parts[0].lowercased() == "id" {
                    return String(parts[1])
                }
            }
        }
        return ""
    }

    public static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    private static func demoDuration(for url: URL) -> TimeInterval {
        let text = url.absoluteString.lowercased()
        if text.contains("northern-light") { return 1_528 }
        let base = 300 + stableHash(text) % 1_200
        return TimeInterval(base)
    }

    private static func makeVideoQualities(duration: TimeInterval) -> [QualityOption] {
        let scale = max(0.08, duration / 1_528.0)
        let base = 1_660_000_000.0 * scale
        return [
            QualityOption(label: "4K 60", sublabel: "2160p", bytes: Int64(base), recommended: true),
            QualityOption(label: "1440p60", sublabel: "2K", bytes: Int64(base * 0.598)),
            QualityOption(label: "1080p", sublabel: "HD", bytes: Int64(base * 0.370)),
            QualityOption(label: "720p", sublabel: "HD", bytes: Int64(base * 0.222)),
            QualityOption(label: "480p", sublabel: "SD", bytes: Int64(base * 0.103))
        ]
    }

    private static func fileSize(for url: URL) -> Int64 {
        let text = url.absoluteString.lowercased()
        if text.contains("photo-library") { return 9_400_000_000 }
        if text.contains("wallpaper") { return 1_240_000_000 }
        if text.contains("field-recording") { return 48_000_000 }
        let unit = 20_000_000 + Int64(stableHash(text) % 220) * 1_000_000
        return unit
    }

    private static func makePlaylist(url: URL, host: String) -> LinkInfo {
        var videos: [PlaylistVideo] = []
        for (index, title) in playlistTitles.enumerated() {
            let duration = playlistDurations[index % playlistDurations.count]
            let bytes = Int64(duration * 400_000)
            videos.append(PlaylistVideo(title: title, duration: duration, bytes: bytes))
        }
        let playlist = PlaylistInfo(
            title: "Northern Series",
            creator: "Northlight Studio",
            videos: videos,
            sourceHost: host
        )
        return LinkInfo(
            url: url,
            host: host,
            title: playlist.title,
            kind: .playlist,
            duration: playlist.totalDuration,
            fullBytes: playlist.totalBytes,
            qualities: [
                QualityOption(label: "4K 60", sublabel: "2160p", bytes: Int64(Double(playlist.totalBytes) * 2.7)),
                QualityOption(label: "1440p60", sublabel: "2K", bytes: Int64(Double(playlist.totalBytes) * 1.6)),
                QualityOption(label: "1080p", sublabel: "HD", bytes: playlist.totalBytes, recommended: true),
                QualityOption(label: "720p", sublabel: "HD", bytes: Int64(Double(playlist.totalBytes) * 0.6)),
                QualityOption(label: "480p", sublabel: "SD", bytes: Int64(Double(playlist.totalBytes) * 0.28))
            ],
            playlist: playlist,
            thumbSeed: Int(stableHash(url.absoluteString) % 9_000)
        )
    }

    public static func extractMagnetTitle(from raw: String) -> String {
        if let queryStart = raw.range(of: "?") {
            let query = String(raw[queryStart.upperBound...])
            for param in query.split(separator: "&") {
                let parts = param.split(separator: "=", maxSplits: 1)
                if parts.count == 2 && parts[0].lowercased() == "dn" {
                    let decoded = parts[1].replacingOccurrences(of: "+", with: " ")
                    return decoded.removingPercentEncoding ?? String(decoded)
                }
            }
        }
        return "Magnet Torrent Download"
    }
}
