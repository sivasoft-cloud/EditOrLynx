import Foundation
import Network

@MainActor
public final class BrowserBridge: ObservableObject {
    public static let shared = BrowserBridge()

    public var onDownloadRequested: ((URL, String?) -> Void)?
    private var listener: NWListener?

    private init() {
        startServer()
    }

    public func startServer(port: UInt16 = 48123) {
        do {
            let parameters = NWParameters.tcp
            self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }
            
            listener?.start(queue: .main)
        } catch {
            print("BrowserBridge server failed to start: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
                guard let data = data, let requestStr = String(data: data, encoding: .utf8) else {
                    connection.cancel()
                    return
                }

                // Simple HTTP POST parser for browser extension payloads
                if requestStr.contains("POST /api/download") {
                    if let bodyRange = requestStr.range(of: "\r\n\r\n") {
                        let body = String(requestStr[bodyRange.upperBound...])
                        if let jsonData = body.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let urlStr = json["url"] as? String,
                           let url = URL(string: urlStr) {
                            let filename = json["filename"] as? String
                            self?.onDownloadRequested?(url, filename)
                        }
                    }
                }

                let response = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: 2\r\n\r\nOK"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }
}
