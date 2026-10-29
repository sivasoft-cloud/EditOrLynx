import Foundation
import AppKit
import PounceCore

public final class TorrentService: @unchecked Sendable {
    public static let shared = TorrentService()

    private var processes: [UUID: Process] = [:]
    private var outputPipes: [UUID: Pipe] = [:]
    private let queue = DispatchQueue(label: "com.editor.lynx.torrent", qos: .utility)

    private init() {}

    public static var aria2Path: String? {
        let candidates = [
            Bundle.main.bundlePath + "/Contents/Resources/bin/aria2c",
            Bundle.main.bundlePath + "/Contents/Resources/aria2c",
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c",
            NSHomeDirectory() + "/Library/Application Support/Edit.or.lynx/bin/aria2c",
            "/usr/bin/aria2c"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static var isTorrentAvailable: Bool {
        aria2Path != nil
    }

    public static let defaultTrackers = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://tracker.torrent.eu.org:451/announce",
        "udp://explodie.org:6969/announce",
        "udp://tracker.openbittorrent.com:80/announce",
        "http://tracker.openbittorrent.com:80/announce",
        "udp://tracker.bittor.pw:1337/announce",
        "udp://p4p.arenabg.com:1337/announce",
        "udp://tracker.cyberia.is:6969/announce",
        "udp://retracker.lanta-net.ru:2710/announce",
        "udp://tracker.tiny-vps.com:6969/announce",
        "udp://opentor.org:2710/announce",
        "https://tracker.tamersunion.org:443/announce",
        "http://open.acgnxtracker.com:80/announce",
        "udp://9.rarbg.to:2920/announce"
    ]

    public static func enrichMagnetLink(_ raw: String) -> String {
        guard raw.lowercased().hasPrefix("magnet:") else { return raw }
        var enriched = raw
        if !enriched.contains("?") {
            enriched = enriched.replacingOccurrences(of: "magnet:", with: "magnet:?")
        }
        for tr in defaultTrackers {
            if let encoded = tr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                if !enriched.contains(encoded) && !enriched.contains(tr) {
                    enriched += "&tr=\(encoded)"
                }
            }
        }
        return enriched
    }

    public func startTorrent(
        item: DownloadItem,
        source: String,
        destinationDir: URL,
        onProgress: @escaping @Sendable (Int64, Int64?, Double, String?) -> Void,
        onComplete: @escaping @Sendable (URL?) -> Void,
        onFailure: @escaping @Sendable (String) -> Void
    ) {
        guard let ariaPath = Self.aria2Path else {
            onFailure("BitTorrent engine (aria2c) not found. Please install via Homebrew: brew install aria2")
            return
        }

        let isMagnet = source.lowercased().hasPrefix("magnet:")
        let cleanSource = isMagnet ? Self.enrichMagnetLink(source) : source

        var localTorrentPath: String? = nil
        if !isMagnet {
            if cleanSource.lowercased().hasPrefix("file://") {
                if let u = URL(string: cleanSource) {
                    localTorrentPath = u.path
                } else {
                    localTorrentPath = String(cleanSource.dropFirst(7))
                }
            } else if cleanSource.hasPrefix("/") || cleanSource.hasPrefix("~") {
                let expanded = NSString(string: cleanSource).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    localTorrentPath = expanded
                }
            } else if FileManager.default.fileExists(atPath: cleanSource) {
                localTorrentPath = cleanSource
            }
        }

        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ariaPath)

            let trackersArg = Self.defaultTrackers.joined(separator: ",")

            var arguments = [
                "--disable-ipv6=true",
                "--enable-dht=true",
                "--bt-enable-lpd=true",
                "--enable-peer-exchange=true",
                "--listen-port=6881-6999",
                "--dht-listen-port=6881-6999",
                "--bt-tracker-connect-timeout=4",
                "--bt-tracker-timeout=6",
                "--bt-request-peer-speed-limit=256K",
                "--bt-load-saved-metadata=true",
                "--summary-interval=1",
                "--dir=\(destinationDir.path)",
                "--file-allocation=none",
                "--seed-time=0",
                "--max-connection-per-server=16",
                "--split=16",
                "--min-split-size=1M",
                "--auto-file-renaming=false",
                "--allow-overwrite=true",
                "--follow-torrent=mem",
                "--bt-save-metadata=true",
                "--bt-max-peers=150",
                "--bt-tracker=\(trackersArg)",
                "--dht-entry-point=router.bittorrent.com:6881",
                "--dht-entry-point=dht.transmissionbt.com:6881",
                "--user-agent=EditOrLynx/2.4 (Macintosh; Intel Mac OS X)",
                "--peer-id-prefix=-EL2400-",
                "--stderr"
            ]

            if let path = localTorrentPath {
                arguments.append("-T")
                arguments.append(path)
            } else {
                arguments.append(cleanSource)
            }
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            self.processes[item.id] = process
            self.outputPipes[item.id] = pipe

            let outHandle = pipe.fileHandleForReading
            var lineBuffer = ""
            var lastFilePath: String? = nil

            let downloadRegexPattern = #"\[#[a-f0-9]+\s+([^\/]+)\/([^\(\]]+)(?:\((\d+)%\))?.*?\bCN:(\d+)(?:.*?\bSD:(\d+))?.*?\bDL:([^\s\]]+)(?:.*?\bETA:([^\s\]]+))?.*\]"#
            let metaRegexPattern = #"\[#[a-f0-9]+\s+0B\/0B.*?\bCN:(\d+)(?:.*?\bSD:(\d+))?.*\]"#

            let dlRegex = try? NSRegularExpression(pattern: downloadRegexPattern)
            let metaRegex = try? NSRegularExpression(pattern: metaRegexPattern)

            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                guard let text = String(data: data, encoding: .utf8) else { return }

                lineBuffer += text
                while let range = lineBuffer.range(of: "\n") ?? lineBuffer.range(of: "\r") {
                    let line = String(lineBuffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    lineBuffer = String(lineBuffer[range.upperBound...])
                    guard !line.isEmpty else { continue }

                    // Parse completed path (ignoring internal .torrent metadata saves)
                    if line.contains("Download complete:") {
                        let parts = line.components(separatedBy: "Download complete:")
                        if let pathPart = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !pathPart.isEmpty {
                            if !pathPart.lowercased().hasSuffix(".torrent") {
                                lastFilePath = pathPart
                            }
                        }
                    } else if line.contains("Download Results:") || line.contains("|") {
                        if line.contains("/") && !line.contains("[#") {
                            let parts = line.split(separator: "/")
                            if let last = parts.last {
                                let candidate = String(last).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !candidate.lowercased().hasSuffix(".torrent") {
                                    lastFilePath = destinationDir.appendingPathComponent(candidate).path
                                }
                            }
                        }
                    }

                    // 1. Check active file download progress
                    if let reg = dlRegex, let m = reg.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                        let ns = line as NSString
                        let dlStr = ns.substring(with: m.range(at: 1))
                        let totStr = ns.substring(with: m.range(at: 2))
                        let cn = ns.substring(with: m.range(at: 4))
                        let sd = m.range(at: 5).location != NSNotFound ? ns.substring(with: m.range(at: 5)) : "0"
                        let dlSpdStr = ns.substring(with: m.range(at: 6))
                        let eta = m.range(at: 7).location != NSNotFound ? ns.substring(with: m.range(at: 7)) : "--"

                        let downloadedBytes = Self.parseBytes(dlStr)
                        let totalBytes = Self.parseBytes(totStr)
                        let speed = Self.parseSpeed(dlSpdStr)

                        if totalBytes > 0 {
                            let hint = "Seeds: \(sd) · Peers: \(cn) · ETA: \(eta)"
                            onProgress(downloadedBytes, totalBytes, speed, hint)
                        } else {
                            let hint = "Connecting to swarm… Peers: \(cn) · Seeds: \(sd)"
                            onProgress(0, nil, speed, hint)
                        }
                    }
                    // 2. Check metadata discovery phase for magnet links
                    else if let mreg = metaRegex, let mm = mreg.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                        let ns = line as NSString
                        let cn = ns.substring(with: mm.range(at: 1))
                        let sd = mm.range(at: 2).location != NSNotFound ? ns.substring(with: mm.range(at: 2)) : "0"
                        let hint = "Connecting to swarm… Peers: \(cn) · Seeds: \(sd)"
                        onProgress(0, nil, 0, hint)
                    }
                }
            }

            do {
                try process.run()
                process.waitUntilExit()

                outHandle.readabilityHandler = nil
                self.processes.removeValue(forKey: item.id)
                self.outputPipes.removeValue(forKey: item.id)

                if process.terminationStatus == 0 {
                    let finalURL = Self.findRecentFile(in: destinationDir, savedPath: lastFilePath)
                    onComplete(finalURL)
                } else {
                    onFailure("Torrent download failed (code \(process.terminationStatus)).")
                }
            } catch {
                outHandle.readabilityHandler = nil
                self.processes.removeValue(forKey: item.id)
                self.outputPipes.removeValue(forKey: item.id)
                onFailure("Could not run BitTorrent process: \(error.localizedDescription)")
            }
        }
    }

    public func cancel(_ id: UUID) {
        queue.async {
            if let proc = self.processes[id], proc.isRunning {
                proc.terminate()
            }
            self.processes.removeValue(forKey: id)
            self.outputPipes.removeValue(forKey: id)
        }
    }

    // MARK: - Helpers

    public static func parseBytes(_ string: String) -> Int64 {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()

        let multiplier: Double
        let numStr: String

        if upper.hasSuffix("TI") || upper.hasSuffix("T") {
            multiplier = 1024 * 1024 * 1024 * 1024
            numStr = upper.replacingOccurrences(of: "TI", with: "").replacingOccurrences(of: "T", with: "")
        } else if upper.hasSuffix("GI") || upper.hasSuffix("G") {
            multiplier = 1024 * 1024 * 1024
            numStr = upper.replacingOccurrences(of: "GI", with: "").replacingOccurrences(of: "G", with: "")
        } else if upper.hasSuffix("MI") || upper.hasSuffix("M") {
            multiplier = 1024 * 1024
            numStr = upper.replacingOccurrences(of: "MI", with: "").replacingOccurrences(of: "M", with: "")
        } else if upper.hasSuffix("KI") || upper.hasSuffix("K") {
            multiplier = 1024
            numStr = upper.replacingOccurrences(of: "KI", with: "").replacingOccurrences(of: "K", with: "")
        } else {
            multiplier = 1
            numStr = upper
        }

        if let val = Double(numStr.trimmingCharacters(in: .whitespaces)) {
            return Int64(val * multiplier)
        }
        return 0
    }

    public static func parseSpeed(_ string: String) -> Double {
        return Double(parseBytes(string))
    }

    private static func findRecentFile(in directory: URL, savedPath: String?) -> URL {
        if let saved = savedPath, FileManager.default.fileExists(atPath: saved), !saved.lowercased().hasSuffix(".torrent"), !saved.lowercased().hasSuffix(".aria2") {
            return URL(fileURLWithPath: saved)
        }
        guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return directory
        }
        var newestFile: URL? = nil
        var newestDate: Date = .distantPast
        for item in items {
            let ext = item.pathExtension.lowercased()
            if ext == "aria2" || ext == "torrent" { continue }
            if let vals = try? item.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = vals.contentModificationDate,
               date > newestDate {
                newestDate = date
                newestFile = item
            }
        }
        return newestFile ?? directory
    }
}
