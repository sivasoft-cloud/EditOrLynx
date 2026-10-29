import AppKit
import Foundation
import PounceCore

/// Fetches the actual bytes for a download and reports them back to the engine.
///
/// Two routes:
///  * Direct files (installers, archives, PDFs, plain media links) come down over
///    URLSession, so the progress bar is the real byte count.
///  * Pages and videos go through `yt-dlp` when it is installed, which names the
///    file after the real video title and can cut a clip. When no extractor is
///    available the page's own media URL is pulled out of its markup, and a plain
///    page is saved as an .html document.
@MainActor
final class TransferService: NSObject {
    static let shared = TransferService()

    weak var model: AppModel?

    private var session: URLSession!
    private var running: [UUID: Process] = [:]
    private var started: Set<UUID> = []
    private var cancelled: Set<UUID> = []
    private var targets: [UUID: URL] = [:]
    private var lastSample: [UUID: (bytes: Int64, time: TimeInterval)] = [:]
    private var currentSpeed: [UUID: Double] = [:]

    /// What a task's own termination means: nothing special, fall back to the page
    /// route (an HTTP error status), or retry with backoff (a transient failure).
    private enum NextAction { case none, fallback, retry }

    /// Bookkeeping for one direct (plain HTTP) transfer. It survives pauses and
    /// transient failures so a resume can send an HTTP Range request instead of
    /// downloading the file again from byte zero.
    private struct DirectTransfer {
        var task: URLSessionDataTask?
        var handle: FileHandle?
        var sourceURL: URL
        /// Staged file the bytes stream into (``partial.data`` in the staging folder).
        var partialURL: URL
        /// Bytes already in the partial file before the current task's first byte.
        var offset: Int64 = 0
        /// Bytes written by the current task.
        var written: Int64 = 0
        /// Full file size when the server reported one.
        var expectedTotal: Int64?
        /// The server proved it honours Range requests (Accept-Ranges or a 206).
        var rangeSupported = false
        /// Failed attempts so far; bounds the automatic retries.
        var attempts = 0
        /// Response metadata for the finish pipeline.
        var mime: String?
        var suggested: String?
        /// The task is ending because we decided it should; read `next` instead of
        /// treating the cancellation as a network failure.
        var ignoreCompletion = false
        var next: NextAction = .none
    }

    private var direct: [UUID: DirectTransfer] = [:]
    private var retryTasks: [UUID: Task<Void, Never>] = [:]
    /// Bounded automatic retries per transfer; the delay is capped at 8 seconds.
    private let maxDirectAttempts = 4
    private let ioQueue = DispatchQueue(label: "com.editor.lynx.ioQueue", qos: .utility)
    private var lastProgressReportTime: [UUID: TimeInterval] = [:]

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60 * 60 * 4
        let queue = OperationQueue()
        queue.name = "com.editor.lynx.network"
        queue.maxConcurrentOperationCount = 8
        queue.qualityOfService = .utility
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }

    private var engine: DownloadEngine? { model?.engine }

    private func handleTorrentProgress(id: UUID, dl: Int64, tot: Int64?, spd: Double, hint: String?) {
        if let tot = tot, tot > 0 {
            engine?.liveStarted(id, totalBytes: tot)
        }
        engine?.liveProgress(id, downloaded: dl, total: tot, speed: spd)
        if let hint = hint {
            engine?.setStatusHint(id, hint: hint)
        }
    }

    private func handleTorrentCompletion(id: UUID, finalURL: URL?) {
        started.remove(id)
        let path = finalURL?.path ?? ""
        let bytes = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
        engine?.liveCompleted(id, filePath: path, bytes: bytes)
    }

    private func handleTorrentFailure(id: UUID, message: String) {
        started.remove(id)
        engine?.liveFailed(id, message: message)
    }

    // MARK: Entry

    func start(_ item: DownloadItem) {
        guard item.isLive, !started.contains(item.id) else { return }
        let rawURL = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // BitTorrent / Magnet Link Detection
        if rawURL.lowercased().hasPrefix("magnet:") || rawURL.lowercased().hasSuffix(".torrent") || item.formatLabel == "TORRENT" || item.formatLabel == "MAGNET" {
            started.insert(item.id)
            cancelled.remove(item.id)
            engine?.liveStarted(item.id, totalBytes: nil)
            engine?.setStatusHint(item.id, hint: "Connecting to BitTorrent swarm…")

            let destination = Self.folderURL(for: item.destinationFolder)

            TorrentService.shared.startTorrent(
                item: item,
                source: rawURL,
                destinationDir: destination,
                onProgress: { [weak self] dl, tot, spd, hint in
                    Task { @MainActor in
                        self?.handleTorrentProgress(id: item.id, dl: dl, tot: tot, spd: spd, hint: hint)
                    }
                },
                onComplete: { [weak self] finalURL in
                    Task { @MainActor in
                        self?.handleTorrentCompletion(id: item.id, finalURL: finalURL)
                    }
                },
                onFailure: { [weak self] err in
                    Task { @MainActor in
                        self?.handleTorrentFailure(id: item.id, message: err)
                    }
                }
            )
            return
        }

        if rawURL.hasPrefix("data:") {
            started.insert(item.id)
            cancelled.remove(item.id)
            engine?.liveStarted(item.id, totalBytes: Int64(rawURL.count * 3 / 4))
            handleDataURL(item: item, raw: rawURL)
            return
        }

        guard let url = URL(string: rawURL) ?? URL(string: rawURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            engine?.liveFailed(item.id, message: "Invalid download link.")
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        let isWeb = scheme == "http" || scheme == "https"
        let isSearchOrAudio = scheme.hasPrefix("ytsearch") || scheme == "search" || scheme == "spotify" || item.kind == .audio
        guard isWeb || isSearchOrAudio else {
            engine?.liveFailed(item.id, message: "That link can't be downloaded.")
            return
        }

        started.insert(item.id)
        cancelled.remove(item.id)
        retryTasks[item.id]?.cancel()
        retryTasks[item.id] = nil
        // A user-initiated start gets a fresh retry budget.
        direct[item.id]?.attempts = 0
        targets[item.id] = url
        engine?.liveStarted(item.id, totalBytes: direct[item.id]?.expectedTotal)

        if item.kind == .file && isWeb {
            downloadDirect(item: item, url: url)
        } else {
            downloadWithExtractor(item: item, url: url)
        }
    }

    /// Stopped for good (removed from the list): the partial file goes too.
    func cancel(_ id: UUID) {
        cancelled.insert(id)
        started.remove(id)
        retryTasks[id]?.cancel()
        retryTasks[id] = nil
        TorrentService.shared.cancel(id)
        if var state = direct[id] {
            state.task?.cancel()
            closeHandle(&state)
        }
        direct[id] = nil
        try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
        if let process = running[id], process.isRunning {
            process.terminate()
        }
        running[id] = nil
        lastSample[id] = nil
        currentSpeed[id] = nil
        targets[id] = nil
    }

    /// Paused: stop the bytes now, but keep the partial file and what we learned
    /// about the server so a resume can continue with a Range request.
    func suspend(_ id: UUID) {
        cancelled.insert(id)
        started.remove(id)
        retryTasks[id]?.cancel()
        retryTasks[id] = nil
        TorrentService.shared.cancel(id)
        if var state = direct[id] {
            state.task?.cancel()
            closeHandle(&state)
            state.task = nil
            state.handle = nil
            state.written = 0
            state.ignoreCompletion = false
            state.next = .none
            direct[id] = state
        }
        // For the extractor route this terminates yt-dlp; its staging folder (with the
        // .part file) is kept so the next start continues instead of restarting.
        if let process = running[id], process.isRunning {
            process.terminate()
        }
        running[id] = nil
        lastSample[id] = nil
        currentSpeed[id] = nil
    }

    static func stagingDir(for id: UUID) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lynk-\(id.uuidString)", isDirectory: true)
    }

    private func closeHandle(_ state: inout DirectTransfer) {
        try? state.handle?.close()
        state.handle = nil
    }

    private func handleDataURL(item: DownloadItem, raw: String) {
        guard let commaIndex = raw.firstIndex(of: ",") else {
            engine?.liveFailed(item.id, message: "Invalid image data.")
            return
        }
        let header = String(raw[..<commaIndex])
        let base64 = String(raw[raw.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else {
            engine?.liveFailed(item.id, message: "Could not decode image.")
            return
        }
        var ext = "png"
        if header.contains("jpeg") || header.contains("jpg") {
            ext = "jpg"
        } else if header.contains("webp") {
            ext = "webp"
        } else if header.contains("gif") {
            ext = "gif"
        } else if header.contains("svg") {
            ext = "svg"
        }
        let folder = Self.folderURL(for: item.destinationFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = Self.uniqueURL(in: folder, base: "ChatGPT-Image-\(Int(Date().timeIntervalSince1970))", ext: ext)
        do {
            try data.write(to: destination)
            engine?.retitle(item.id, to: destination.lastPathComponent)
            engine?.liveProgress(item.id, downloaded: Int64(data.count), total: Int64(data.count), speed: 0)
            complete(item.id, path: destination.path)
        } catch {
            engine?.liveFailed(item.id, message: "Could not save image to disk.")
        }
    }

    // MARK: Direct HTTP

    /// Starts (or resumes) the plain-HTTP transfer, streaming into a staged partial
    /// file. When the server previously proved Range support and bytes are already
    /// on disk, the request carries `Range: bytes=<offset>-` and the response is
    /// appended; otherwise the partial is discarded and the download restarts
    /// safely from zero rather than producing a corrupt file.
    private func downloadDirect(item: DownloadItem, url: URL) {
        let id = item.id
        let staging = Self.stagingDir(for: id)
        try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let partial = staging.appendingPathComponent("partial.data")

        var state = direct[id] ?? DirectTransfer(sourceURL: url, partialURL: partial)
        state.sourceURL = url
        state.partialURL = partial
        state.task = nil
        closeHandle(&state)
        state.written = 0
        state.ignoreCompletion = false
        state.next = .none

        var offset: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: partial.path),
           let number = attrs[.size] as? NSNumber {
            offset = number.int64Value
        }
        if offset > 0 && !state.rangeSupported {
            // No proven Range support — restart safely instead of corrupting the file.
            try? FileManager.default.removeItem(at: partial)
            offset = 0
        }
        state.offset = offset

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let page = targets[item.id], page != url {
            request.setValue(page.absoluteString, forHTTPHeaderField: "Referer")
        }
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }
        let task = session.dataTask(with: request)
        task.taskDescription = id.uuidString
        state.task = task
        direct[id] = state
        targets[id] = url
        lastSample[id] = (offset, Date().timeIntervalSinceReferenceDate)
        if offset > 0 {
            engine?.liveProgress(id, downloaded: offset, total: state.expectedTotal, speed: 0)
        }
        task.resume()
    }

    fileprivate func received(_ id: UUID, bytes: Int64, total: Int64?) {
        guard !cancelled.contains(id) else { return }
        let now = Date().timeIntervalSinceReferenceDate
        var speed = currentSpeed[id] ?? 0
        if let sample = lastSample[id] {
            let elapsed = now - sample.time
            if elapsed >= 0.25 {
                let instant = Double(max(0, bytes - sample.bytes)) / elapsed
                speed = speed > 0 ? (speed * 0.7 + instant * 0.3) : instant
                currentSpeed[id] = speed
                lastSample[id] = (bytes, now)
            }
        } else {
            lastSample[id] = (bytes, now)
        }
        let smoothed = max(0, speed)
        engine?.liveProgress(id, downloaded: bytes, total: total, speed: smoothed)
    }

    // MARK: Direct transfer callbacks

    /// Decides whether the streamed response may proceed, fixing up offsets and
    /// totals from the response headers before the first body byte arrives.
    fileprivate func handleResponse(id: UUID, response: URLResponse) -> URLSession.ResponseDisposition {
        guard !cancelled.contains(id), var state = direct[id] else { return .cancel }

        guard let http = response as? HTTPURLResponse else {
            state.mime = response.mimeType
            state.suggested = response.suggestedFilename
            let expected = response.expectedContentLength
            state.expectedTotal = expected > 0 ? expected : nil
            state.offset = 0
            if openPartial(&state, append: false) {
                direct[id] = state
                lastSample[id] = (0, Date().timeIntervalSinceReferenceDate)
                return .allow
            }
            finishFailure(id: id, "Couldn't write the temporary download file.")
            return .cancel
        }

        let status = http.statusCode
        let acceptRanges = http.value(forHTTPHeaderField: "Accept-Ranges")?
            .lowercased().contains("bytes") ?? false
        let contentRange = http.value(forHTTPHeaderField: "Content-Range")

        if (200..<300).contains(status) {
            var append = false
            if status == 206, state.offset > 0, Self.rangeStart(contentRange) == state.offset {
                // The server answered exactly the range we asked for: append.
                append = true
                state.rangeSupported = true
                if let total = Self.rangeTotal(contentRange) {
                    state.expectedTotal = total
                } else if http.expectedContentLength > 0 {
                    state.expectedTotal = state.offset + http.expectedContentLength
                }
            } else {
                // A full 200 body: either a fresh download or a server that ignored
                // our Range request. Restart the file at zero so nothing corrupts.
                state.offset = 0
                state.rangeSupported = acceptRanges
                state.expectedTotal = http.expectedContentLength > 0 ? http.expectedContentLength : nil
            }
            state.mime = http.mimeType
            state.suggested = http.suggestedFilename
            if let name = http.suggestedFilename, !name.isEmpty, name != "download", name != "file", name != "uc" {
                engine?.retitle(id, to: name)
            }
            if openPartial(&state, append: append) {
                direct[id] = state
                lastSample[id] = (state.offset, Date().timeIntervalSinceReferenceDate)
                engine?.liveProgress(id, downloaded: state.offset, total: state.expectedTotal, speed: 0)
                return .allow
            }
            finishFailure(id: id, "Couldn't write the temporary download file.")
            return .cancel
        }

        // An HTTP error status: end our own task and decide from `next`.
        state.ignoreCompletion = true
        if (status == 416 || status == 403) && state.offset > 0 {
            // Azure Blob SAS or signed CDN URLs reject Range requests with 403 or 416.
            // Restart safely from scratch with offset 0 without Range header.
            state.rangeSupported = false
            try? FileManager.default.removeItem(at: state.partialURL)
            state.offset = 0
            state.next = state.attempts < maxDirectAttempts ? .retry : .fallback
        } else if (status == 408 || status == 429 || (500...599).contains(status)),
                  state.attempts < maxDirectAttempts {
            state.next = .retry
        } else {
            state.next = .fallback
        }
        direct[id] = state
        return .cancel
    }

    /// Opens the staged partial file for writing; `append` keeps existing bytes.
    private func openPartial(_ state: inout DirectTransfer, append: Bool) -> Bool {
        let fm = FileManager.default
        if append {
            guard fm.fileExists(atPath: state.partialURL.path) else { return false }
        } else {
            try? fm.removeItem(at: state.partialURL)
            guard fm.createFile(atPath: state.partialURL.path, contents: nil) else { return false }
        }
        guard let handle = try? FileHandle(forWritingTo: state.partialURL) else { return false }
        if append {
            guard (try? handle.seekToEnd()) != nil else {
                try? handle.close()
                return false
            }
        }
        state.handle = handle
        state.written = 0
        return true
    }

    /// Streams one body chunk to disk on background I/O queue and throttles progress updates to eliminate UI lag.
    fileprivate func appendData(_ id: UUID, _ data: Data) {
        guard !cancelled.contains(id), let state = direct[id], let handle = state.handle else { return }
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try handle.write(contentsOf: data)
            } catch {
                Task { @MainActor in
                    let task = self.direct[id]?.task
                    self.finishFailure(id: id, "Couldn't write to disk — \(error.localizedDescription)")
                    task?.cancel()
                }
                return
            }

            Task { @MainActor in
                guard !self.cancelled.contains(id), var current = self.direct[id] else { return }
                current.written += Int64(data.count)
                self.direct[id] = current

                let now = Date().timeIntervalSinceReferenceDate
                let lastReport = self.lastProgressReportTime[id] ?? 0
                let total = current.expectedTotal
                let currentBytes = current.offset + current.written

                // Throttle progress dispatches to 10Hz (once every 100ms) or on completion
                if now - lastReport >= 0.1 || (total != nil && currentBytes >= total!) {
                    self.lastProgressReportTime[id] = now
                    self.received(id, bytes: currentBytes, total: total)
                }
            }
        }
    }

    /// The task ended: either by our own decision, by a transient network fault
    /// (bounded backoff retry), or for good — in which case the finished bytes are
    /// validated against the response metadata before anything is marked complete.
    fileprivate func directCompleted(_ id: UUID, error: Error?) {
        guard var state = direct[id] else { return }
        closeHandle(&state)
        state.task = nil

        if state.ignoreCompletion {
            let next = state.next
            state.ignoreCompletion = false
            state.next = .none
            direct[id] = state
            switch next {
            case .retry:
                scheduleRetry(id: id)
            case .fallback:
                direct[id] = nil
                lastSample[id] = nil
                if !cancelled.contains(id), let item = engine?.item(with: id) {
                    try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
                    fallbackToPage(item: item, url: state.sourceURL)
                }
            case .none:
                break
            }
            return
        }

        if cancelled.contains(id) {
            // Paused or removed while the task was ending; suspend/cancel already
            // arranged the file state.
            state.written = 0
            direct[id] = state
            return
        }

        if let error {
            handleDirectError(id: id, state: state, error: error)
            return
        }

        // The transfer ended without an error: validate it before completing.
        let partial = state.partialURL
        let size = Self.fileSize(partial)
        guard size > 0 else {
            try? FileManager.default.removeItem(at: partial)
            finishFailure(id: id, "The server sent an empty file.")
            return
        }
        if let total = state.expectedTotal, total > 0, size != total {
            if size > total {
                // The partial no longer matches this resource — start over.
                state.rangeSupported = false
                try? FileManager.default.removeItem(at: partial)
                state.offset = 0
            }
            direct[id] = state
            if state.attempts < maxDirectAttempts {
                scheduleRetry(id: id)
            } else {
                direct[id] = nil
                lastSample[id] = nil
                currentSpeed[id] = nil
                try? FileManager.default.removeItem(at: partial)
                finishFailure(
                    id: id,
                    "The download finished short: \(Fmt.bytes(Double(size))) of \(Fmt.bytes(Double(total)))."
                )
            }
            return
        }
        finishDirect(id: id, state: state, status: 200)
    }

    private func handleDirectError(id: UUID, state: DirectTransfer, error: Error) {
        let nsError = error as NSError
        // Our own cancellation is interpreted elsewhere (or already handled).
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        if state.attempts < maxDirectAttempts, Self.isTransient(error) {
            var state = state
            direct[id] = state
            scheduleRetry(id: id)
            return
        }
        finishFailure(id: id, error.localizedDescription)
    }

    /// Bounded automatic retry with exponential backoff (0.5 s, 1 s, 2 s, 4 s).
    /// The staged partial survives, so a Range-capable server resumes instead of
    /// restarting.
    private func scheduleRetry(id: UUID) {
        guard var state = direct[id] else { return }
        guard let item = engine?.item(with: id), !cancelled.contains(id),
              item.state == .downloading else {
            // Paused, queued or removed meanwhile: leave the restart to the engine's
            // normal promotion flow.
            direct[id] = nil
            started.remove(id)
            return
        }
        guard state.attempts < maxDirectAttempts else {
            direct[id] = nil
            lastSample[id] = nil
            currentSpeed[id] = nil
            finishFailure(
                id: id,
                "The download kept failing after \(state.attempts + 1) attempts. Press Retry to start again."
            )
            return
        }
        state.attempts += 1
        closeHandle(&state)
        state.task = nil
        state.written = 0
        direct[id] = state
        // Show an honest zero speed while waiting — never a stale one.
        engine?.liveProgress(id, downloaded: state.offset, total: state.expectedTotal, speed: 0)

        let delay = min(8.0, 0.5 * pow(2.0, Double(state.attempts - 1)))
        retryTasks[id]?.cancel()
        retryTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, !self.cancelled.contains(id),
                  let current = self.engine?.item(with: id),
                  let pending = self.direct[id] else { return }
            self.retryTasks[id] = nil
            guard self.started.contains(id), current.state == .downloading else {
                self.started.remove(id)
                self.direct[id] = nil
                return
            }
            self.downloadDirect(item: current, url: pending.sourceURL)
        }
    }

    /// Runs a finished transfer through the same checks as before: HTML pages, the
    /// extractor hand-off, then a move into the downloads folder under a safe name.
    private func finishDirect(id: UUID, state: DirectTransfer, status: Int) {
        direct[id] = nil
        lastSample[id] = nil
        currentSpeed[id] = nil
        let temp = state.partialURL
        guard !cancelled.contains(id), let item = engine?.item(with: id) else {
            try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
            return
        }
        guard (200..<300).contains(status) else {
            try? FileManager.default.removeItem(at: temp)
            fallbackToPage(item: item, url: state.sourceURL)
            return
        }

        let host = state.sourceURL.host?.lowercased() ?? ""
        let isYouTube = item.urlString.contains("youtube.com") || item.urlString.contains("youtu.be") || host.contains("youtube.com") || host.contains("youtu.be")
        let isMediaSite = item.kind == .video || item.kind == .audio || item.kind == .clip || LinkInspector.isVideoSite(host) || isYouTube

        // Intercept Google Drive virus scan warning on large files and automatically proceed with confirm URL
        if GoogleDriveService.isGoogleDrive(url: state.sourceURL) {
            if let data = try? Data(contentsOf: temp),
               let html = String(data: data, encoding: .utf8),
               let confirmURL = GoogleDriveService.extractConfirmURL(html: html, originalURL: state.sourceURL) {
                try? FileManager.default.removeItem(at: temp)
                try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
                downloadDirect(item: item, url: confirmURL)
                return
            }
        }

        if state.mime?.contains("html") == true || (isMediaSite && !(200..<300).contains(status)) {
            if isMediaSite {
                try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
                downloadWithExtractor(item: item, url: state.sourceURL)
                return
            }
            guard let data = try? Data(contentsOf: temp), !data.isEmpty else {
                try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
                finishFailure(id: id, "The server sent an empty page.")
                return
            }
            try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
            savePage(data, item: item)
            return
        }

        guard let saved = moveToFolder(temp, item: item, mime: state.mime, suggested: state.suggested) else {
            try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
            finishFailure(id: id, "Couldn't write the file to \(Self.displayFolder(item.destinationFolder)).")
            return
        }
        try? FileManager.default.removeItem(at: Self.stagingDir(for: id))
        complete(id, path: saved.path)
    }

    // MARK: yt-dlp

    private func downloadWithExtractor(item: DownloadItem, url: URL) {
        guard let tool = Self.tool("yt-dlp") else {
            let host = url.host?.lowercased() ?? ""
            if LinkInspector.isVideoSite(host) {
                finishFailure(id: item.id, "yt-dlp is required to download YouTube and video links. Install it with: brew install yt-dlp ffmpeg")
                return
            }
            fallbackToPage(item: item, url: url)
            return
        }
        // Reuse a staging folder left over from a pause so yt-dlp continues its
        // .part file; a stale partial from the direct route is dropped.
        let staging = Self.stagingDir(for: item.id)
        try? FileManager.default.removeItem(at: staging.appendingPathComponent("partial.data"))
        try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        var arguments = [
            "--no-playlist",
            "--newline",
            "--no-warnings",
            "--no-simulate",
            "--progress",
            "--no-overwrites",
            "--continue",
            "--retries", "10",
            "--fragment-retries", "10",
            "--concurrent-fragments", engine?.settings.turboEnabled == true ? "16" : "8",
            "-P", staging.path
        ]

        if let ffmpeg = Self.tool("ffmpeg") {
            arguments += ["--ffmpeg-location", ffmpeg]
        }

        let isClip = item.clipStart != nil && item.clipEnd != nil
        arguments += ["-o", isClip ? "%(title).150B [%(id)s] clip.%(ext)s" : "%(title).150B [%(id)s].%(ext)s"]

        if let start = item.clipStart, let end = item.clipEnd, end > start + 0.5 {
            arguments += ["--download-sections", "*\(Int(start.rounded()))-\(Int(end.rounded()))"]
            arguments += ["--force-keyframes-at-cuts"]
        }

        if item.kind == .audio {
            let isLossless = item.formatLabel.uppercased() == "LOSSLESS" || item.formatLabel.uppercased() == "FLAC" || item.qualityLabel.uppercased().contains("LOSSLESS") || item.qualityLabel.uppercased().contains("FLAC")
            let format = isLossless ? "flac" : "m4a"
            arguments += [
                "-f", "bestaudio/best",
                "-x", "--audio-format", format,
                "--audio-quality", "0"
            ]
        } else {
            let height = Self.height(for: item.qualityLabel)
            if Self.tool("ffmpeg") != nil {
                arguments += [
                    "-f", "bv*[height<=\(height)][vcodec^=avc]+ba[acodec^=mp4a]/bv*[height<=\(height)][vcodec^=avc]+ba/bv*[height<=\(height)][ext=mp4]+ba[ext=m4a]/bv*[height<=\(height)]+ba[acodec^=mp4a]/bv*[height<=\(height)]+ba/b[height<=\(height)]/bv*+ba/b/best",
                    "--merge-output-format", "mp4",
                    "--postprocessor-args", "Merger:-c:v copy -c:a aac -b:a 192k -movflags +faststart"
                ]
            } else {
                arguments += [
                    "-f", "bv*[height<=\(height)][vcodec^=avc]+ba[acodec^=mp4a]/b[height<=\(height)][vcodec^=avc]/b[height<=\(height)]/b/best"
                ]
            }
        }

        var targetURLString = url.absoluteString
        let decoded = targetURLString.removingPercentEncoding ?? targetURLString
        if decoded.hasPrefix("ytsearch1:") {
            targetURLString = decoded
        } else if SpotifyService.isSpotify(url: url) || url.host?.contains("apple.com") == true || url.host == "search" || (item.kind == .audio && !LinkInspector.isVideoSite(url.host ?? "")) {
            let artist = item.audioArtist ?? ""
            let title = item.title
            let query = !artist.isEmpty && !title.lowercased().contains(artist.lowercased()) ? "\(artist) - \(title)" : title
            targetURLString = "ytsearch1:\(query) audio"
        }

        arguments += [
            "--progress-template", "download:PPO %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.total_bytes_estimate)s %(progress.speed)s TITLE:%(info.title)s",
            "--progress-template", "postprocess:POSTPROCESS %(progress.status)s PATH:%(info._filename)s",
            targetURLString
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.currentDirectoryURL = staging
        process.standardInput = FileHandle.nullDevice
        process.arguments = arguments

        // Ensure Homebrew and user binary directories are in PATH for ffmpeg, deno, and python
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let searchDirs = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/opt/local/bin",
            "\(home)/.local/bin",
            "\(home)/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (searchDirs.joined(separator: ":")) + ":" + existingPath
        process.environment = env

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        let state = ExtractorOutput()
        let id = item.id

        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            _ = state.consume(data, staging: staging)
            if let t = state.title {
                Task { @MainActor in TransferService.shared.extractorTitle(id, t) }
            }
            if let snapshot = state.progress() {
                Task { @MainActor in
                    TransferService.shared.extractorProgress(id, snapshot: snapshot)
                }
            }
        }
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            state.note(error: data)
        }

        let began = Date()
        process.terminationHandler = { finished in
            output.fileHandleForReading.readabilityHandler = nil
            errors.fileHandleForReading.readabilityHandler = nil

            // Read any leftover buffered bytes without blocking
            let remainingOut = output.fileHandleForReading.availableData
            if !remainingOut.isEmpty {
                _ = state.consume(remainingOut, staging: staging)
            }
            let remainingErr = errors.fileHandleForReading.availableData
            if !remainingErr.isEmpty {
                state.note(error: remainingErr)
            }
            _ = state.flush(staging: staging)

            try? output.fileHandleForReading.close()
            try? errors.fileHandleForReading.close()

            let code = finished.terminationStatus
            let path = state.path
            let title = state.title
            let reason = state.errorSummary
            Task { @MainActor in
                if let title {
                    TransferService.shared.extractorTitle(id, title)
                }
                TransferService.shared.extractorFinished(id, exit: code, path: path, staging: staging, since: began, reason: reason)
            }
        }

        do {
            running[id] = process
            try process.run()
        } catch {
            running[id] = nil
            fallbackToPage(item: item, url: url)
        }
    }

    fileprivate func extractorProgress(_ id: UUID, snapshot: ExtractorOutput.Snapshot) {
        guard !cancelled.contains(id) else { return }
        if snapshot.isPostProcessing {
            engine?.setStatusHint(id, hint: snapshot.postProcessingHint ?? "Finalizing…")
            let tot = max(snapshot.total ?? 0, snapshot.downloaded)
            engine?.liveProgress(id, downloaded: tot, total: tot > 0 ? tot : nil, speed: 0)
        } else {
            engine?.setStatusHint(id, hint: nil)
            engine?.liveProgress(id, downloaded: snapshot.downloaded, total: snapshot.total, speed: snapshot.speed)
        }
    }

    /// The extractor knows the real title, so the row stops showing a guess made from the URL.
    fileprivate func extractorTitle(_ id: UUID, _ title: String) {
        guard !cancelled.contains(id) else { return }
        engine?.retitle(id, to: title)
    }

    private func extractorFinished(_ id: UUID, exit: Int32, path: String?, staging: URL, since: Date, reason: String?) {
        running[id] = nil
        guard !cancelled.contains(id) else {
            // Paused: keep the staged .part so a resume continues where it stopped.
            // A removed item's staging is cleaned up by cancel().
            if engine?.item(with: id) == nil {
                try? FileManager.default.removeItem(at: staging)
            }
            return
        }
        guard let item = engine?.item(with: id) else {
            try? FileManager.default.removeItem(at: staging)
            return
        }

        // Resolve finished file on disk: check direct path first, then scan staging directory
        var targetFile: URL? = nil
        if let path {
            if FileManager.default.fileExists(atPath: path) {
                targetFile = URL(fileURLWithPath: path)
            } else {
                let flacPath = (path as NSString).deletingPathExtension + ".flac"
                if FileManager.default.fileExists(atPath: flacPath) {
                    targetFile = URL(fileURLWithPath: flacPath)
                }
            }
        }

        // If not found by direct path, ALWAYS scan staging directory for finished file
        if targetFile == nil, let files = try? FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            let candidates = files.filter {
                let ext = $0.pathExtension.lowercased()
                let sz = (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return sz > 1_000 && !$0.lastPathComponent.hasPrefix(".") && !ext.hasPrefix("part") && !ext.hasPrefix("ytdl")
            }
            let sorted = candidates.sorted { f1, f2 in
                let ext1 = f1.pathExtension.lowercased()
                let ext2 = f2.pathExtension.lowercased()
                if ext1 == "flac" && ext2 != "flac" { return true }
                if ext2 == "flac" && ext1 != "flac" { return false }
                let s1 = (try? f1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let s2 = (try? f2.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return s1 > s2
            }
            targetFile = sorted.first
        }

        // Move the staged file into the downloads folder, under its real name.
        if let targetFile, FileManager.default.fileExists(atPath: targetFile.path) {
            let hint = item.kind == .file ? "Finalizing download…" : (item.kind == .audio ? "Finalizing audio…" : "Finalizing universal video…")
            engine?.setStatusHint(id, hint: hint)
            Task.detached(priority: .userInitiated) {
                let verifiedFile = Self.ensureUniversalVideo(at: targetFile)
                await MainActor.run {
                    if let destination = self.adopt(verifiedFile, for: item) {
                        try? FileManager.default.removeItem(at: staging)
                        self.complete(id, path: destination.path)
                    } else {
                        try? FileManager.default.removeItem(at: staging)
                        self.finishFailure(id: id, "Couldn't write the file into \(Self.displayFolder(item.destinationFolder)).")
                    }
                }
            }
            return
        }
        try? FileManager.default.removeItem(at: staging)

        // For media URLs (video, audio, clip), fail directly rather than saving an HTML page
        if item.kind == .video || item.kind == .audio || item.kind == .clip {
            finishFailure(id: id, reason ?? "The download did not produce a valid media file.")
        } else if let url = targets[id] {
            fallbackToPage(item: item, url: url, reason: reason)
        } else {
            finishFailure(id: id, reason ?? "The download failed.")
        }
    }

    /// Moves a finished staged file into the item's download folder under a unique name.
    private func adopt(_ staged: URL, for item: DownloadItem) -> URL? {
        let folder = Self.folderURL(for: item.destinationFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = (staged.lastPathComponent as NSString).deletingPathExtension
        let ext = (staged.pathExtension as NSString).lowercased
        var baseName = (item.kind == .audio && !item.title.isEmpty) ? item.title : (stem.isEmpty ? item.title : stem)
        if item.kind == .audio, let artist = item.audioArtist, !artist.isEmpty, !baseName.lowercased().contains(artist.lowercased()) {
            baseName = "\(artist) - \(baseName)"
        }
        baseName = baseName.replacingOccurrences(of: "/", with: "-")
                           .replacingOccurrences(of: ":", with: " - ")
                           .replacingOccurrences(of: "\"", with: "")
                           .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedExt: String
        let isLossless = item.formatLabel.uppercased() == "LOSSLESS" || item.formatLabel.uppercased() == "FLAC" || item.qualityLabel.uppercased().contains("LOSSLESS") || item.qualityLabel.uppercased().contains("FLAC")
        if isLossless {
            resolvedExt = "flac"
        } else {
            resolvedExt = ext.isEmpty ? "bin" : ext
        }

        var sourceStaged = staged
        if isLossless && ext != "flac", let ffmpeg = Self.tool("ffmpeg") {
            let flacStaged = staged.deletingPathExtension().appendingPathExtension("flac")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ffmpeg)
            proc.standardInput = FileHandle.nullDevice
            proc.arguments = ["-y", "-nostdin", "-i", staged.path, "-c:a", "flac", flacStaged.path]
            try? proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: flacStaged.path) {
                try? FileManager.default.removeItem(at: staged)
                sourceStaged = flacStaged
            }
        }

        let destination = Self.uniqueURL(
            in: folder,
            base: baseName,
            ext: resolvedExt
        )
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: sourceStaged, to: destination)
            Self.tagAudioMetadata(file: destination, item: item)
            engine?.retitle(item.id, to: destination.lastPathComponent)
            return destination
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceStaged, to: destination)
                try? FileManager.default.removeItem(at: sourceStaged)
                Self.tagAudioMetadata(file: destination, item: item)
                engine?.retitle(item.id, to: destination.lastPathComponent)
                return destination
            } catch {
                return nil
            }
        }
    }

    /// Completes an item only when a non-empty file is genuinely on disk.
    private func complete(_ id: UUID, path: String) {
        started.remove(id)
        retryTasks[id]?.cancel()
        retryTasks[id] = nil
        direct[id] = nil
        lastSample[id] = nil
        currentSpeed[id] = nil
        let url = URL(fileURLWithPath: path)
        let size = Self.fileSize(url)
        guard FileManager.default.fileExists(atPath: path), size > 0 else {
            try? FileManager.default.removeItem(at: url)
            finishFailure(id: id, "The finished file is missing from disk.")
            return
        }
        engine?.liveCompleted(id, filePath: path, bytes: size)
    }

    // MARK: Page fallback

    private func fallbackToPage(item: DownloadItem, url: URL, reason: String? = nil) {
        let host = url.host?.lowercased() ?? ""
        if LinkInspector.isVideoSite(host) || item.kind == .video || item.kind == .audio || item.kind == .clip {
            finishFailure(id: item.id, reason ?? "Video extraction failed. Please ensure yt-dlp is installed.")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        URLSession.shared.dataTask(with: request) { data, response, error in
            let html = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let title = TransferService.htmlTitle(html)
            let media = TransferService.mediaURL(in: html, base: url)
            Task { @MainActor in
                self.receivedPage(item: item, data: data, html: html, title: title, media: media, error: error, reason: reason)
            }
        }.resume()
    }

    private func receivedPage(item: DownloadItem, data: Data?, html: String, title: String?, media: URL?, error: Error?, reason: String?) {
        guard !cancelled.contains(item.id), let current = engine?.item(with: item.id) else { return }
        if let title, !title.isEmpty {
            engine?.retitle(item.id, to: title)
        }
        if let media {
            downloadDirect(item: engine?.item(with: item.id) ?? current, url: media)
            return
        }
        if let data, !data.isEmpty, !html.isEmpty {
            savePage(data, item: engine?.item(with: item.id) ?? current)
            return
        }
        finishFailure(id: item.id, reason ?? error?.localizedDescription ?? "Nothing at that link could be downloaded.")
    }

    /// A page with no media of its own is still worth keeping: save the document itself.
    private func savePage(_ data: Data, item: DownloadItem) {
        if let url = URL(string: item.urlString) {
            let host = url.host?.lowercased() ?? ""
            if LinkInspector.isVideoSite(host) || item.kind == .video || item.kind == .audio || item.kind == .clip {
                downloadWithExtractor(item: item, url: url)
                return
            }
        }
        let folder = Self.folderURL(for: item.destinationFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let html = String(data: data, encoding: .utf8) ?? ""
        let title = Self.htmlTitle(html) ?? item.title
        engine?.retitle(item.id, to: title)
        let destination = Self.uniqueURL(in: folder, base: title, ext: "html")
        do {
            try data.write(to: destination, options: .atomic)
            complete(item.id, path: destination.path)
        } catch {
            finishFailure(id: item.id, error.localizedDescription)
        }
    }

    private func finishFailure(id: UUID, _ message: String) {
        guard !cancelled.contains(id) else { return }
        started.remove(id)
        retryTasks[id]?.cancel()
        retryTasks[id] = nil
        if var state = direct[id] {
            state.task?.cancel()
            closeHandle(&state)
        }
        direct[id] = nil
        running[id] = nil
        lastSample[id] = nil
        currentSpeed[id] = nil
        let clean = Self.cleanError(message)
        engine?.liveFailed(id, message: clean)
        model?.reportFailedTransfer(id: id, message: clean)
    }

    // MARK: Files

    private func moveToFolder(_ temp: URL, item: DownloadItem, mime: String?, suggested: String?) -> URL? {
        let folder = Self.folderURL(for: item.destinationFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fromURL = URL(string: item.urlString)?.pathExtension ?? ""
        var ext = fromURL.lowercased()
        if ext.isEmpty || ext.count > 6 {
            ext = Self.extensionFor(mime: mime) ?? (suggested.map { ($0 as NSString).pathExtension.lowercased() } ?? "bin")
        }
        if item.formatLabel.uppercased() == "LOSSLESS" || item.formatLabel.uppercased() == "FLAC" || item.qualityLabel.uppercased().contains("LOSSLESS") || item.qualityLabel.uppercased().contains("FLAC") {
            ext = "flac"
        } else if item.kind == .audio && (ext.isEmpty || ext == "bin") {
            ext = "m4a"
        }

        // Sniff magic bytes if extension is unknown or binary
        if ext.isEmpty || ext == "bin" {
            if let handle = try? FileHandle(forReadingFrom: temp) {
                let header = handle.readData(ofLength: 16)
                try? handle.close()
                if header.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
                    ext = "png"
                } else if header.starts(with: [0xFF, 0xD8, 0xFF]) {
                    ext = "jpg"
                } else if header.count >= 12,
                          header[0] == 0x52, header[1] == 0x49, header[2] == 0x46, header[3] == 0x46, // RIFF
                          header[8] == 0x57, header[9] == 0x45, header[10] == 0x42, header[11] == 0x50 { // WEBP
                    ext = "webp"
                } else if header.starts(with: [0x47, 0x49, 0x46, 0x38]) { // GIF8
                    ext = "gif"
                } else if header.starts(with: [0x25, 0x50, 0x44, 0x46]) { // %PDF
                    ext = "pdf"
                } else if header.starts(with: [0x50, 0x4B, 0x03, 0x04]) { // PK.. (ZIP)
                    ext = "zip"
                }
            }
        }
        if ext.isEmpty { ext = "bin" }

        var stem = (suggested as NSString?)?.deletingPathExtension ?? ""
        let generic: Set<String> = ["", "download", "file", "index", "unknown", "data", "uc"]
        if item.kind == .audio {
            var songStem = item.title
            if let artist = item.audioArtist, !artist.isEmpty, !songStem.lowercased().contains(artist.lowercased()) {
                songStem = "\(artist) - \(songStem)"
            }
            stem = songStem
        } else if generic.contains(stem.lowercased()) || stem.count > 100 || stem.lowercased().hasPrefix("file-") || item.urlString.contains("oaiusercontent.com") {
            stem = item.title
        }
        stem = stem.replacingOccurrences(of: "/", with: "-")
                   .replacingOccurrences(of: ":", with: " - ")
                   .replacingOccurrences(of: "\"", with: "")
                   .trimmingCharacters(in: .whitespacesAndNewlines)

        let destination = Self.uniqueURL(in: folder, base: stem, ext: ext)
        var sourceFile = temp
        let isLossless = item.formatLabel.uppercased() == "LOSSLESS" || item.formatLabel.uppercased() == "FLAC" || item.qualityLabel.uppercased().contains("LOSSLESS") || item.qualityLabel.uppercased().contains("FLAC")
        if isLossless && temp.pathExtension.lowercased() != "flac", let ffmpeg = Self.tool("ffmpeg") {
            let flacTemp = temp.deletingPathExtension().appendingPathExtension("flac")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ffmpeg)
            proc.standardInput = FileHandle.nullDevice
            proc.arguments = ["-y", "-nostdin", "-i", temp.path, "-c:a", "flac", flacTemp.path]
            try? proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: flacTemp.path) {
                try? FileManager.default.removeItem(at: temp)
                sourceFile = flacTemp
            }
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: sourceFile, to: destination)
            Self.tagAudioMetadata(file: destination, item: item)
            engine?.retitle(item.id, to: destination.lastPathComponent)
            return destination
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceFile, to: destination)
                try? FileManager.default.removeItem(at: sourceFile)
                Self.tagAudioMetadata(file: destination, item: item)
                engine?.retitle(item.id, to: destination.lastPathComponent)
                return destination
            } catch {
                return nil
            }
        }
    }

    /// Embeds cover artwork, artist, album, and song title into downloaded audio files using ffmpeg.
    private static func tagAudioMetadata(file: URL, item: DownloadItem) {
        guard item.kind == .audio else { return }
        guard let ffmpeg = Self.tool("ffmpeg") else { return }

        let ext = file.pathExtension.lowercased()
        guard ext == "m4a" || ext == "mp3" || ext == "flac" || ext == "mp4" else { return }

        // Download cover artwork if available
        var tempCoverURL: URL? = nil
        if let coverStr = item.audioCoverURL, let cURL = URL(string: coverStr) {
            let tempDir = FileManager.default.temporaryDirectory
            let coverPath = tempDir.appendingPathComponent("cover_\(UUID().uuidString).jpg")
            if let data = try? Data(contentsOf: cURL), !data.isEmpty {
                try? data.write(to: coverPath)
                tempCoverURL = coverPath
            }
        }

        let taggedTemp = file.deletingLastPathComponent().appendingPathComponent("tagged_\(UUID().uuidString).\(ext)")

        var args = ["-y", "-nostdin", "-i", file.path]
        if let tempCoverURL, FileManager.default.fileExists(atPath: tempCoverURL.path), ext != "flac" {
            args += ["-i", tempCoverURL.path, "-map", "0:a", "-map", "1:v", "-c", "copy", "-disposition:v:0", "attached_pic"]
        } else {
            args += ["-c", "copy"]
        }

        // Add metadata tags
        let title = item.title
        args += ["-metadata", "title=\(title)"]
        if let artist = item.audioArtist, !artist.isEmpty {
            args += ["-metadata", "artist=\(artist)"]
        }
        if let album = item.audioAlbum, !album.isEmpty {
            args += ["-metadata", "album=\(album)"]
        }

        args.append(taggedTemp.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: ffmpeg)
        proc.standardInput = FileHandle.nullDevice
        proc.arguments = args
        try? proc.run()
        proc.waitUntilExit()

        if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: taggedTemp.path) {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.moveItem(at: taggedTemp, to: file)
        } else {
            try? FileManager.default.removeItem(at: taggedTemp)
        }

        if let tempCoverURL {
            try? FileManager.default.removeItem(at: tempCoverURL)
        }
    }

    // MARK: Helpers

    nonisolated static func tool(_ name: String) -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Library/Application Support/Edit.or.lynx/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/opt/homebrew/sbin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/local/sbin/\(name)",
            "/opt/local/bin/\(name)",
            "\(home)/.local/bin/\(name)",
            "\(home)/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func height(for quality: String) -> Int {
        let text = quality.lowercased()
        if text.contains("4k") || text.contains("2160") { return 2160 }
        if text.contains("1440") { return 1440 }
        if text.contains("1080") { return 1080 }
        if text.contains("720") { return 720 }
        if text.contains("480") { return 480 }
        if text.contains("360") { return 360 }
        return 1080
    }

    private static func extensionFor(mime: String?) -> String? {
        guard let mime = mime?.lowercased() else { return nil }
        if mime.contains("html") { return "html" }
        if mime.contains("mp4") { return "mp4" }
        if mime.contains("mpeg") && mime.contains("audio") { return "mp3" }
        if mime.contains("quicktime") { return "mov" }
        if mime.contains("webm") { return "webm" }
        if mime.contains("pdf") { return "pdf" }
        if mime.contains("zip") { return "zip" }
        if mime.contains("m4a") || mime.contains("aac") { return "m4a" }
        if mime.contains("flac") { return "flac" }
        if mime.contains("wav") { return "wav" }
        if mime.contains("png") { return "png" }
        if mime.contains("jpeg") || mime.contains("jpg") { return "jpg" }
        if mime.contains("webp") { return "webp" }
        if mime.contains("avif") { return "avif" }
        if mime.contains("svg") { return "svg" }
        if mime.contains("gif") { return "gif" }
        if mime.contains("heic") { return "heic" }
        if mime.contains("tiff") { return "tiff" }
        if mime.contains("json") { return "json" }
        if mime.contains("text/plain") { return "txt" }
        return nil
    }

    nonisolated static func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func newestFile(in folder: URL, after date: Date) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let recent = items.filter { url in
            guard !url.pathExtension.isEmpty, url.pathExtension != "part" else { return false }
            let attributes = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = attributes?.contentModificationDate ?? .distantPast
            let size = attributes?.fileSize ?? 0
            return modified >= date.addingTimeInterval(-2) && size > 0
        }
        return recent.max { a, b in
            let left = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
    }

    nonisolated static func ensureUniversalVideo(at url: URL) -> URL {
        let ext = url.pathExtension.lowercased()
        guard ext == "mp4" || ext == "m4v" || ext == "mov" || ext == "webm" || ext == "mkv" else {
            return url
        }

        guard let ffmpeg = tool("ffmpeg") else {
            return url
        }

        var needsConversion = false
        var copyVideo = false
        var copyAudio = false

        if let ffprobe = tool("ffprobe") {
            let vCodec = probeStreamCodec(ffprobe: ffprobe, url: url, streamType: "v")
            let aCodec = probeStreamCodec(ffprobe: ffprobe, url: url, streamType: "a")

            let isVUniversal = vCodec == "h264" || vCodec == "hevc" || vCodec == "avc1"
            let isAUniversal = aCodec == "aac" || aCodec == "mp3" || aCodec == "mp4a" || aCodec.isEmpty

            if isVUniversal && isAUniversal && (ext == "mp4" || ext == "m4v") {
                return url
            }

            needsConversion = true
            copyVideo = isVUniversal
            copyAudio = isAUniversal
        } else {
            if ext == "webm" || ext == "mkv" {
                needsConversion = true
            } else {
                return url
            }
        }

        guard needsConversion else { return url }

        let tempOutput = url.deletingPathExtension().appendingPathExtension("universal.mp4")
        try? FileManager.default.removeItem(at: tempOutput)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.standardInput = FileHandle.nullDevice

        var args = ["-y", "-nostdin", "-i", url.path]
        if copyVideo {
            args += ["-c:v", "copy"]
        } else {
            args += ["-c:v", "libx264", "-preset", "fast", "-crf", "21"]
        }

        if copyAudio {
            args += ["-c:a", "copy"]
        } else {
            args += ["-c:a", "aac", "-b:a", "192k"]
        }

        args += ["-movflags", "+faststart", tempOutput.path]
        process.arguments = args

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0,
               FileManager.default.fileExists(atPath: tempOutput.path),
               fileSize(tempOutput) > 1000 {
                try? FileManager.default.removeItem(at: url)
                return tempOutput
            }
        } catch {}

        return url
    }

    nonisolated static func probeStreamCodec(ffprobe: String, url: URL, streamType: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobe)
        process.standardInput = FileHandle.nullDevice
        process.arguments = [
            "-v", "error",
            "-nostdin",
            "-select_streams", "\(streamType):0",
            "-show_entries", "stream=codec_name",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } catch {
            return ""
        }
    }

    static func folderURL(for folder: String) -> URL {
        let clean = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = clean.isEmpty ? "~/Downloads/Edit.or.lynx" : clean
        let path = (resolved as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func displayFolder(_ folder: String) -> String {
        folder.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    static func uniqueURL(in folder: URL, base: String, ext: String) -> URL {
        var stem = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: " -")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "|", with: "-")
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stem.isEmpty { stem = "Download" }
        if stem.count > 120 { stem = String(stem.prefix(120)) }
        if stem.lowercased().hasSuffix("." + ext.lowercased()) {
            stem = String(stem.dropLast(ext.count + 1))
        }
        var candidate = folder.appendingPathComponent("\(stem).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem) \(counter).\(ext)")
            counter += 1
            if counter > 999 { break }
        }
        return candidate
    }

    // MARK: Content-Range parsing

    /// "bytes 100-999/1000" → 100; nil when absent or not a byte range.
    nonisolated static func rangeStart(_ header: String?) -> Int64? {
        guard let header, header.lowercased().hasPrefix("bytes") else { return nil }
        let rest = header.dropFirst("bytes".count).trimmingCharacters(in: .whitespaces)
        guard let dash = rest.firstIndex(of: "-") else { return nil }
        return Int64(rest[..<dash].trimmingCharacters(in: .whitespaces))
    }

    /// "bytes 100-999/1000" → 1000; nil when absent or unknown ("*").
    nonisolated static func rangeTotal(_ header: String?) -> Int64? {
        guard let header, header.lowercased().hasPrefix("bytes") else { return nil }
        let rest = header.dropFirst("bytes".count).trimmingCharacters(in: .whitespaces)
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let total = rest[rest.index(after: slash)...].trimmingCharacters(in: .whitespaces)
        guard total != "*" else { return nil }
        return Int64(total)
    }

    /// Faults worth an automatic retry with backoff; everything else fails at once.
    nonisolated private static func isTransient(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed, .notConnectedToInternet, .cannotLoadFromNetwork,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }

    private static func cleanError(_ message: String) -> String {
        let firstLine = message
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? message
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "The download failed." }
        if trimmed.count > 180 { return String(trimmed.prefix(177)) + "…" }
        return trimmed
    }

    // MARK: Page markup

    nonisolated static func htmlTitle(_ html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']"#,
            #"<title[^>]*>([^<]+)</title>"#
        ]
        for pattern in patterns {
            if let raw = firstMatch(html, pattern) {
                let clean = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { return clean }
            }
        }
        return nil
    }

    nonisolated static func mediaURL(in html: String, base: URL) -> URL? {
        let patterns = [
            #"<meta[^>]+property=["']og:video:secure_url["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+property=["']og:video["'][^>]+content=["']([^"']+)["']"#,
            #"<video[^>]+src=["']([^"']+)["']"#,
            #"<source[^>]+src=["']([^"']+\.(?:mp4|m4v|webm|mov)[^"']*)["']"#,
            #"https?://[^"'\s<>]+\.(?:mp4|m4v|webm|mov)(?:\?[^"'\s<>]*)?"#
        ]
        for pattern in patterns {
            if let raw = firstMatch(html, pattern) {
                let text = decodeEntities(raw)
                if let url = URL(string: text, relativeTo: base)?.absoluteURL,
                   let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                    return url
                }
            }
        }
        return nil
    }

    nonisolated private static func firstMatch(_ text: String, _ pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1,
              let found = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[found])
    }

    nonisolated private static func decodeEntities(_ text: String) -> String {
        var value = text
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        return value
    }
}

// MARK: - URLSession

extension TransferService: URLSessionDataDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let raw = dataTask.taskDescription, let id = UUID(uuidString: raw) else {
            completionHandler(.cancel)
            return
        }
        Task { @MainActor in
            completionHandler(TransferService.shared.handleResponse(id: id, response: response))
        }
    }

    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let raw = dataTask.taskDescription, let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in
            TransferService.shared.appendData(id, data)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let raw = task.taskDescription, let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in
            TransferService.shared.directCompleted(id, error: error)
        }
    }
}

// MARK: - Extractor output

/// Collects `yt-dlp` output off the pipe and keeps the last progress line and file path.
private final class ExtractorOutput: @unchecked Sendable {
    struct Snapshot {
        var downloaded: Int64
        var total: Int64?
        var speed: Double
        var isPostProcessing: Bool
        var postProcessingHint: String?
    }

    private let lock = NSLock()
    private var buffer = Data()
    private var lastPath: String?
    private var errors: [String] = []
    private var currentStreamDownloaded: Int64 = 0
    private var currentStreamTotal: Int64 = 0
    private var accumulatedDownloaded: Int64 = 0
    private var accumulatedTotal: Int64 = 0
    private var speed: Double = 0
    private var lastEmit: TimeInterval = 0
    private var isPostProcessing: Bool = false
    private var postProcessingHint: String?
    private var detectedTitle: String?

    var path: String? {
        lock.lock(); defer { lock.unlock() }
        return lastPath
    }

    var title: String? {
        lock.lock(); defer { lock.unlock() }
        return detectedTitle
    }

    var errorSummary: String? {
        lock.lock(); defer { lock.unlock() }
        return errors.last
    }

    func note(error data: Data) {
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(whereSeparator: \.isNewline) {
            let clean = line.trimmingCharacters(in: .whitespaces)
            guard clean.contains("ERROR") || clean.contains("error") || clean.contains("Unsupported") else { continue }
            lock.lock()
            errors.append(clean)
            if errors.count > 6 { errors.removeFirst() }
            lock.unlock()
        }
    }

    /// Feed raw bytes; returns the complete lines they finish.
    func consume(_ data: Data, staging: URL) -> [String] {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let index = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let slice = buffer[buffer.startIndex..<index]
            buffer.removeSubrange(buffer.startIndex...index)
            if let text = String(data: slice, encoding: .utf8) {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    lines.append(clean)
                }
            }
        }
        if buffer.count > 64_000 { buffer.removeAll() }
        lock.unlock()

        for line in lines {
            parseLine(line, staging: staging)
        }
        return lines
    }

    /// Flushes any remaining bytes in the buffer when the process terminates.
    func flush(staging: URL) -> [String] {
        lock.lock()
        var lines: [String] = []
        if !buffer.isEmpty {
            if let text = String(data: buffer, encoding: .utf8) {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    lines.append(clean)
                }
            }
            buffer.removeAll()
        }
        lock.unlock()

        for line in lines {
            parseLine(line, staging: staging)
        }
        return lines
    }

    private func parseLine(_ line: String, staging: URL) {
        if line.hasPrefix("[download] Destination: ") {
            let p = String(line.dropFirst("[download] Destination: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
            lock.lock()
            if currentStreamDownloaded > 0 {
                accumulatedDownloaded += currentStreamDownloaded
                accumulatedTotal += (currentStreamTotal > 0 ? currentStreamTotal : currentStreamDownloaded)
                currentStreamDownloaded = 0
                currentStreamTotal = 0
            }
            lastPath = full
            lock.unlock()
        } else if line.hasPrefix("[download] ") && line.hasSuffix(" has already been downloaded") {
            let p = String(line.dropFirst("[download] ".count).dropLast(" has already been downloaded".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
            lock.lock()
            lastPath = full
            lock.unlock()
        } else if line.hasPrefix("[Merger] Merging formats into ") {
            var p = String(line.dropFirst("[Merger] Merging formats into ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if p.hasPrefix("\"") && p.hasSuffix("\"") && p.count >= 2 {
                p = String(p.dropFirst().dropLast())
            }
            let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
            lock.lock()
            lastPath = full
            isPostProcessing = true
            postProcessingHint = "Merging video & audio…"
            lock.unlock()
        } else if line.hasPrefix("[ExtractAudio] Destination: ") {
            let p = String(line.dropFirst("[ExtractAudio] Destination: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
            lock.lock()
            lastPath = full
            isPostProcessing = true
            postProcessingHint = "Converting Lossless audio…"
            lock.unlock()
        } else if line.hasPrefix("POSTPROCESS started") {
            lock.lock()
            isPostProcessing = true
            postProcessingHint = "Finalizing download…"
            if let pathRange = line.range(of: "PATH:") {
                let p = String(line[pathRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !p.isEmpty && p != "NA" {
                    let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
                    if lastPath == nil || lastPath?.hasSuffix(".part") == true {
                        lastPath = full
                    }
                }
            }
            lock.unlock()
        } else if line.hasPrefix("POSTPROCESS finished") {
            lock.lock()
            isPostProcessing = true
            postProcessingHint = "Saving file…"
            if let pathRange = line.range(of: "PATH:") {
                let p = String(line[pathRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !p.isEmpty && p != "NA" {
                    let full = p.hasPrefix("/") ? p : staging.appendingPathComponent(p).path
                    if lastPath == nil || lastPath?.hasSuffix(".part") == true {
                        lastPath = full
                    }
                }
            }
            lock.unlock()
        } else if line.hasPrefix("/") {
            lock.lock()
            lastPath = line
            lock.unlock()
        }

        if let titleRange = line.range(of: "TITLE:") {
            let t = String(line[titleRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && t != "NA" {
                lock.lock()
                detectedTitle = t
                lock.unlock()
            }
        }

        if line.hasPrefix("PPO ") || line.hasPrefix("download:PPO ") {
            let raw = line.hasPrefix("download:PPO ") ? String(line.dropFirst("download:PPO ".count)) : String(line.dropFirst("PPO ".count))
            let tokens = raw.components(separatedBy: " TITLE:")[0].split(separator: " ")
            if tokens.count >= 2 {
                let got = Int64(tokens[0].trimmingCharacters(in: .whitespaces)) ?? 0
                let tot1 = Int64(tokens[1].trimmingCharacters(in: .whitespaces))
                let tot2 = tokens.count > 2 ? Int64(tokens[2].trimmingCharacters(in: .whitespaces)) : nil
                let totVal = (tot1 != nil && tot1! > 0) ? tot1 : ((tot2 != nil && tot2! > 0) ? tot2 : nil)
                let spdVal = tokens.count > 3 ? Double(tokens[3].trimmingCharacters(in: .whitespaces)) : nil
                lock.lock()
                if got > 0 { currentStreamDownloaded = got }
                if let totVal, totVal > 0 { currentStreamTotal = totVal }
                if let spdVal, spdVal > 0 { speed = spdVal }
                lock.unlock()
            }
        } else if line.hasPrefix("download:") {
            let parts = line.dropFirst("download:".count).split(separator: " ")
            guard parts.count >= 2,
                  let got = Int64(parts[0].trimmingCharacters(in: .whitespaces)) else { return }
            let totalValue = Int64(parts[1].trimmingCharacters(in: .whitespaces))
            let speedValue = parts.count > 2 ? Double(parts[2].trimmingCharacters(in: .whitespaces)) : nil
            lock.lock()
            currentStreamDownloaded = got
            if let totalValue, totalValue > 0 { currentStreamTotal = totalValue }
            if let speedValue, speedValue > 0 { speed = speedValue }
            lock.unlock()
        } else if line.hasPrefix("[download]") && line.contains("%") {
            // Standard yt-dlp line fallback: [download]  45.0% of ~ 25.00MiB at  1.50MiB/s ETA 00:09
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let pctIdx = parts.firstIndex(where: { $0.hasSuffix("%") }) {
                let pctClean = parts[pctIdx].replacingOccurrences(of: "%", with: "")
                if let pct = Double(pctClean) {
                    var totalParsed: Int64? = nil
                    if let ofIdx = parts.firstIndex(of: "of"), ofIdx + 1 < parts.count {
                        let token = parts[ofIdx + 1] == "~" && ofIdx + 2 < parts.count ? parts[ofIdx + 2] : parts[ofIdx + 1]
                        totalParsed = Self.parseBytesString(token)
                    }
                    var speedParsed: Double? = nil
                    if let atIdx = parts.firstIndex(of: "at"), atIdx + 1 < parts.count {
                        speedParsed = Self.parseSpeedString(parts[atIdx + 1])
                    }
                    lock.lock()
                    if let totalParsed, totalParsed > 0 {
                        currentStreamTotal = totalParsed
                        currentStreamDownloaded = max(currentStreamDownloaded, Int64(Double(totalParsed) * (pct / 100.0)))
                    }
                    if let speedParsed, speedParsed > 0 {
                        speed = speedParsed
                    }
                    lock.unlock()
                }
            }
        }
    }

    private static func parseBytesString(_ raw: String) -> Int64? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let numStr = clean.filter { "0123456789.".contains($0) }
        guard let num = Double(numStr) else { return nil }
        let lower = clean.lowercased()
        if lower.contains("gib") || lower.contains("gb") { return Int64(num * 1024 * 1024 * 1024) }
        if lower.contains("mib") || lower.contains("mb") { return Int64(num * 1024 * 1024) }
        if lower.contains("kib") || lower.contains("kb") { return Int64(num * 1024) }
        return Int64(num)
    }

    private static func parseSpeedString(_ raw: String) -> Double? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let numStr = clean.filter { "0123456789.".contains($0) }
        guard let num = Double(numStr) else { return nil }
        let lower = clean.lowercased()
        if lower.contains("gib") || lower.contains("gb") { return num * 1024 * 1024 * 1024 }
        if lower.contains("mib") || lower.contains("mb") { return num * 1024 * 1024 }
        if lower.contains("kib") || lower.contains("kb") { return num * 1024 }
        return num
    }

    func progress() -> Snapshot? {
        lock.lock(); defer { lock.unlock() }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastEmit >= 0.12 else { return nil }
        lastEmit = now

        let totalDownloaded = accumulatedDownloaded + currentStreamDownloaded
        let estTotal = (accumulatedTotal > 0 || currentStreamTotal > 0) ? (accumulatedTotal + currentStreamTotal) : nil
        return Snapshot(
            downloaded: totalDownloaded,
            total: estTotal,
            speed: isPostProcessing ? 0 : speed,
            isPostProcessing: isPostProcessing,
            postProcessingHint: postProcessingHint
        )
    }
}
