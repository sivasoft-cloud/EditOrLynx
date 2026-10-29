import Foundation
import Combine

public struct EngineSettings: Codable, Equatable {
    public var connections: Int
    public var maxConcurrent: Int
    public var destinationFolder: String
    public var turboEnabled: Bool
    public var autoDelete: Bool
    public var watchClipboard: Bool
    public var offerCopiedLinks: Bool
    public var showBrowserButton: Bool

    public init(
        connections: Int = 32,
        maxConcurrent: Int = 10,
        destinationFolder: String = "~/Downloads/Edit.or.lynx",
        turboEnabled: Bool = false,
        autoDelete: Bool = true,
        watchClipboard: Bool = true,
        offerCopiedLinks: Bool = true,
        showBrowserButton: Bool = false
    ) {
        self.connections = connections
        self.maxConcurrent = maxConcurrent
        self.destinationFolder = destinationFolder
        self.turboEnabled = turboEnabled
        self.autoDelete = autoDelete
        self.watchClipboard = watchClipboard
        self.offerCopiedLinks = offerCopiedLinks
        self.showBrowserButton = showBrowserButton
    }
}

@MainActor
public final class DownloadEngine: ObservableObject {
    @Published public private(set) var downloads: [DownloadItem]
    @Published public var settings: EngineSettings
    @Published public var version: Int = 0

    /// Called on the main actor when a download reaches completion.
    public var onComplete: ((DownloadItem) -> Void)?
    /// Called on the main actor when a download fails.
    public var onFail: ((DownloadItem) -> Void)?
    /// A real transfer should run for this item (it has just been added or promoted).
    public var onLivePending: ((DownloadItem) -> Void)?
    /// A real transfer's bytes must stop (the item was paused or removed).
    public var onLiveCancel: ((UUID) -> Void)?
    /// The item was paused: stop the bytes but keep any partial file so a resume can
    /// continue with an HTTP Range request instead of starting over.
    public var onLivePause: ((UUID) -> Void)?

    private var lastTick: Date
    private let randomize: Bool

    public init(
        downloads: [DownloadItem] = [],
        settings: EngineSettings = EngineSettings(),
        now: Date = Date(),
        randomize: Bool = true
    ) {
        self.downloads = downloads
        self.settings = settings
        self.lastTick = now
        self.randomize = randomize
        normalizeStates()
    }

    // MARK: Derived state

    public var activeCount: Int {
        downloads.filter { $0.state == .downloading }.count
    }

    public var activeDownloads: [DownloadItem] {
        downloads.filter { $0.state.isActive }
            .sorted { $0.addedAt > $1.addedAt }
    }

    public var completedDownloads: [DownloadItem] {
        downloads.filter { $0.state == .completed }
            .sorted { ($0.completedAt ?? $0.addedAt) > ($1.completedAt ?? $1.addedAt) }
    }

    public var totalSpeed: Double {
        downloads.filter { $0.state == .downloading }.reduce(0) { $0 + $1.currentSpeed }
    }

    public var queuedCount: Int {
        downloads.filter { $0.state == .queued }.count
    }

    public func item(with id: UUID) -> DownloadItem? {
        downloads.first { $0.id == id }
    }

    // MARK: Simulation

    public func tick(now: Date = Date()) {
        let dt = min(2.0, max(0, now.timeIntervalSince(lastTick)))
        guard dt > 0 else { return }
        lastTick = now

        promoteQueued()

        var completed: [DownloadItem] = []

        for index in downloads.indices {
            guard downloads[index].state == .downloading else {
                if downloads[index].state == .paused || downloads[index].state == .queued {
                    downloads[index].currentSpeed = 0
                }
                continue
            }

            // A real transfer reports its own bytes; only the demo animation is simulated.
            if downloads[index].isLive {
                continue
            }

            var item = downloads[index]
            let connections = max(1, min(32, item.connectionCount))
            let uptime = now.timeIntervalSince(item.addedAt)
            let wobble = 0.88
                + 0.085 * sin(uptime * 0.7 + Double(item.seed) * 0.11)
                + 0.045 * sin(uptime * 2.3 + Double(item.seed) * 0.37)
            let jitter = randomize ? Double.random(in: -0.028...0.028) : 0
            let turbo: Double = settings.turboEnabled ? 1.36 : 1
            let instantaneous = item.baseSpeedPerConnection * Double(connections) * turbo * max(0.2, wobble + jitter)

            item.isTurbo = settings.turboEnabled
            item.currentSpeed = item.currentSpeed > 0 ? item.currentSpeed * 0.55 + instantaneous * 0.45 : instantaneous
            let step = max(1, Int64(instantaneous * dt))
            item.downloadedBytes = min(item.totalBytes, item.downloadedBytes + step)

            if item.speedSamples.count >= 42 {
                item.speedSamples.removeFirst(item.speedSamples.count - 41)
            }
            item.speedSamples.append(item.currentSpeed)

            // Finish on the tick that lands within one step of the end, so a transfer can
            // never render 99% forever while waiting on a last partial chunk.
            let remaining = item.totalBytes - item.downloadedBytes
            if remaining <= 0 || (remaining <= step / 2 && item.progress >= 0.9) || item.progress >= 0.999 {
                item.downloadedBytes = item.totalBytes
                item.state = .completed
                item.completedAt = now
                item.currentSpeed = 0
                completed.append(item)
            }

            downloads[index] = item
        }

        for item in completed {
            onComplete?(item)
        }

        promoteQueued()
        startPendingLive()
    }

    // MARK: Live transfers

    /// Ask for a real transfer for every live item that is running but not yet started.
    private func startPendingLive() {
        guard let onLivePending else { return }
        for item in downloads where item.isLive && item.state == .downloading {
            onLivePending(item)
        }
    }

    /// A real transfer has begun producing bytes.
    public func liveStarted(_ id: UUID, totalBytes: Int64?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .downloading
        downloads[index].errorMessage = nil
        if let totalBytes, totalBytes > 0 {
            downloads[index].totalBytes = totalBytes
            downloads[index].downloadedBytes = min(downloads[index].downloadedBytes, totalBytes)
        }
    }

    /// A real transfer's progress, as bytes actually received.
    public func liveProgress(_ id: UUID, downloaded: Int64, total: Int64?, speed: Double) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        guard downloads[index].state == .downloading else { return }
        if let total, total > 0 {
            downloads[index].totalBytes = total
        }
        if downloads[index].totalBytes > 0 {
            downloads[index].downloadedBytes = max(0, min(downloads[index].totalBytes, downloaded))
        } else {
            // No content length: keep the real byte count instead of clamping to zero.
            downloads[index].downloadedBytes = max(0, downloaded)
        }
        downloads[index].currentSpeed = max(0, speed)
        if downloads[index].speedSamples.count >= 42 {
            downloads[index].speedSamples.removeFirst(downloads[index].speedSamples.count - 41)
        }
        downloads[index].speedSamples.append(max(0, speed))
    }

    /// Status hint (e.g. "Merging video & audio…", "Finalizing…")
    public func setStatusHint(_ id: UUID, hint: String?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].statusHint = hint
    }

    /// The real file is on disk: complete the item in the same update that reveals the path.
    public func liveCompleted(_ id: UUID, filePath: String, bytes: Int64?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        let size = bytes ?? downloads[index].downloadedBytes
        downloads[index].totalBytes = max(1, size)
        downloads[index].downloadedBytes = max(1, size)
        downloads[index].filePath = filePath
        downloads[index].state = .completed
        downloads[index].statusHint = nil
        downloads[index].completedAt = Date()
        downloads[index].currentSpeed = 0
        version &+= 1
        let item = downloads[index]
        promoteQueued()
        startPendingLive()
        onComplete?(item)
    }

    /// A real transfer failed (network, extractor, disk).
    public func liveFailed(_ id: UUID, message: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .failed
        downloads[index].statusHint = nil
        downloads[index].errorMessage = message
        downloads[index].currentSpeed = 0
        let item = downloads[index]
        promoteQueued()
        startPendingLive()
        onFail?(item)
    }

    /// Show the title the source page reports instead of the guess made from the URL.
    public func retitle(_ id: UUID, to title: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != downloads[index].title else { return }
        downloads[index].title = clean
    }

    // MARK: Mutations

    public func add(_ item: DownloadItem) {
        var item = item
        item.destinationFolder = item.destinationFolder.isEmpty ? settings.destinationFolder : item.destinationFolder
        item.isTurbo = settings.turboEnabled
        if item.state == .queued || item.state == .downloading {
            item.state = activeCount < settings.maxConcurrent ? .downloading : .queued
        }
        downloads.insert(item, at: 0)
        if item.state == .downloading {
            downloads[0].currentSpeed = item.baseSpeedPerConnection * Double(max(1, min(32, item.connectionCount)))
        }
        startPendingLive()
    }

    public func pause(_ id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        guard downloads[index].state == .downloading || downloads[index].state == .queued else { return }
        let live = downloads[index].isLive
        downloads[index].state = .paused
        downloads[index].currentSpeed = 0
        // Pausing must stop the network immediately, but keeps the partial file for resume.
        if live { onLivePause?(id) }
        promoteQueued()
    }

    public func resume(_ id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        guard downloads[index].state == .paused || downloads[index].state == .failed else { return }
        downloads[index].errorMessage = nil
        downloads[index].state = activeCount < settings.maxConcurrent ? .downloading : .queued
    }

    public func toggle(_ id: UUID) {
        guard let item = item(with: id) else { return }
        switch item.state {
        case .downloading, .queued: pause(id)
        case .paused, .failed: resume(id)
        case .completed: break
        }
    }

    public func pauseAll() {
        for index in downloads.indices where downloads[index].state == .downloading || downloads[index].state == .queued {
            let live = downloads[index].isLive
            downloads[index].state = .paused
            downloads[index].currentSpeed = 0
            // A paused download must not keep consuming bandwidth.
            if live { onLivePause?(downloads[index].id) }
        }
    }

    public func resumeAll() {
        for index in downloads.indices where downloads[index].state == .paused {
            downloads[index].state = activeCount < settings.maxConcurrent ? .downloading : .queued
        }
        promoteQueued()
    }

    public func remove(_ id: UUID) {
        if downloads.first(where: { $0.id == id })?.isLive == true { onLiveCancel?(id) }
        downloads.removeAll { $0.id == id }
        promoteQueued()
    }

    public func setFilePath(_ id: UUID, path: String?) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].filePath = path
    }

    public func clearCompleted() {
        downloads.removeAll { $0.state == .completed }
    }

    @discardableResult
    public func clearAllNonActive() -> Int {
        let count = downloads.filter { $0.state != .downloading && $0.state != .queued }.count
        downloads.removeAll { $0.state != .downloading && $0.state != .queued }
        version &+= 1
        return count
    }

    @discardableResult
    public func clearAllTasks() -> Int {
        let active = downloads.filter { $0.state == .downloading || $0.state == .queued || $0.state == .paused }
        for item in active where item.isLive {
            onLiveCancel?(item.id)
        }
        downloads.removeAll { $0.state == .downloading || $0.state == .queued || $0.state == .paused }
        version &+= 1
        promoteQueued()
        return active.count
    }

    public func clearEverything() {
        downloads.removeAll()
    }

    public func retry(_ id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .failed
        downloads[index].errorMessage = "Connection lost"
        downloads[index].downloadedBytes = max(0, downloads[index].downloadedBytes - 1)
        resume(id)
    }

    public func replaceAll(_ items: [DownloadItem]) {
        downloads = items
        normalizeStates()
        promoteQueued()
    }

    public func updateSettings(_ mutate: (inout EngineSettings) -> Void) {
        mutate(&settings)
        settings.connections = max(1, min(32, settings.connections))
        settings.maxConcurrent = max(1, min(10, settings.maxConcurrent))
        promoteQueued()
    }

    public func setTurbo(_ enabled: Bool) {
        settings.turboEnabled = enabled
        for index in downloads.indices where downloads[index].state == .downloading {
            downloads[index].isTurbo = enabled
        }
    }

    // MARK: Helpers

    private func normalizeStates() {
        let activeIndices = downloads.indices
            .filter { downloads[$0].state == .downloading }
            .sorted { downloads[$0].addedAt < downloads[$1].addedAt }
        for (position, index) in activeIndices.enumerated() where position >= settings.maxConcurrent {
            downloads[index].state = .queued
        }
    }

    private func promoteQueued() {
        guard activeCount < settings.maxConcurrent else { return }
        let queued = downloads.indices
            .filter { downloads[$0].state == .queued }
            .sorted { downloads[$0].addedAt < downloads[$1].addedAt }
        for index in queued {
            guard activeCount < settings.maxConcurrent else { break }
            downloads[index].state = .downloading
        }
    }
}
