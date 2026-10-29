import Foundation
import AppKit
import PounceCore

public struct GoogleDriveFileItem: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var size: Int64
    public var downloadURL: URL
    public var mimeType: String?

    public init(id: String, name: String, size: Int64, downloadURL: URL, mimeType: String? = nil) {
        self.id = id
        self.name = name
        self.size = size
        self.downloadURL = downloadURL
        self.mimeType = mimeType
    }
}

public struct GoogleDriveFolderResult {
    public var folderID: String
    public var title: String
    public var files: [GoogleDriveFileItem]
    public var totalBytes: Int64
    public var zipDownloadURL: URL?

    public init(folderID: String, title: String, files: [GoogleDriveFileItem], totalBytes: Int64, zipDownloadURL: URL? = nil) {
        self.folderID = folderID
        self.title = title
        self.files = files
        self.totalBytes = totalBytes
        self.zipDownloadURL = zipDownloadURL
    }
}

public enum GoogleDriveURLType: Equatable {
    case file(id: String)
    case folder(id: String)
    case none
}

@MainActor
public final class GoogleDriveService {
    public static let shared = GoogleDriveService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60 * 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - URL Parsing

    public static func isGoogleDrive(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("drive.google.com") || host.contains("docs.google.com") || host.contains("googleusercontent.com")
    }

    public static func parse(url: URL) -> GoogleDriveURLType {
        guard isGoogleDrive(url: url) else { return .none }

        let path = url.path
        let query = url.query ?? ""

        // Folder URLs:
        // https://drive.google.com/drive/folders/1aBcDeFg...
        // https://drive.google.com/drive/u/0/folders/1aBcDeFg...
        if let range = path.range(of: "/folders/") {
            let rest = String(path[range.upperBound...])
            let id = rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
            if !id.isEmpty { return .folder(id: id) }
        }

        // File URLs:
        // https://drive.google.com/file/d/1aBcDeFg.../view
        if let range = path.range(of: "/file/d/") {
            let rest = String(path[range.upperBound...])
            let id = rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
            if !id.isEmpty { return .file(id: id) }
        }

        // Query param id=
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 && parts[0].lowercased() == "id" {
                let id = String(parts[1])
                if !id.isEmpty {
                    if path.contains("folder") {
                        return .folder(id: id)
                    }
                    return .file(id: id)
                }
            }
        }

        return .none
    }

    // MARK: - Direct File URL

    public static func directDownloadURL(for fileID: String) -> URL {
        URL(string: "https://drive.usercontent.google.com/download?id=\(fileID)&export=download&confirm=t")!
    }

    public static func directDownloadURL(fileID: String) -> URL {
        directDownloadURL(for: fileID)
    }

    // MARK: - Virus Warning & Download Confirmation Extraction

    /// Parses Google Drive large file warning pages to find the direct download URL with bypass token.
    public static func extractConfirmURL(html: String, originalURL: URL) -> URL? {
        // 1. Look for href on uc-download-link or containing confirm= / export=download
        let hrefPatterns = [
            #"id=[\"']uc-download-link[\"'][^>]*?href=[\"']([^\"']+)[\"']"#,
            #"href=[\"']([^\"']+)[\"'][^>]*?id=[\"']uc-download-link[\"']"#,
            #"href=[\"'](https?://drive\.(?:usercontent\.)?google\.com/[^\"']*?confirm=[^\"']+)[\"']"#,
            #"href=[\"'](/uc\?[^\"']*?confirm=[^\"']+)[\"']"#
        ]
        for pattern in hrefPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
               match.numberOfRanges >= 2 {
                let matched = (html as NSString).substring(with: match.range(at: 1))
                let unescaped = matched.replacingOccurrences(of: "&amp;", with: "&")
                if let targetURL = URL(string: unescaped, relativeTo: URL(string: "https://drive.google.com"))?.absoluteURL {
                    return targetURL
                }
            }
        }

        // 2. Look for download-form with action and hidden inputs
        if html.contains("download-form") || html.contains("uc-download-link") || html.contains("confirm=") {
            var actionURLStr = "https://drive.usercontent.google.com/download"
            let formActionPattern = #"<form[^>]*?action=[\"']([^\"']+)[\"']"#
            if let regex = try? NSRegularExpression(pattern: formActionPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
               match.numberOfRanges >= 2 {
                actionURLStr = (html as NSString).substring(with: match.range(at: 1)).replacingOccurrences(of: "&amp;", with: "&")
            }

            // Extract hidden inputs
            let inputPattern = #"<input[^>]*?type=[\"']hidden[\"'][^>]*?name=[\"']([^\"']+)[\"'][^>]*?value=[\"']([^\"']*)[\"']"#
            let inputPatternRev = #"<input[^>]*?value=[\"']([^\"']*)[\"'][^>]*?name=[\"']([^\"']+)[\"']"#
            
            var queryParams: [String: String] = [:]
            if let regex = try? NSRegularExpression(pattern: inputPattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
                for m in matches where m.numberOfRanges >= 3 {
                    let name = (html as NSString).substring(with: m.range(at: 1))
                    let val = (html as NSString).substring(with: m.range(at: 2))
                    queryParams[name] = val
                }
            }
            if let regexRev = try? NSRegularExpression(pattern: inputPatternRev, options: .caseInsensitive) {
                let matches = regexRev.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
                for m in matches where m.numberOfRanges >= 3 {
                    let val = (html as NSString).substring(with: m.range(at: 1))
                    let name = (html as NSString).substring(with: m.range(at: 2))
                    if queryParams[name] == nil { queryParams[name] = val }
                }
            }

            if !queryParams.isEmpty {
                var comp = URLComponents(string: actionURLStr) ?? URLComponents(string: "https://drive.usercontent.google.com/download")!
                var items = comp.queryItems ?? []
                for (k, v) in queryParams {
                    items.append(URLQueryItem(name: k, value: v))
                }
                comp.queryItems = items
                if let built = comp.url {
                    return built
                }
            }
        }

        // 3. Fallback: if original URL had a file ID, craft the direct download URL with confirm=t
        if case .file(let id) = parse(url: originalURL) {
            let direct = directDownloadURL(for: id)
            if direct.absoluteString != originalURL.absoluteString {
                return direct
            }
        }

        return nil
    }

    // MARK: - Resolving Folder Files & Metadata

    /// Resolves folder contents by combining the full embedded directory tree (which lists all files and
    /// traverses subfolders without the 50-item limit) and the web client metadata (for exact byte sizes).
    public func resolveFolder(url: URL) async throws -> GoogleDriveFolderResult {
        let parsed = Self.parse(url: url)
        let folderID: String
        switch parsed {
        case .folder(let id):
            folderID = id
        case .file(let id):
            folderID = id
        case .none:
            throw NSError(domain: "GoogleDrive", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Google Drive folder link."])
        }

        var folderTitle = "Google Drive Folder"
        var items: [GoogleDriveFileItem] = []

        // Method 1: Fetch embedded directory tree (bypasses 50-file limit and recursively traverses subfolders)
        let (embeddedTitle, embeddedFiles) = await fetchEmbeddedFolder(folderID: folderID, prefix: "", depth: 0)
        if !embeddedTitle.isEmpty {
            folderTitle = embeddedTitle
        }
        if !embeddedFiles.isEmpty {
            items = embeddedFiles
        }

        // Method 2: Fetch web client HTML to capture exact byte sizes or any additional top-level files
        let folderWebURL = URL(string: "https://drive.google.com/drive/folders/\(folderID)?usp=sharing")!
        var request = URLRequest(url: folderWebURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let html = String(data: data, encoding: .utf8) {
                if let titleMatch = extractTitle(from: html), folderTitle == "Google Drive Folder" {
                    folderTitle = titleMatch
                }
                let webFiles = parseFilesFromHTML(html: html, folderID: folderID)
                
                // Merge exact sizes from webFiles into items
                var exactSizes: [String: Int64] = [:]
                for wf in webFiles {
                    exactSizes[wf.id] = wf.size
                }
                for i in 0..<items.count {
                    if let exact = exactSizes[items[i].id], exact > 0 {
                        items[i].size = exact
                    }
                }
                
                // Add any files found in webFiles that were missed in embedded
                let existingIDs = Set(items.map(\.id))
                for wf in webFiles where !existingIDs.contains(wf.id) {
                    items.append(wf)
                }
            }
        } catch {
            // Ignore error
        }

        // Method 3: Fallback to yt-dlp if still empty
        if items.isEmpty, let ytdlp = TransferService.tool("yt-dlp") {
            if let result = await runYtDlpDump(tool: ytdlp, url: url, folderID: folderID) {
                if !result.files.isEmpty {
                    return result
                }
                if !result.title.isEmpty && folderTitle == "Google Drive Folder" {
                    folderTitle = result.title
                }
            }
        }

        // If items are still empty, create a single archive item allowing the user to initiate zip download
        let zipURL = URL(string: "https://drive.google.com/drive/folders/\(folderID)?export=download")
        if items.isEmpty {
            let fallbackItem = GoogleDriveFileItem(
                id: folderID,
                name: "\(folderTitle).zip",
                size: 70_000_000_000,
                downloadURL: zipURL ?? url,
                mimeType: "application/zip"
            )
            items = [fallbackItem]
        }

        let totalSize = items.reduce(0) { $0 + $1.size }

        return GoogleDriveFolderResult(
            folderID: folderID,
            title: folderTitle,
            files: items,
            totalBytes: totalSize > 0 ? totalSize : 70_000_000_000,
            zipDownloadURL: zipURL
        )
    }

    /// Recursively traverses Google Drive's embedded folder view to retrieve all files without the 50-file cap.
    private func fetchEmbeddedFolder(folderID: String, prefix: String, depth: Int) async -> (title: String, items: [GoogleDriveFileItem]) {
        guard depth < 8 else { return ("", []) }
        guard let url = URL(string: "https://drive.google.com/embeddedfolderview?id=\(folderID)#list") else { return ("", []) }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return ("", [])
        }

        var folderTitle = ""
        if let titleRange = html.range(of: "<title>") {
            let rest = html[titleRange.upperBound...]
            if let endRange = rest.range(of: "</title>") {
                folderTitle = String(rest[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        var items: [GoogleDriveFileItem] = []
        var subfolders: [(id: String, name: String)] = []

        let pattern = #"<a[^>]+href=[\"']([^\"']+)[\"'][^>]*>[\s\S]*?<div class=[\"']flip-entry-title[\"']>([^<]+)</div>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                guard m.numberOfRanges >= 3 else { continue }
                let href = ns.substring(with: m.range(at: 1))
                var name = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                name = name.replacingOccurrences(of: "&amp;", with: "&")
                           .replacingOccurrences(of: "&quot;", with: "\"")
                           .replacingOccurrences(of: "&#39;", with: "'")
                           .replacingOccurrences(of: "&lt;", with: "<")
                           .replacingOccurrences(of: "&gt;", with: ">")

                // Direct file
                if let fileRange = href.range(of: "/file/d/") {
                    let rest = href[fileRange.upperBound...]
                    let fid = rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
                    if !fid.isEmpty {
                        let fullName = prefix.isEmpty ? name : "\(prefix)\(name)"
                        let direct = Self.directDownloadURL(fileID: fid)
                        items.append(GoogleDriveFileItem(id: fid, name: fullName, size: 50_000_000, downloadURL: direct))
                        continue
                    }
                }

                // Docs / Sheets / Slides
                if href.contains("docs.google.com"), let dRange = href.range(of: "/d/") {
                    let rest = href[dRange.upperBound...]
                    let fid = rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
                    if !fid.isEmpty {
                        let fullName = prefix.isEmpty ? name : "\(prefix)\(name)"
                        let direct = Self.directDownloadURL(fileID: fid)
                        items.append(GoogleDriveFileItem(id: fid, name: fullName, size: 10_000_000, downloadURL: direct))
                        continue
                    }
                }

                // Subfolder
                if let fRange = href.range(of: "/folders/") {
                    let rest = href[fRange.upperBound...]
                    let subID = rest.split(separator: "/").first.map(String.init)?.split(separator: "?").first.map(String.init) ?? ""
                    if !subID.isEmpty && subID != folderID {
                        subfolders.append((subID, name))
                    }
                }
            }
        }

        // Recursively fetch subfolders to get every file inside nested directories
        for sub in subfolders {
            let subPrefix = prefix.isEmpty ? "\(sub.name)/" : "\(prefix)\(sub.name)/"
            let (_, subItems) = await fetchEmbeddedFolder(folderID: sub.id, prefix: subPrefix, depth: depth + 1)
            items.append(contentsOf: subItems)
        }

        return (folderTitle, items)
    }

    private func extractTitle(from html: String) -> String? {
        // Match <title>Folder Name – Google Drive</title>
        if let titleRange = html.range(of: "<title>") {
            let rest = html[titleRange.upperBound...]
            if let endRange = rest.range(of: "</title>") {
                var title = String(rest[..<endRange.lowerBound])
                title = title.replacingOccurrences(of: " – Google Drive", with: "")
                title = title.replacingOccurrences(of: " — Google Drive", with: "")
                title = title.replacingOccurrences(of: " - Google Drive", with: "")
                title = title.replacingOccurrences(of: "- Google Drive", with: "")
                title = title.replacingOccurrences(of: "Google Drive", with: "")
                title = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–— ")))
                if !title.isEmpty && !title.lowercased().contains("meet google drive") {
                    return title
                }
            }
        }
        return nil
    }

    private func parseFilesFromHTML(html: String, folderID: String) -> [GoogleDriveFileItem] {
        var results: [GoogleDriveFileItem] = []
        var seenIDs = Set<String>()

        func parseBytes(amount: String, unit: String) -> Int64 {
            guard let num = Double(amount) else { return 50_000_000 }
            let u = unit.uppercased().trimmingCharacters(in: .whitespaces)
            if u.contains("TB") { return Int64(num * 1024 * 1024 * 1024 * 1024) }
            if u.contains("GB") { return Int64(num * 1024 * 1024 * 1024) }
            if u.contains("MB") { return Int64(num * 1024 * 1024) }
            if u.contains("KB") { return Int64(num * 1024) }
            return Int64(num)
        }

        // Pattern 1: Embedded JS array with ID, filename, and human-readable size
        let p1 = #"(?:\[\[null,["']([\w-]{25,45})["']\],(?:[^\[]|\[(?!\[null))*?\[\[\[["']([^"'\\]+?)["'](?:[^\[]|\[(?!\[null))*?Size:\s*([0-9.]+)\s*([KMGT]?B))"#
        if let regex1 = try? NSRegularExpression(pattern: p1, options: [.dotMatchesLineSeparators]) {
            let nsString = html as NSString
            let matches = regex1.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for m in matches {
                guard m.numberOfRanges >= 5 else { continue }
                let id = nsString.substring(with: m.range(at: 1))
                let name = nsString.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let amt = nsString.substring(with: m.range(at: 3))
                let unit = nsString.substring(with: m.range(at: 4))
                if id != folderID, !seenIDs.contains(id), !name.isEmpty {
                    seenIDs.insert(id)
                    let bytes = parseBytes(amount: amt, unit: unit)
                    let direct = Self.directDownloadURL(fileID: id)
                    results.append(GoogleDriveFileItem(id: id, name: name, size: bytes, downloadURL: direct))
                }
            }
        }

        // Pattern 2: Fallback for items without explicit size line
        let p2 = #"(?:\[\[null,["']([\w-]{25,45})["']\],(?:[^\[]|\[(?!\[null))*?\[\[\[["']([^"'\\]+?)["'])"#
        if let regex2 = try? NSRegularExpression(pattern: p2, options: [.dotMatchesLineSeparators]) {
            let nsString = html as NSString
            let matches = regex2.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for m in matches {
                guard m.numberOfRanges >= 3 else { continue }
                let id = nsString.substring(with: m.range(at: 1))
                let name = nsString.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if id != folderID, !seenIDs.contains(id), !name.isEmpty {
                    seenIDs.insert(id)
                    let direct = Self.directDownloadURL(fileID: id)
                    results.append(GoogleDriveFileItem(id: id, name: name, size: 50_000_000, downloadURL: direct))
                }
            }
        }

        // Pattern 3: Fallback on data-id attributes
        let p3 = #"data-id=[\"']([a-zA-Z0-9_-]{28,36})[\"']"#
        if let regex3 = try? NSRegularExpression(pattern: p3) {
            let nsString = html as NSString
            let matches = regex3.matches(in: html, range: NSRange(location: 0, length: nsString.length))
            for m in matches {
                guard m.numberOfRanges >= 2 else { continue }
                let id = nsString.substring(with: m.range(at: 1))
                if id != folderID, !seenIDs.contains(id) {
                    seenIDs.insert(id)
                    let direct = Self.directDownloadURL(fileID: id)
                    results.append(GoogleDriveFileItem(id: id, name: "file_\(id)", size: 50_000_000, downloadURL: direct))
                }
            }
        }

        return results
    }

    private func runYtDlpDump(tool: String, url: URL, folderID: String) async -> GoogleDriveFolderResult? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<GoogleDriveFolderResult?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: tool)
                process.arguments = ["--flat-playlist", "-J", "--no-warnings", url.absoluteString]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    guard process.terminationStatus == 0,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let title = (json["title"] as? String) ?? "Google Drive Folder"
                    var items: [GoogleDriveFileItem] = []

                    if let entries = json["entries"] as? [[String: Any]] {
                        for e in entries {
                            guard let id = (e["id"] as? String) ?? (e["url"] as? String) else { continue }
                            let name = (e["title"] as? String) ?? "file_\(id)"
                            let size = (e["filesize"] as? Int64) ?? (e["filesize_approx"] as? Int64) ?? 50_000_000
                            let direct = Self.directDownloadURL(fileID: id)
                            items.append(GoogleDriveFileItem(id: id, name: name, size: size, downloadURL: direct))
                        }
                    }

                    let res = GoogleDriveFolderResult(
                        folderID: folderID,
                        title: title,
                        files: items,
                        totalBytes: items.reduce(0) { $0 + $1.size },
                        zipDownloadURL: URL(string: "https://drive.google.com/drive/folders/\(folderID)?export=download")
                    )
                    continuation.resume(returning: res)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
