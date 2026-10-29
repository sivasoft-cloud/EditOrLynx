import Foundation

public enum ClipboardClassifier {
    public static func kind(for raw: String) -> ClipboardKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("data:image/") || lower.hasPrefix("magnet:") || lower.hasSuffix(".torrent") {
            return .link
        }
        if lower.hasPrefix("www."), URL(string: "https://\(text)")?.host != nil {
            return .link
        }
        if isHexColor(text) { return .color }
        return .text
    }

    public static func isHexColor(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("#") else { return false }
        let body = String(t.dropFirst())
        guard body.count == 3 || body.count == 6 || body.count == 8 else { return false }
        return body.allSatisfy { $0.isHexDigit }
    }

    public static func normalizeLink(_ raw: String) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("data:") {
            return URL(string: text)
        }
        if text.lowercased().hasPrefix("magnet:") {
            return URL(string: text)
        }
        if text.lowercased().hasPrefix("file://") && text.lowercased().hasSuffix(".torrent") {
            return URL(string: text)
        }
        if text.hasPrefix("/") && text.lowercased().hasSuffix(".torrent") {
            return URL(fileURLWithPath: text)
        }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https"), url.host != nil {
            return url
        }
        if text.lowercased().hasPrefix("www.") {
            return URL(string: "https://\(text)")
        }
        // Handle domains like files.oaiusercontent.com/file-... without protocol
        if let url = URL(string: "https://\(text)"), let host = url.host, host.contains(".") {
            return url
        }
        return nil
    }
}
