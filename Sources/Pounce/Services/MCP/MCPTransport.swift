import Foundation

public protocol MCPTransport: AnyObject, Sendable {
    func open() async throws
    func request(_ method: String, _ params: [String: Any], timeout: TimeInterval) async throws -> [String: Any]
    func close()
}

public enum MCPEndpoint: Equatable, Sendable {
    case stdio(command: String, args: [String], env: [String: String])
    case http(URL, headers: [String: String])

    public static func parse(_ config: [String: Any]) -> Result<MCPEndpoint, ProviderError> {
        let type = (config["type"] as? String)?.lowercased()
        if type == "sse" {
            return .failure(ProviderError(message: "The old SSE transport isn't supported — use Streamable HTTP URL"))
        }
        if let raw = (config["url"] as? String) ?? (config["serverUrl"] as? String) {
            guard let url = URL(string: raw.trimmingCharacters(in: .whitespaces)), allowed(url) else {
                return .failure(ProviderError(message: "URL must be https (plain http only allowed on localhost)"))
            }
            return .success(.http(url, headers: config["headers"] as? [String: String] ?? [:]))
        }
        if let type, type != "stdio" {
            return .failure(ProviderError(message: "A \(type) server needs a url"))
        }
        guard let command = config["command"] as? String, !command.isEmpty else {
            return .failure(ProviderError(message: "Needs a command or a url"))
        }
        return .success(.stdio(
            command: command,
            args: config["args"] as? [String] ?? [],
            env: config["env"] as? [String: String] ?? [:]
        ))
    }

    public static func allowed(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "https": return !(url.host ?? "").isEmpty
        case "http": return ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
        default: return false
        }
    }
}

public enum MCPWire {
    public static let protocolVersion = "2025-06-18"
    public static var initializeParams: [String: Any] {
        [
            "protocolVersion": protocolVersion,
            "capabilities": [String: Any](),
            "clientInfo": ["name": "Edit.or.lynx", "version": "2.4.0"]
        ]
    }

    public enum Incoming {
        case result(id: Int, [String: Any])
        case error(id: Int, String)
        case serverRequest(id: Any, method: String)
        case other
    }

    public static func classify(_ obj: [String: Any]) -> Incoming {
        if let method = obj["method"] as? String {
            if let id = obj["id"] { return .serverRequest(id: id, method: method) }
            return .other
        }
        guard let id = obj["id"] as? Int else { return .other }
        if let err = obj["error"] as? [String: Any] {
            return .error(id: id, err["message"] as? String ?? "MCP error")
        }
        return .result(id: id, obj["result"] as? [String: Any] ?? [:])
    }

    public static func reply(id: Any, method: String) -> [String: Any] {
        method == "ping" ? ["jsonrpc": "2.0", "id": id, "result": [String: Any]()]
            : ["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "not supported"]]
    }

    public static func messages(_ text: String) -> [[String: Any]] {
        guard let d = text.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) else { return [] }
        if let one = obj as? [String: Any] { return [one] }
        return obj as? [[String: Any]] ?? []
    }
}

// MARK: - Stdio Transport

public final class StdioTransport: MCPTransport, @unchecked Sendable {
    private let name: String
    private let command: String
    private let args: [String]
    private let env: [String: String]

    private var process: Process?
    private var stdin: FileHandle?
    private let lock = NSLock()
    private var nextId = 1
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var buffer = Data()

    public init(name: String, command: String, args: [String], env: [String: String]) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }

    public func open() async throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = [command] + args
        var e = ProcessInfo.processInfo.environment
        e["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (e["PATH"] ?? "/usr/bin:/bin")
        for (k, v) in env { e[k] = v }
        p.environment = e
        let inPipe = Pipe(), outPipe = Pipe()
        p.standardInput = inPipe
        p.standardOutput = outPipe
        p.standardError = FileHandle.nullDevice
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if d.isEmpty {
                h.readabilityHandler = nil
                self?.failAll("Server exited")
                return
            }
            self?.received(d)
        }
        p.terminationHandler = { [weak self] _ in self?.failAll("Server exited") }
        try p.run()
        process = p
        stdin = inPipe.fileHandleForWriting

        _ = try await request("initialize", MCPWire.initializeParams, timeout: 20)
        send(["jsonrpc": "2.0", "method": "notifications/initialized"])
    }

    public func request(_ method: String, _ params: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        let id = lock.withLock {
            let i = nextId
            nextId += 1
            return i
        }
        let msg: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        return try await withCheckedThrowingContinuation { cont in
            lock.withLock { pending[id] = cont }
            send(msg)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1e9))
                self?.timeout(id)
            }
        }
    }

    private func send(_ obj: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj) else { return }
        lock.withLock {
            _ = try? stdin?.write(contentsOf: d + Data("\n".utf8))
        }
    }

    private func received(_ data: Data) {
        lock.withLock { buffer.append(data) }
        while let nl = lock.withLock({ buffer.firstIndex(of: 0x0a) }) {
            let lineData = lock.withLock { () -> Data in
                let sub = buffer.prefix(upTo: nl)
                buffer.removeSubrange(..<buffer.index(after: nl))
                return sub
            }
            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }
            for msg in MCPWire.messages(line) {
                handleIncoming(msg)
            }
        }
    }

    private func handleIncoming(_ obj: [String: Any]) {
        switch MCPWire.classify(obj) {
        case .result(let id, let res):
            let cont = lock.withLock { pending.removeValue(forKey: id) }
            cont?.resume(returning: res)
        case .error(let id, let err):
            let cont = lock.withLock { pending.removeValue(forKey: id) }
            cont?.resume(throwing: ProviderError(message: "\(name): \(err)"))
        case .serverRequest(let id, let method):
            send(MCPWire.reply(id: id, method: method))
        case .other:
            break
        }
    }

    private func timeout(_ id: Int) {
        let cont = lock.withLock { pending.removeValue(forKey: id) }
        cont?.resume(throwing: ProviderError(message: "\(name): request timed out"))
    }

    private func failAll(_ why: String) {
        let map = lock.withLock {
            let m = pending
            pending.removeAll()
            return m
        }
        for (_, cont) in map {
            cont.resume(throwing: ProviderError(message: "\(name): \(why)"))
        }
    }

    public func close() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        stdin = nil
        failAll("closed")
    }
}

// MARK: - HTTP Transport

public final class HTTPTransport: MCPTransport, @unchecked Sendable {
    private let name: String
    private let url: URL
    private let headers: [String: String]
    private var nextId = 1
    private let lock = NSLock()

    public init(name: String, url: URL, headers: [String: String]) {
        self.name = name
        self.url = url
        self.headers = headers
    }

    public func open() async throws {
        _ = try await request("initialize", MCPWire.initializeParams, timeout: 20)
    }

    public func request(_ method: String, _ params: [String: Any], timeout: TimeInterval) async throws -> [String: Any] {
        let id = lock.withLock {
            let i = nextId
            nextId += 1
            return i
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        let body: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await HTTP.session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ProviderError(message: HTTP.errorMessage(status: status, body: String(data: data, encoding: .utf8) ?? "", provider: name))
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError(message: "\(name): Invalid JSON response")
        }

        if let err = obj["error"] as? [String: Any] {
            throw ProviderError(message: "\(name): \(err["message"] as? String ?? "RPC error")")
        }

        return obj["result"] as? [String: Any] ?? [:]
    }

    public func close() {}
}
