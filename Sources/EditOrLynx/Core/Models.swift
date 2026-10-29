import Foundation
import SwiftUI

// MARK: - Download State
public enum DownloadState: String, Codable, CaseIterable, Sendable {
    case idle
    case connecting
    case downloading
    case paused
    case completed
    case failed
    case cancelled

    public var title: String {
        switch self {
        case .idle:        return "Waiting"
        case .connecting:  return "Connecting…"
        case .downloading: return "Downloading"
        case .paused:      return "Paused"
        case .completed:   return "Completed"
        case .failed:      return "Failed"
        case .cancelled:   return "Cancelled"
        }
    }

    public var isActive: Bool {
        self == .connecting || self == .downloading
    }

    public var isTerminal: Bool {
        self == .completed || self == .cancelled
    }
}

// MARK: - File Category
public enum FileCategory: String, Codable, CaseIterable, Sendable {
    case video
    case audio
    case archive
    case document
    case app
    case image
    case torrent
    case gdrive
    case other

    public var iconName: String {
        switch self {
        case .video:    return "play.rectangle.fill"
        case .audio:    return "waveform"
        case .archive:  return "archivebox.fill"
        case .document: return "doc.text.fill"
        case .app:      return "app.badge.fill"
        case .image:    return "photo.fill"
        case .torrent:  return "arrow.triangle.swap"
        case .gdrive:   return "externaldrive.fill.badge.icloud"
        case .other:    return "arrow.down.doc.fill"
        }
    }

    public var color: Color {
        switch self {
        case .video:    return .purple
        case .audio:    return .pink
        case .archive:  return .orange
        case .document: return .blue
        case .app:      return .teal
        case .image:    return .green
        case .torrent:  return .indigo
        case .gdrive:   return .yellow
        case .other:    return .gray
        }
    }

    public static func detect(url: URL, suggestedFilename: String? = nil) -> FileCategory {
        let name = (suggestedFilename ?? url.lastPathComponent).lowercased()
        let ext = (name as NSString).pathExtension.lowercased()

        if url.absoluteString.lowercased().hasPrefix("magnet:") || ext == "torrent" {
            return .torrent
        }
        if url.host?.contains("drive.google.com") == true {
            return .gdrive
        }

        switch ext {
        case "mp4", "mkv", "mov", "avi", "webm", "m4v":
            return .video
        case "mp3", "flac", "aac", "wav", "m4a", "ogg", "alac":
            return .audio
        case "zip", "tar", "gz", "rar", "7z", "bz2", "xz":
            return .archive
        case "pdf", "epub", "docx", "xlsx", "pptx", "txt", "md":
            return .document
        case "dmg", "pkg", "app", "iso":
            return .app
        case "jpg", "jpeg", "png", "gif", "webp", "svg", "heic":
            return .image
        default:
            return .other
        }
    }
}

// MARK: - Download Item
public struct DownloadItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var url: URL
    public var filename: String
    public var totalBytes: Int64
    public var downloadedBytes: Int64
    public var speed: Double // Bytes per second
    public var state: DownloadState
    public var category: FileCategory
    public var destinationURL: URL
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var errorMessage: String?
    public var connections: Int
    public var isBatch: Bool
    public var batchFileCount: Int

    public init(
        id: UUID = UUID(),
        url: URL,
        filename: String? = nil,
        totalBytes: Int64 = 0,
        downloadedBytes: Int64 = 0,
        speed: Double = 0,
        state: DownloadState = .idle,
        category: FileCategory? = nil,
        destinationURL: URL? = nil,
        dateAdded: Date = Date(),
        connections: Int = 16,
        isBatch: Bool = false,
        batchFileCount: Int = 1
    ) {
        self.id = id
        self.url = url
        let detectedName = filename ?? url.lastPathComponent.removingPercentEncoding ?? "download"
        self.filename = detectedName.isEmpty ? "file_\(id.uuidString.prefix(6))" : detectedName
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.speed = speed
        self.state = state
        self.category = category ?? FileCategory.detect(url: url, suggestedFilename: filename)
        
        let defaultFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        self.destinationURL = destinationURL ?? defaultFolder.appendingPathComponent(self.filename)
        
        self.dateAdded = dateAdded
        self.dateCompleted = nil
        self.errorMessage = nil
        self.connections = connections
        self.isBatch = isBatch
        self.batchFileCount = batchFileCount
    }

    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, max(0.0, Double(downloadedBytes) / Double(totalBytes)))
    }

    public var etaSeconds: TimeInterval? {
        guard speed > 1024, totalBytes > downloadedBytes else { return nil }
        let remaining = Double(totalBytes - downloadedBytes)
        return remaining / speed
    }
}

// MARK: - Offering & Media Models
public enum LinkKind: String, Codable, Sendable {
    case video
    case audio
    case file
    case playlist
}

public struct QualityOption: Identifiable, Hashable, Codable, Sendable {
    public var label: String
    public var sublabel: String
    public var bytes: Int64
    public var recommended: Bool

    public var id: String { label }

    public init(label: String, sublabel: String = "", bytes: Int64 = 0, recommended: Bool = false) {
        self.label = label
        self.sublabel = sublabel
        self.bytes = bytes
        self.recommended = recommended
    }

    public var sizeText: String { Formatters.bytes(bytes) }
}

public struct LinkInfo: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var url: URL
    public var host: String
    public var title: String
    public var kind: LinkKind
    public var duration: TimeInterval?
    public var fullBytes: Int64
    public var qualities: [QualityOption]

    public init(
        id: UUID = UUID(),
        url: URL,
        host: String = "",
        title: String = "",
        kind: LinkKind = .video,
        duration: TimeInterval? = nil,
        fullBytes: Int64 = 0,
        qualities: [QualityOption] = []
    ) {
        self.id = id
        self.url = url
        self.host = host.isEmpty ? (url.host ?? "") : host
        self.title = title.isEmpty ? (url.lastPathComponent.removingPercentEncoding ?? "Media") : title
        self.kind = kind
        self.duration = duration
        self.fullBytes = fullBytes
        self.qualities = qualities
    }

    public var durationText: String {
        guard let duration, duration > 0 else { return "Media Link" }
        let total = Int(duration)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
