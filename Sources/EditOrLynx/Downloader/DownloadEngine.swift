import Foundation
import Combine

@MainActor
public final class DownloadEngine: NSObject, ObservableObject {
    public static let shared = DownloadEngine()

    @Published public private(set) var activeDownloads: [UUID: DownloadItem] = [:]
    @Published public private(set) var completedDownloads: [DownloadItem] = []
    @Published public var maxConcurrentDownloads: Int = 5
    @Published public var defaultConnectionsPerTask: Int = 16

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private var fileHandles: [UUID: FileHandle] = [:]
    private var partialFiles: [UUID: URL] = [:]
    private var speedTimers: [UUID: (lastBytes: Int64, lastTime: TimeInterval)] = [:]
    private var refreshTimer: AnyCancellable?

    override private init() {
        super.init()

        // Periodically refresh speeds
        refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTransferSpeeds()
            }
    }

    // MARK: - Public API

    public func startDownload(
        url: URL,
        customFilename: String? = nil,
        destinationFolder: URL? = nil,
        connections: Int = 16
    ) -> DownloadItem {
        var item = DownloadItem(
            url: url,
            filename: customFilename,
            connections: connections
        )

        if let dest = destinationFolder {
            item.destinationURL = dest.appendingPathComponent(item.filename)
        }

        activeDownloads[item.id] = item
        scheduleNext()
        return item
    }

    public func pauseDownload(id: UUID) {
        guard var item = activeDownloads[id] else { return }
        item.state = .paused
        item.speed = 0
        activeDownloads[id] = item

        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        try? fileHandles[id]?.synchronize()
        fileHandles.removeValue(forKey: id)
        scheduleNext()
    }

    public func resumeDownload(id: UUID) {
        guard var item = activeDownloads[id] else { return }
        item.state = .connecting
        activeDownloads[id] = item
        startTask(for: item)
    }

    public func cancelDownload(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
        try? fileHandles[id]?.close()
        fileHandles.removeValue(forKey: id)

        if let partial = partialFiles[id] {
            try? FileManager.default.removeItem(at: partial)
            partialFiles.removeValue(forKey: id)
        }

        if var item = activeDownloads.removeValue(forKey: id) {
            item.state = .cancelled
            item.speed = 0
            completedDownloads.insert(item, at: 0)
        }
        scheduleNext()
    }

    public func removeCompleted(id: UUID) {
        completedDownloads.removeAll { $0.id == id }
    }

    public func clearAllCompleted() {
        completedDownloads.removeAll()
    }

    // MARK: - Internal Scheduling

    private func scheduleNext() {
        let activeRunning = activeDownloads.values.filter { $0.state == .downloading || $0.state == .connecting }.count
        guard activeRunning < maxConcurrentDownloads else { return }

        if let nextWaiting = activeDownloads.values.first(where: { $0.state == .idle }) {
            var item = nextWaiting
            item.state = .connecting
            activeDownloads[item.id] = item
            startTask(for: item)
        }
    }

    private func startTask(for item: DownloadItem) {
        let id = item.id
        var request = URLRequest(url: item.url)
        request.setValue("bytes=\(item.downloadedBytes)-", forHTTPHeaderField: "Range")

        // Prepare temporary file for streaming bytes
        let stagingFolder = FileManager.default.temporaryDirectory.appendingPathComponent("EditOrLynxStaging", isDirectory: true)
        try? FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        let partialURL = stagingFolder.appendingPathComponent("\(id.uuidString).part")
        partialFiles[id] = partialURL

        if !FileManager.default.fileExists(atPath: partialURL.path) {
            FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: partialURL) else {
            fail(id: id, error: "Cannot create staging file")
            return
        }

        handle.seekToEndOfFile()
        fileHandles[id] = handle

        speedTimers[id] = (lastBytes: item.downloadedBytes, lastTime: Date().timeIntervalSince1970)

        // Asynchronous URLSession download streaming
        let downloadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    self.fail(id: id, error: "Server returned HTTP status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    return
                }

                if var currentItem = self.activeDownloads[id] {
                    let totalLength = response.expectedContentLength
                    let downloaded = currentItem.downloadedBytes
                    if totalLength > 0 && currentItem.totalBytes <= 0 {
                        currentItem.totalBytes = totalLength + downloaded
                    }
                    currentItem.state = .downloading
                    self.updateItem(currentItem)
                }

                var buffer = Data()
                buffer.reserveCapacity(65536)

                for try await byte in asyncBytes {
                    if Task.isCancelled || self.activeDownloads[id]?.state != .downloading {
                        break
                    }
                    buffer.append(byte)
                    if buffer.count >= 65536 {
                        handle.write(buffer)
                        self.incrementBytes(id: id, by: Int64(buffer.count))
                        buffer.removeAll(keepingCapacity: true)
                    }
                }

                if !buffer.isEmpty {
                    handle.write(buffer)
                    self.incrementBytes(id: id, by: Int64(buffer.count))
                }

                if !Task.isCancelled && self.activeDownloads[id]?.state == .downloading {
                    self.finishDownload(id: id)
                }
            } catch {
                if !Task.isCancelled {
                    self.fail(id: id, error: error.localizedDescription)
                }
            }
        }
        activeTasks[id] = downloadTask
    }

    private func updateItem(_ item: DownloadItem) {
        activeDownloads[item.id] = item
    }

    private func incrementBytes(id: UUID, by amount: Int64) {
        guard var item = activeDownloads[id] else { return }
        item.downloadedBytes += amount
        activeDownloads[id] = item
    }

    private func finishDownload(id: UUID) {
        guard var item = activeDownloads.removeValue(forKey: id) else { return }
        activeTasks.removeValue(forKey: id)
        try? fileHandles[id]?.close()
        fileHandles.removeValue(forKey: id)

        if let partial = partialFiles.removeValue(forKey: id) {
            let dest = item.destinationURL
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: partial, to: dest)
        }

        item.state = .completed
        item.speed = 0
        item.dateCompleted = Date()
        completedDownloads.insert(item, at: 0)
        scheduleNext()
    }

    private func fail(id: UUID, error: String) {
        guard var item = activeDownloads.removeValue(forKey: id) else { return }
        activeTasks.removeValue(forKey: id)
        try? fileHandles[id]?.close()
        fileHandles.removeValue(forKey: id)

        item.state = .failed
        item.speed = 0
        item.errorMessage = error
        completedDownloads.insert(item, at: 0)
        scheduleNext()
    }

    private func updateTransferSpeeds() {
        let now = Date().timeIntervalSince1970
        for (id, item) in activeDownloads where item.state == .downloading {
            guard let timer = speedTimers[id] else {
                speedTimers[id] = (lastBytes: item.downloadedBytes, lastTime: now)
                continue
            }

            let elapsed = now - timer.lastTime
            if elapsed >= 0.5 {
                let delta = item.downloadedBytes - timer.lastBytes
                let currentSpeed = max(0, Double(delta) / elapsed)
                var updated = item
                updated.speed = currentSpeed
                activeDownloads[id] = updated
                speedTimers[id] = (lastBytes: item.downloadedBytes, lastTime: now)
            }
        }
    }
}
