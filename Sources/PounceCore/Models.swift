import Foundation

// MARK: - Downloads

public enum DownloadKind: String, Codable, CaseIterable, Identifiable {
    case video
    case audio
    case file
    case clip

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        case .file: return "File"
        case .clip: return "Clip"
        }
    }

    public var symbol: String {
        switch self {
        case .video: return "film"
        case .audio: return "waveform"
        case .file: return "doc.zipper"
        case .clip: return "scissors"
        }
    }
}

public enum DownloadState: String, Codable {
    case queued
    case downloading
    case paused
    case completed
    case failed

    public var isActive: Bool {
        switch self {
        case .queued, .downloading, .paused, .failed: return true
        case .completed: return false
        }
    }

    public var label: String {
        switch self {
        case .queued: return "Waiting"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

public struct DownloadItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var sourceHost: String
    public var urlString: String
    public var kind: DownloadKind
    public var formatLabel: String
    public var qualityLabel: String
    public var totalBytes: Int64
    public var downloadedBytes: Int64
    public var state: DownloadState
    public var connectionCount: Int
    public var addedAt: Date
    public var completedAt: Date?
    public var destinationFolder: String
    public var isTurbo: Bool
    public var baseSpeedPerConnection: Double
    public var currentSpeed: Double
    public var speedSamples: [Double]
    public var clipSummary: String?
    public var autoDelete: Bool
    public var seed: Int
    public var errorMessage: String?
    /// Absolute path of the file written to disk once the transfer finishes.
    public var filePath: String?
    /// True when the bytes come from a real transfer instead of the demo animation.
    /// Optional so state saved by an older build still decodes.
    public var liveTransfer: Bool?
    /// The part of a video a clip covers, in seconds (nil for whole videos).
    public var clipStart: Double?
    public var clipEnd: Double?
    /// Status hint during post-processing (e.g. "Merging video & audio…", "Finalizing…")
    public var statusHint: String?
    /// Rich audio metadata for tagging (Artist, Album, Cover Artwork URL)
    public var audioArtist: String?
    public var audioAlbum: String?
    public var audioCoverURL: String?

    public init(
        id: UUID = UUID(),
        title: String,
        sourceHost: String,
        urlString: String,
        kind: DownloadKind,
        formatLabel: String,
        qualityLabel: String,
        totalBytes: Int64,
        downloadedBytes: Int64 = 0,
        state: DownloadState = .queued,
        connectionCount: Int = 16,
        addedAt: Date = Date(),
        completedAt: Date? = nil,
        destinationFolder: String = "~/Downloads/Edit.or.lynx",
        isTurbo: Bool = false,
        baseSpeedPerConnection: Double = 2_600_000,
        currentSpeed: Double = 0,
        speedSamples: [Double] = [],
        clipSummary: String? = nil,
        autoDelete: Bool = false,
        seed: Int = 0,
        errorMessage: String? = nil,
        filePath: String? = nil,
        liveTransfer: Bool? = nil,
        clipStart: Double? = nil,
        clipEnd: Double? = nil,
        statusHint: String? = nil,
        audioArtist: String? = nil,
        audioAlbum: String? = nil,
        audioCoverURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceHost = sourceHost
        self.urlString = urlString
        self.kind = kind
        self.formatLabel = formatLabel
        self.qualityLabel = qualityLabel
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.state = state
        self.connectionCount = connectionCount
        self.addedAt = addedAt
        self.completedAt = completedAt
        self.destinationFolder = destinationFolder
        self.isTurbo = isTurbo
        self.baseSpeedPerConnection = baseSpeedPerConnection
        self.currentSpeed = currentSpeed
        self.speedSamples = speedSamples
        self.clipSummary = clipSummary
        self.autoDelete = autoDelete
        self.seed = seed
        self.errorMessage = errorMessage
        self.filePath = filePath
        self.liveTransfer = liveTransfer
        self.clipStart = clipStart
        self.clipEnd = clipEnd
        self.statusHint = statusHint
        self.audioArtist = audioArtist
        self.audioAlbum = audioAlbum
        self.audioCoverURL = audioCoverURL
    }

    public var progress: Double {
        if statusHint != nil { return 1.0 }
        guard totalBytes > 0 else { return state == .completed ? 1 : 0 }
        return min(1, max(0, Double(downloadedBytes) / Double(totalBytes)))
    }

    /// False while the server hasn't declared a length; the UI must not guess a percentage then.
    public var hasKnownSize: Bool { totalBytes > 0 }

    /// A percentage only when one is known: `nil` renders as "—".
    public var percentText: String? {
        if statusHint != nil { return "100%" }
        guard hasKnownSize, state != .queued else { return nil }
        return Fmt.percent(progress)
    }

    /// "12.4 MB of 80 MB" when the total is known, else just what has arrived.
    public var sizeProgressText: String {
        let done = Fmt.bytes(Double(max(0, downloadedBytes)))
        guard hasKnownSize else { return done }
        return "\(done) of \(sizeText)"
    }

    /// True for items whose bytes are fetched from the network.
    public var isLive: Bool { liveTransfer == true }

    public var remainingBytes: Int64 {
        max(0, totalBytes - downloadedBytes)
    }

    public var eta: TimeInterval? {
        guard state == .downloading, currentSpeed > 1, hasKnownSize else { return nil }
        let remaining = Double(remainingBytes)
        guard remaining > 1 else { return nil }
        return min(remaining / currentSpeed, 7 * 24 * 60 * 60)
    }

    public var sizeText: String { Fmt.bytes(Double(totalBytes)) }

    public var detailLine: String {
        var parts: [String] = [kind.displayName]
        if qualityLabel != "—" { parts.append(qualityLabel) }
        if kind != .audio { parts.append(formatLabel) }
        parts.append(sizeText)
        parts.append(sourceHost)
        return parts.joined(separator: " • ")
    }

    public var activeDetailLine: String {
        guard state == .downloading else {
            if state == .paused { return "Paused • \(sizeProgressText)" }
            if state == .queued { return hasKnownSize ? "Waiting • \(sizeText)" : "Waiting" }
            if state == .failed { return errorMessage ?? "Download failed" }
            return detailLine
        }
        if let hint = statusHint, !hint.isEmpty {
            return "\(sizeProgressText) • \(hint)"
        }
        var parts: [String] = [hasKnownSize ? sizeProgressText : Fmt.bytes(Double(downloadedBytes))]
        if currentSpeed > 1 {
            parts.append(Fmt.speed(currentSpeed))
        }
        if isTurbo { parts.append("Turbo") }
        if let eta { parts.append(Fmt.eta(eta)) }
        return parts.joined(separator: " • ")
    }

    /// "0 B of 120 MB" for a download whose server never declared a size.
    public var unknownSizeDetailLine: String {
        "\(sizeProgressText) • \(Fmt.speed(currentSpeed))"
    }

    public var displayTime: String {
        Fmt.timestamp(completedAt ?? addedAt)
    }

    public var streamingSamples: [Double] {
        if speedSamples.isEmpty {
            return Array(repeating: 0, count: 28)
        }
        return speedSamples
    }
}

// MARK: - Links and qualities

public enum LinkKind: String, Codable {
    case video
    case audio
    case file
    case playlist
}

public struct QualityOption: Identifiable, Hashable, Codable {
    public var label: String
    public var sublabel: String
    public var bytes: Int64
    public var recommended: Bool

    public var id: String { label }

    public init(label: String, sublabel: String, bytes: Int64, recommended: Bool = false) {
        self.label = label
        self.sublabel = sublabel
        self.bytes = bytes
        self.recommended = recommended
    }

    public var sizeText: String { Fmt.bytes(Double(bytes)) }
}

public struct PlaylistVideo: Identifiable, Hashable, Codable {
    public var id: UUID
    public var title: String
    public var duration: TimeInterval
    public var bytes: Int64

    public init(id: UUID = UUID(), title: String, duration: TimeInterval, bytes: Int64) {
        self.id = id
        self.title = title
        self.duration = duration
        self.bytes = bytes
    }

    public var durationText: String { Fmt.duration(duration) }
}

public struct PlaylistInfo: Hashable, Codable {
    public var title: String
    public var creator: String
    public var videos: [PlaylistVideo]
    public var sourceHost: String

    public init(title: String, creator: String, videos: [PlaylistVideo], sourceHost: String) {
        self.title = title
        self.creator = creator
        self.videos = videos
        self.sourceHost = sourceHost
    }

    public var totalDuration: TimeInterval { videos.reduce(0) { $0 + $1.duration } }
    public var totalBytes: Int64 { videos.reduce(0) { $0 + $1.bytes } }
    public var durationText: String { Fmt.duration(totalDuration) }
}

public struct LinkInfo: Identifiable, Equatable {
    public var id = UUID()
    public var url: URL
    public var host: String
    public var title: String
    public var kind: LinkKind
    public var duration: TimeInterval?
    public var fullBytes: Int64
    public var qualities: [QualityOption]
    public var playlist: PlaylistInfo?
    public var thumbSeed: Int

    public init(
        url: URL,
        host: String,
        title: String,
        kind: LinkKind,
        duration: TimeInterval? = nil,
        fullBytes: Int64,
        qualities: [QualityOption] = [],
        playlist: PlaylistInfo? = nil,
        thumbSeed: Int = 0
    ) {
        self.url = url
        self.host = host
        self.title = title
        self.kind = kind
        self.duration = duration
        self.fullBytes = fullBytes
        self.qualities = qualities
        self.playlist = playlist
        self.thumbSeed = thumbSeed
    }

    public var durationText: String {
        guard let duration else { return "Link" }
        return Fmt.duration(duration)
    }

    public var suggestedFileName: String {
        let ext: String
        switch kind {
        case .video: ext = "mp4"
        case .audio: ext = "m4a"
        case .file:
            if !url.pathExtension.isEmpty {
                ext = url.pathExtension.lowercased()
            } else {
                let lowerStr = url.absoluteString.lowercased()
                if lowerStr.contains("oaiusercontent") || lowerStr.contains("image") || lowerStr.contains("dall-e") || lowerStr.contains("png") {
                    ext = "png"
                } else if lowerStr.contains("webp") {
                    ext = "webp"
                } else if lowerStr.contains("jpeg") || lowerStr.contains("jpg") {
                    ext = "jpg"
                } else {
                    ext = "bin"
                }
            }
        case .playlist: ext = "zip"
        }
        var base = title.replacingOccurrences(of: "/", with: "-")
        base = base.replacingOccurrences(of: ":", with: " -")
        if base.lowercased().hasSuffix(".\(ext.lowercased())") { return base }
        return "\(base).\(ext)"
    }

    public static func == (lhs: LinkInfo, rhs: LinkInfo) -> Bool {
        lhs.url == rhs.url && lhs.title == rhs.title && lhs.kind == rhs.kind
    }
}

// MARK: - Clips

public enum ClipFormat: String, Codable, CaseIterable, Identifiable {
    case video
    case vertical
    case square
    case gif
    case audio

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .video: return "Video"
        case .vertical: return "Vertical"
        case .square: return "Square"
        case .gif: return "GIF"
        case .audio: return "Audio"
        }
    }

    public var sublabel: String {
        switch self {
        case .video: return "16:9"
        case .vertical: return "9:16"
        case .square: return "1:1"
        case .gif: return "15 fps"
        case .audio: return "MP3"
        }
    }

    public var symbol: String {
        switch self {
        case .video: return "rectangle"
        case .vertical: return "rectangle.portrait"
        case .square: return "square"
        case .gif: return "photo.stack"
        case .audio: return "waveform"
        }
    }

    public var sizeMultiplier: Double {
        switch self {
        case .video: return 1
        case .vertical: return 0.62
        case .square: return 0.44
        case .gif: return 0.85
        case .audio: return 0.07
        }
    }

    public var fileExtension: String {
        self == .audio ? "mp3" : (self == .gif ? "gif" : "mp4")
    }
}

public struct ClipPart: Identifiable, Hashable, Codable {
    public var id: UUID
    public var start: TimeInterval
    public var end: TimeInterval

    public init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval) {
        self.id = id
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { max(0, end - start) }
}

public struct ClipSelection: Equatable {
    public var parts: [ClipPart]
    public var format: ClipFormat
    public var qualityLabel: String
    public var subtitles: Bool
    public var audioOnly: Bool

    public init(
        parts: [ClipPart],
        format: ClipFormat = .video,
        qualityLabel: String = "1080p",
        subtitles: Bool = false,
        audioOnly: Bool = false
    ) {
        self.parts = parts
        self.format = format
        self.qualityLabel = qualityLabel
        self.subtitles = subtitles
        self.audioOnly = audioOnly
    }

    public var totalSeconds: TimeInterval { parts.reduce(0) { $0 + $1.duration } }

    public var partsSummary: String {
        let list = parts.map { "\(Fmt.clock($0.start))–\(Fmt.clock($0.end))" }.joined(separator: ", ")
        return "\(list) • \(Fmt.shortDuration(totalSeconds)) • \(format.title)"
    }

    public func estimatedBytes(fullBytes: Int64, fullDuration: TimeInterval, qualityMultiplier: Double) -> Int64 {
        guard fullDuration > 0 else { return Int64(Double(fullBytes) * 0.1) }
        let ratio = min(1, totalSeconds / fullDuration)
        let bytes = Double(fullBytes) * ratio * format.sizeMultiplier * qualityMultiplier
        return max(180_000, Int64(bytes))
    }
}

// MARK: - Clipboard and shelf

public enum ClipboardKind: String, Codable {
    case text
    case link
    case color

    public var label: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .color: return "Color"
        }
    }

    public var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette"
        }
    }
}

public struct ClipboardEntry: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var kind: ClipboardKind
    public var sourceApp: String?
    public var sourceBundleID: String?
    public var capturedAt: Date
    public var pinned: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        kind: ClipboardKind,
        sourceApp: String? = nil,
        sourceBundleID: String? = nil,
        capturedAt: Date = Date(),
        pinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.kind = kind
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
        self.pinned = pinned
    }

    public var displayText: String {
        text.replacingOccurrences(of: "\n", with: " ")
    }

    public var sourceLine: String {
        let source = sourceApp ?? "Clipboard"
        return "\(source) • \(Fmt.relative(capturedAt))"
    }
}

public struct ShelfItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var path: String
    public var name: String
    public var addedAt: Date

    public init(id: UUID = UUID(), path: String, name: String, addedAt: Date = Date()) {
        self.id = id
        self.path = path
        self.name = name
        self.addedAt = addedAt
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var fileExtension: String { url.pathExtension.uppercased() }
}

// MARK: - Detail helpers

public extension DownloadItem {
    var piecesTotal: Int {
        max(1, min(9_600, Int(totalBytes / 980_000)))
    }

    var piecesDone: Int {
        Int((progress * Double(piecesTotal)).rounded())
    }

    var connectionsSummary: String {
        "\(connectionCount) connections"
    }

    var savingToDisplay: String {
        destinationFolder.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var fileURL: URL? {
        filePath.map { URL(fileURLWithPath: $0) }
    }
}
