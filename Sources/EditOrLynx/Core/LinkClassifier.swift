import Foundation

public enum LinkType: Equatable {
    case direct(url: URL, filename: String)
    case googleDrive(url: URL, isFolder: Bool, id: String)
    case torrent(magnet: String?, torrentURL: URL?)
    case mediaStream(url: URL, title: String?)
    case unknown(url: URL)
}

public struct LinkClassifier {
    public static func classify(_ rawURL: String) -> LinkType {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown(url: URL(string: "about:blank")!) }

        // Magnet Link
        if trimmed.lowercased().hasPrefix("magnet:") {
            return .torrent(magnet: trimmed, torrentURL: nil)
        }

        guard let url = URL(string: trimmed) else {
            return .unknown(url: URL(string: "about:blank")!)
        }

        // Torrent file
        if url.pathExtension.lowercased() == "torrent" {
            return .torrent(magnet: nil, torrentURL: url)
        }

        // Google Drive
        let host = url.host?.lowercased() ?? ""
        if host.contains("drive.google.com") || host.contains("docs.google.com") {
            let path = url.path
            if path.contains("/folders/") {
                let id = url.lastPathComponent
                return .googleDrive(url: url, isFolder: true, id: id)
            } else if path.contains("/file/d/") {
                let parts = path.components(separatedBy: "/file/d/")
                let id = parts.count > 1 ? parts[1].components(separatedBy: "/")[0] : url.lastPathComponent
                return .googleDrive(url: url, isFolder: false, id: id)
            } else if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value {
                return .googleDrive(url: url, isFolder: false, id: id)
            }
        }

        // Media streaming (YouTube, Vimeo, Soundcloud, etc.)
        if host.contains("youtube.com") || host.contains("youtu.be") || host.contains("vimeo.com") || host.contains("soundcloud.com") {
            return .mediaStream(url: url, title: nil)
        }

        // Direct HTTP/HTTPS download
        let filename = url.lastPathComponent.removingPercentEncoding ?? "download"
        return .direct(url: url, filename: filename.isEmpty ? "file" : filename)
    }
}
