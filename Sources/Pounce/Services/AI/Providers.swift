import Foundation

// MARK: - Conversation Types

public struct ToolCall: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var arguments: String // JSON object as text
    public var extra: String? = nil

    public init(id: String, name: String, arguments: String, extra: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.extra = extra
    }
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable { case system, user, assistant, tool }
    public var role: Role
    public var text: String
    public var at = Date()
    public var images: [String]? = nil
    public var toolCalls: [ToolCall]? = nil
    public var toolCallId: String? = nil
    public var isError: Bool? = nil
    public var raw: String? = nil
    public var rawSource: String? = nil

    public init(role: Role, text: String, at: Date = Date(), images: [String]? = nil, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil, isError: Bool? = nil, raw: String? = nil, rawSource: String? = nil) {
        self.role = role
        self.text = text
        self.at = at
        self.images = images
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.isError = isError
        self.raw = raw
        self.rawSource = rawSource
    }
}

public struct ToolSpec: Sendable {
    public let name: String
    public let description: String
    public let schema: String // JSON Schema

    public init(name: String, description: String, schema: String) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}

public enum ProviderEvent: Sendable {
    case text(String)
    case thinking(String)
    case toolCall(ToolCall)
    case usage(input: Int, output: Int)
    case raw(String, source: String)
    case ranTool(ToolCall, ok: Bool, result: String)
    case stop(reason: String)
}

public struct ProviderError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }

    public init(message: String) {
        self.message = message
    }
}

public protocol ChatProvider: Sendable {
    var name: String { get }
    var model: String { get }
    var isConnected: Bool { get }
    var supportsTools: Bool { get }
    var supportsImages: Bool { get }
    var contextChars: Int { get }
    func turn(system: String, messages: [ChatMessage], tools: [ToolSpec]) -> AsyncThrowingStream<ProviderEvent, Error>
}

public extension ChatProvider {
    var contextChars: Int { 300_000 }
}

public struct NotConnectedProvider: ChatProvider {
    public let name = "Not connected"
    public let model = "Connect an AI"
    public let isConnected = false
    public let supportsTools = false
    public let supportsImages = false

    public init() {}

    public func turn(system: String, messages: [ChatMessage], tools: [ToolSpec]) -> AsyncThrowingStream<ProviderEvent, Error> {
        let reply = """
        I'm not connected to an AI yet. You can connect any provider in **Settings › AI (Bring Your Own Brain)**: \
        OpenRouter, OpenAI (GPT-4o), Anthropic (Claude 3.5), Google Gemini, Groq, or local models via Ollama and LM Studio. \
        All your API keys are stored securely in macOS Keychain.
        """
        return AsyncThrowingStream { c in
            let task = Task {
                for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                    if Task.isCancelled { break }
                    c.yield(.text(String(word) + " "))
                    try? await Task.sleep(nanoseconds: 18_000_000)
                }
                c.yield(.stop(reason: "end_turn"))
                c.finish()
            }
            c.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Shared HTTP helpers

public enum HTTP {
    public static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 300
        c.timeoutIntervalForResource = 1800
        return URLSession(configuration: c)
    }()

    public static func json(_ obj: Any) -> Data {
        guard JSONSerialization.isValidJSONObject([obj]) else { return Data() }
        return (try? JSONSerialization.data(withJSONObject: obj, options: .fragmentsAllowed)) ?? Data()
    }

    public static func parse(_ text: String) -> [String: Any]? {
        guard let d = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }

    public static func errorMessage(status: Int, body: String, provider: String) -> String {
        let obj = parse(body)
        let detail = ((obj?["error"] as? [String: Any])?["message"] as? String)
            ?? (obj?["error"] as? String) ?? (obj?["message"] as? String)
            ?? String(body.prefix(300))
        switch status {
        case 401, 403: return "\(provider) rejected the API key (\(status)). Check it in Settings › AI. \(detail)"
        case 404: return "\(provider): model or endpoint not found (404). \(detail)"
        case 429: return "\(provider) is rate-limiting or out of credit (429). \(detail)"
        default: return "\(provider) error \(status): \(detail)"
        }
    }

    public static func sse(_ req: URLRequest, provider: String) -> AsyncThrowingStream<(event: String?, data: String), Error> {
        AsyncThrowingStream { c in
            let task = Task {
                do {
                    var attempt = 0
                    var bytes: URLSession.AsyncBytes
                    while true {
                        let (b, resp) = try await session.bytes(for: req)
                        let http = resp as? HTTPURLResponse
                        let status = http?.statusCode ?? 0
                        if status == 200 { bytes = b; break }
                        var body = ""
                        for try await line in b.lines { body += line; if body.count > 4000 { break } }
                        if (status == 429 || status == 503) && attempt < 2,
                           let wait = retryDelay(header: http?.value(forHTTPHeaderField: "retry-after"), body: body), wait <= 20 {
                            attempt += 1
                            try await Task.sleep(nanoseconds: UInt64((wait + 0.5) * 1e9))
                            continue
                        }
                        throw ProviderError(message: errorMessage(status: status, body: body, provider: provider))
                    }
                    var event: String?
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.hasPrefix("event:") {
                            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            c.yield((event, line.dropFirst(5).trimmingCharacters(in: .whitespaces)))
                            event = nil
                        }
                    }
                    c.finish()
                } catch {
                    c.finish(throwing: error)
                }
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    public static func retryDelay(header: String?, body: String) -> Double? {
        if let h = header, let v = Double(h.trimmingCharacters(in: .whitespaces)) { return v }
        if let r = body.range(of: #"(?:try again in|retry in|retry after)\s*([0-9.]+)\s*s"#, options: [.regularExpression, .caseInsensitive]) {
            let digits = body[r].replacingOccurrences(of: #"[^0-9.]"#, with: "", options: .regularExpression)
            return Double(digits)
        }
        return header == nil ? 2 : nil
    }

    public static func imageDataURL(_ path: String) -> (mime: String, base64: String)? {
        guard let data = FileManager.default.contents(atPath: path), data.count < 15_000_000 else { return nil }
        let ext = (path as NSString).pathExtension.lowercased()
        let mime = ext == "png" ? "image/png" : ext == "gif" ? "image/gif" : ext == "webp" ? "image/webp" : "image/jpeg"
        return (mime, data.base64EncodedString())
    }
}
