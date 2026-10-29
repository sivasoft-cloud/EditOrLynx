import Foundation
import AppKit
import PounceCore

public struct SpotifyTrackItem: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var artist: String
    public var album: String
    public var coverURL: URL?
    public var durationSeconds: Double
    public var spotifyURL: URL

    public var searchQuery: String {
        if !artist.isEmpty && !title.lowercased().contains(artist.lowercased()) {
            return "ytsearch1:\(artist) - \(title) audio"
        }
        return "ytsearch1:\(title) audio"
    }

    public init(
        id: String,
        title: String,
        artist: String = "",
        album: String = "",
        coverURL: URL? = nil,
        durationSeconds: Double = 0,
        spotifyURL: URL
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.coverURL = coverURL
        self.durationSeconds = durationSeconds
        self.spotifyURL = spotifyURL
    }
}

public struct SpotifyCollectionResult {
    public var id: String
    public var title: String
    public var artist: String
    public var coverURL: URL?
    public var tracks: [SpotifyTrackItem]
    public var type: String // "album" or "playlist"

    public init(id: String, title: String, artist: String = "", coverURL: URL? = nil, tracks: [SpotifyTrackItem], type: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.coverURL = coverURL
        self.tracks = tracks
        self.type = type
    }
}

@MainActor
public final class SpotifyService {
    public static let shared = SpotifyService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Link Detection

    public static func isSpotify(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        if host.contains("spotify.com") || url.scheme == "spotify" {
            return true
        }
        return false
    }

    private static func extractID(after marker: String, in path: String) -> String? {
        guard let range = path.range(of: marker) else { return nil }
        let rest = String(path[range.upperBound...])
        let firstSegment = rest.components(separatedBy: "/").first ?? ""
        let cleanID = firstSegment.components(separatedBy: "?").first ?? ""
        return cleanID.isEmpty ? nil : cleanID
    }

    public static func parseSpotifyType(url: URL) -> (type: String, id: String)? {
        let path = url.path
        if let id = extractID(after: "/track/", in: path) {
            return ("track", id)
        }
        if let id = extractID(after: "/album/", in: path) {
            return ("album", id)
        }
        if let id = extractID(after: "/playlist/", in: path) {
            return ("playlist", id)
        }
        if url.scheme == "spotify" {
            let parts = url.absoluteString.components(separatedBy: ":")
            if parts.count >= 3 {
                return (parts[1], parts[2])
            }
        }
        return nil
    }

    // MARK: - Resolve Track

    public func resolveTrack(url: URL) async throws -> SpotifyTrackItem {
        guard let (type, id) = Self.parseSpotifyType(url: url) else {
            throw NSError(domain: "Spotify", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Spotify link."])
        }

        let cleanURL = "https://open.spotify.com/track/\(id)"
        guard let oembedURL = URL(string: "https://open.spotify.com/oembed?url=\(cleanURL)") else {
            throw NSError(domain: "Spotify", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not create Spotify oEmbed query."])
        }

        var req = URLRequest(url: oembedURL)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Spotify", code: 404, userInfo: [NSLocalizedDescriptionKey: "Spotify track not found."])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Spotify", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Spotify response."])
        }

        let rawTitle = (json["title"] as? String) ?? "Spotify Track"
        let coverStr = json["thumbnail_url"] as? String
        let coverURL = coverStr.flatMap(URL.init(string:))

        // Also fetch track page for artist and album name
        var artist = ""
        var album = ""
        var cleanTitle = rawTitle

        if let trackPageURL = URL(string: cleanURL) {
            var pageReq = URLRequest(url: trackPageURL)
            pageReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            if let (pageData, _) = try? await session.data(for: pageReq),
               let html = String(data: pageData, encoding: .utf8) {
                if let a = extractMeta(property: "music:musician_description", html: html) ?? extractMeta(name: "twitter:audio:artist_name", html: html) {
                    artist = a
                }
                if let alb = extractMeta(property: "music:album", html: html) {
                    album = alb
                }
                if let ogTitle = extractMeta(property: "og:title", html: html), !ogTitle.isEmpty {
                    cleanTitle = ogTitle
                }
                if let desc = extractMeta(property: "og:description", html: html), artist.isEmpty {
                    let parts = desc.components(separatedBy: " · ")
                    if let first = parts.first, !first.isEmpty {
                        artist = first
                    }
                }
            }
        }

        if artist.isEmpty && cleanTitle.contains(" - ") {
            let parts = cleanTitle.components(separatedBy: " - ")
            artist = parts[0].trimmingCharacters(in: .whitespaces)
            cleanTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
        }

        return SpotifyTrackItem(
            id: id,
            title: cleanTitle,
            artist: artist,
            album: album,
            coverURL: coverURL,
            durationSeconds: 210,
            spotifyURL: url
        )
    }

    // MARK: - Resolve Album or Playlist

    public func resolveAlbumOrPlaylist(url: URL) async throws -> SpotifyCollectionResult {
        guard let (type, id) = Self.parseSpotifyType(url: url), type == "album" || type == "playlist" else {
            throw NSError(domain: "Spotify", code: 400, userInfo: [NSLocalizedDescriptionKey: "Not a Spotify album or playlist."])
        }

        let embedURLStr = "https://open.spotify.com/embed/\(type)/\(id)"
        guard let embedURL = URL(string: embedURLStr) else {
            throw NSError(domain: "Spotify", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid embed URL."])
        }

        var req = URLRequest(url: embedURL)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Spotify", code: 404, userInfo: [NSLocalizedDescriptionKey: "Spotify collection not found."])
        }

        // Parse <script id="__NEXT_DATA__" type="application/json">
        guard let startRange = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let endRange = html[startRange.upperBound...].range(of: "</script>") else {
            throw NSError(domain: "Spotify", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not parse Spotify embed structure."])
        }

        let jsonStr = String(html[startRange.upperBound..<endRange.lowerBound])
        guard let jsonData = jsonStr.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let props = root["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let dataObj = state["data"] as? [String: Any],
              let entity = dataObj["entity"] as? [String: Any] else {
            throw NSError(domain: "Spotify", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not read Spotify tracks."])
        }

        let title = (entity["name"] as? String) ?? (type == "album" ? "Spotify Album" : "Spotify Playlist")
        let artist = (entity["subtitle"] as? String) ?? ""
        var coverURL: URL? = nil
        if let coverArt = entity["coverArt"] as? [String: Any],
           let sources = coverArt["sources"] as? [[String: Any]],
           let firstSource = sources.first,
           let u = firstSource["url"] as? String {
            coverURL = URL(string: u)
        }

        var tracks: [SpotifyTrackItem] = []
        if let trackList = entity["trackList"] as? [[String: Any]] {
            for t in trackList {
                let tTitle = (t["title"] as? String) ?? "Track"
                let tArtist = (t["subtitle"] as? String) ?? artist
                let uri = (t["uri"] as? String) ?? ""
                let tID = uri.split(separator: ":").last.map(String.init) ?? UUID().uuidString
                let dur = Double((t["duration"] as? Int) ?? 200_000) / 1000.0

                let item = SpotifyTrackItem(
                    id: tID,
                    title: tTitle,
                    artist: tArtist,
                    album: title,
                    coverURL: coverURL,
                    durationSeconds: dur,
                    spotifyURL: URL(string: "https://open.spotify.com/track/\(tID)")!
                )
                tracks.append(item)
            }
        }

        return SpotifyCollectionResult(
            id: id,
            title: title,
            artist: artist,
            coverURL: coverURL,
            tracks: tracks,
            type: type
        )
    }

    private func extractMeta(property: String, html: String) -> String? {
        let pattern = #"<meta\s+property=[\"']\#(property)[\"']\s+content=[\"']([^\"']+)[\"']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges >= 2 {
            return (html as NSString).substring(with: match.range(at: 1))
        }
        return nil
    }

    private func extractMeta(name: String, html: String) -> String? {
        let pattern = #"<meta\s+name=[\"']\#(name)[\"']\s+content=[\"']([^\"']+)[\"']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges >= 2 {
            return (html as NSString).substring(with: match.range(at: 1))
        }
        return nil
    }
}
