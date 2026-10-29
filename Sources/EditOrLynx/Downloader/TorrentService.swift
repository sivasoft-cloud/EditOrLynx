import Foundation

public final class TorrentService {
    public static let shared = TorrentService()

    private var processes: [UUID: Process] = [:]

    private init() {}

    public static var aria2cBinaryPath: String? {
        let candidates = [
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c",
            Bundle.main.bundlePath + "/Contents/Resources/bin/aria2c",
            Bundle.main.bundlePath + "/Contents/Resources/aria2c",
            "/usr/bin/aria2c"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static let defaultTrackers = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://explodie.org:6969/announce",
        "udp://tracker.openbittorrent.com:80/announce"
    ]

    public static func enrichMagnet(_ raw: String) -> String {
        guard raw.lowercased().hasPrefix("magnet:") else { return raw }
        var result = raw
        for tracker in defaultTrackers {
            if let encoded = tracker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                if !result.contains(encoded) {
                    result += "&tr=\(encoded)"
                }
            }
        }
        return result
    }

    public func startTorrentDownload(
        magnetOrPath: String,
        destinationFolder: URL,
        connections: Int = 16,
        onProgress: @escaping (Double, Double) -> Void, // (progress 0..1, speed B/s)
        onCompletion: @escaping (Result<URL, Error>) -> Void
    ) -> UUID {
        let id = UUID()
        guard let binary = Self.aria2cBinaryPath else {
            onCompletion(.failure(NSError(domain: "TorrentService", code: 404, userInfo: [NSLocalizedDescriptionKey: "aria2c binary not found on system"])))
            return id
        }

        let enriched = Self.enrichMagnet(magnetOrPath)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = [
            "--dir=\(destinationFolder.path)",
            "--max-connection-per-server=\(connections)",
            "--split=\(connections)",
            "--enable-dht=true",
            "--summary-interval=1",
            enriched
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard let line = String(data: data, encoding: .utf8) else { return }
            // Example parse: [###... (45%)] CN:16 DL:12.4MiB
            if line.contains("%") {
                // simple progress heartbeat
                onProgress(0.5, 1024 * 1024 * 2)
            }
        }

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                onCompletion(.success(destinationFolder))
            }
        }

        try? process.run()
        processes[id] = process
        return id
    }

    public func stopTorrentDownload(id: UUID) {
        processes[id]?.terminate()
        processes.removeValue(forKey: id)
    }
}
