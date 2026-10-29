import Foundation
import Darwin
import PounceCore

/// A loopback-only HTTP door for the browser extensions.
///
/// The extension posts `{ "url": …, "title": …, "action": "download" }` and the app
/// queues it exactly as if the link had been copied. Nothing leaves the Mac: the
/// listener binds to 127.0.0.1 and only answers browser-extension origins.
final class ExtensionBridge: @unchecked Sendable {
    static let shared = ExtensionBridge()
    static let port: UInt16 = 47_820

    weak var model: AppModel?

    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.editor.lynx.extensionbridge", qos: .utility, attributes: .concurrent)

    func start() {
        guard !isRunning else { return }
        isRunning = true

        queue.async { [weak self] in
            self?.runServer()
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    // MARK: - Server Loop

    private func runServer() {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return }
        serverSocket = sock

        var opt: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        #if os(macOS)
        var nosig: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
        #endif

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(Self.port).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0 else {
            let err = String(cString: strerror(errno))
            print("[ExtensionBridge] bind failed (\(errno)): \(err)")
            close(sock)
            serverSocket = -1
            return
        }

        if listen(sock, 32) != 0 {
            let err = String(cString: strerror(errno))
            print("[ExtensionBridge] listen failed (\(errno)): \(err)")
            close(sock)
            serverSocket = -1
            return
        }
        print("[ExtensionBridge] Listening on 127.0.0.1:\(Self.port)")

        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(sock, $0, &clientLen)
                }
            }
            guard client >= 0 else {
                if !isRunning { break }
                usleep(10_000)
                continue
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(client)
            }
        }
    }

    private func handleClient(_ client: Int32) {
        defer { close(client) }

        var buffer = [UInt8](repeating: 0, count: 65_536)
        let bytesRead = read(client, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let data = Data(buffer.prefix(bytesRead))
        guard let request = Self.parse(data) else { return }

        let (status, respData) = process(request: request)
        send(status: status, body: respData, to: client)
    }

    // MARK: - Request Parsing

    private struct Request {
        var method: String
        var path: String
        var body: Data
    }

    private static func parse(_ buffer: Data) -> Request? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[buffer.startIndex..<headerEnd.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])
        var contentLength = 0
        for line in lines.dropFirst() {
            let pieces = line.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2, pieces[0].lowercased().trimmingCharacters(in: .whitespaces) == "content-length" else { continue }
            contentLength = Int(pieces[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let bodyStart = headerEnd.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        let body: Data
        if available >= contentLength, contentLength > 0 {
            body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
        } else {
            body = buffer.subdata(in: bodyStart..<buffer.endIndex)
        }
        return Request(method: method, path: path, body: body)
    }

    // MARK: - Request Processing

    private func process(request: Request) -> (Int, Data) {
        let path = request.path.split(separator: "?").first.map(String.init) ?? request.path

        if request.method == "OPTIONS" {
            return (204, Data())
        }

        switch (request.method, path) {
        case ("GET", "/"), ("GET", "/status"):
            let active = DispatchQueue.main.sync { [weak self] in
                self?.model?.engine.activeCount ?? 0
            }
            let payload: [String: Any] = [
                "ok": true,
                "app": "Edit.or.lynx",
                "version": "1.0",
                "activeCount": active,
                "port": Int(Self.port)
            ]
            let json = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
            return (200, json)

        case ("GET", "/jobs"):
            let jobs: [[String: Any]] = DispatchQueue.main.sync { [weak self] in
                let items: [DownloadItem] = self?.model.map { Array($0.engine.downloads.prefix(16)) } ?? []
                return items.map { item in
                    [
                        "id": item.id.uuidString,
                        "title": item.title,
                        "state": item.state.rawValue,
                        "progress": (item.progress * 1000).rounded() / 1000,
                        "downloadedBytes": item.downloadedBytes,
                        "totalBytes": item.totalBytes,
                        "file": item.filePath ?? ""
                    ]
                }
            }
            let json = (try? JSONSerialization.data(withJSONObject: ["ok": true, "jobs": jobs])) ?? Data()
            return (200, json)

        case ("POST", "/job"):
            guard let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let url = object["url"] as? String else {
                return (400, Data("{\"ok\":false,\"error\":\"A job needs a url.\"}".utf8))
            }
            let title = object["title"] as? String
            let action = (object["action"] as? String) ?? "download"
            let quality = object["quality"] as? String
            let audioOnly = object["audioOnly"] as? Bool ?? false

            Task { @MainActor [weak self] in
                self?.model?.receiveExternalLink(url: url, title: title, action: action, quality: quality, audioOnly: audioOnly)
            }
            return (200, Data("{\"ok\":true,\"action\":\"offer\"}".utf8))

        case ("GET", "/job"):
            var components = URLComponents()
            components.query = request.path.split(separator: "?", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
            let items = components.queryItems ?? []
            let url = items.first(where: { $0.name == "url" })?.value
            let title = items.first(where: { $0.name == "title" })?.value
            let action = items.first(where: { $0.name == "action" })?.value ?? "download"
            let quality = items.first(where: { $0.name == "quality" })?.value
            let audioOnly = (items.first(where: { $0.name == "audioOnly" })?.value == "true")
            guard let url else {
                return (400, Data("{\"ok\":false,\"error\":\"A job needs a url.\"}".utf8))
            }
            Task { @MainActor [weak self] in
                self?.model?.receiveExternalLink(url: url, title: title, action: action, quality: quality, audioOnly: audioOnly)
            }
            return (200, Data("{\"ok\":true}".utf8))

        case ("POST", "/notify"):
            guard let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                  let text = (object["text"] as? String) ?? (object["message"] as? String) else {
                return (400, Data("{\"ok\":false,\"error\":\"A notification needs text.\"}".utf8))
            }
            let title = object["title"] as? String
            let symbol = (object["symbol"] as? String) ?? "bell.fill"
            Task { @MainActor [weak self] in
                self?.model?.showNotification(title: title, text: text, symbol: symbol)
            }
            return (200, Data("{\"ok\":true,\"notified\":true}".utf8))

        default:
            return (404, Data("{\"ok\":false,\"error\":\"Not found\"}".utf8))
        }
    }

    private func send(status: Int, body: Data, to client: Int32) {
        let reason = status == 200 ? "OK" : (status == 204 ? "No Content" : "Error")
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: application/json; charset=utf-8\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        head += "Access-Control-Allow-Headers: Content-Type\r\n\r\n"

        var payload = Data(head.utf8)
        payload.append(body)

        _ = payload.withUnsafeBytes { ptr in
            write(client, ptr.baseAddress, ptr.count)
        }
    }
}
