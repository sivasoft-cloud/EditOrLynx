import Foundation
import PounceCore

@MainActor
enum Checks {
    static var passed = 0
    static var failed = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passed += 1
        } else {
            failed += 1
            print("  ✗ \(message)")
        }
    }

    static func equal<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String) {
        check(lhs == rhs, "\(message) — expected \(rhs), got \(lhs)")
    }

    static func main() {
        print("Edit.or.lynx core checks")
        links()
        formatting()
        clipboard()
        clips()
        engine()
        demo()
        license()
        unknownSize()
        pauseContract()
        chatGPTAndImages()

        print("\n\(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }

    static func links() {
        let video = LinkInspector.inspect("https://northlight.films/films/northern-light-making-of")
        check(video != nil, "video link should parse")
        if let video {
            equal(video.kind, .video, "video kind")
            equal(video.title, "Northern Light Making Of", "video title")
            equal(video.qualities.count, 5, "quality count")
            equal(video.qualities.first?.label, "4K 60", "top quality")
            check(video.fullBytes > 1_000_000_000, "video size")
            check(video.suggestedFileName.hasSuffix(".mp4"), "suggested filename")
            check(!video.suggestedFileName.contains("/"), "filename has no slash")
            equal(video.duration, 1_528, "demo duration")
        }

        let playlist = LinkInspector.inspect("https://northlight.films/playlist?list=northern-series")
        check(playlist != nil, "playlist should parse")
        if let playlist {
            equal(playlist.kind, .playlist, "playlist kind")
            equal(playlist.playlist?.videos.count, 12, "playlist count")
            equal(playlist.playlist?.title, "Northern Series", "playlist title")
            check((playlist.playlist?.totalDuration ?? 0) > 5_000, "playlist duration")
        }

        let audio = LinkInspector.inspect("https://example.com/sound/field-recordings.m4a")
        equal(audio?.kind, .audio, "audio kind")
        equal(audio?.qualities.count, 2, "audio qualities")

        let file = LinkInspector.inspect("https://example.com/files/archive.zip")
        equal(file?.kind, .file, "file kind")
        equal(file?.title, "Archive", "file title")
        check((file?.fullBytes ?? 0) > 0, "file size")

        check(LinkInspector.inspect("not a link") == nil, "invalid link rejected")
        check(LinkInspector.inspect("ftp://example.com/file.zip") == nil, "ftp rejected")
        check(LinkInspector.inspect("") == nil, "empty rejected")
        equal(LinkInspector.titleFromURL(URL(string: "https://x.com/a/northern-light")!), "Northern Light", "title casing")
    }

    static func formatting() {
        equal(Fmt.bytes(9_400_000_000), "9.4 GB", "bytes GB")
        equal(Fmt.bytes(614_600_000), "614.6 MB", "bytes MB")
        equal(Fmt.bytes(255_000_000), "255 MB", "bytes integer MB")
        equal(Fmt.bytes(1_240_000_000), "1.24 GB", "bytes small GB")
        equal(Fmt.speed(109_700_000), "109.7 MB/s", "speed")
        equal(Fmt.eta(51), "51 s left", "eta seconds")
        check(Fmt.eta(80).contains("min"), "eta minutes")
        equal(Fmt.duration(1_528), "25:28", "duration minutes")
        equal(Fmt.duration(5_592), "1:33:12", "duration hours")
        equal(Fmt.shortDuration(35), "35 sec", "short duration")
        equal(Fmt.shortDuration(120), "2 min", "short minutes")
        equal(Fmt.speed(0), "—", "idle speed is a dash, never a fake rate")
        equal(Fmt.percent(-1), "0%", "percent clamps low")
        equal(Fmt.percent(9), "100%", "percent clamps high")
        equal(Fmt.bytes(-5), "0 B", "bytes clamp negative")
        equal(Fmt.eta(-5), "0 s left", "eta clamps negative")
        equal(Fmt.eta(65), "1 min left", "eta minute rounding")
    }

    static func clipboard() {
        equal(ClipboardClassifier.kind(for: "https://example.com/a"), .link, "https link")
        equal(ClipboardClassifier.kind(for: "www.example.com"), .link, "www link")
        equal(ClipboardClassifier.kind(for: "#FF9F0A"), .color, "hex color")
        equal(ClipboardClassifier.kind(for: "#fff"), .color, "short hex")
        equal(ClipboardClassifier.kind(for: "just some text"), .text, "plain text")
        equal(ClipboardClassifier.normalizeLink("www.example.com/a")?.scheme, "https", "normalized scheme")
        check(ClipboardClassifier.normalizeLink("hello") == nil, "non-link rejected")
    }

    static func clips() {
        let selection = ClipSelection(
            parts: [ClipPart(start: 250, end: 285)],
            format: .video,
            qualityLabel: "1080p"
        )
        equal(selection.totalSeconds, 35, "clip seconds")
        let estimate = selection.estimatedBytes(fullBytes: 1_660_000_000, fullDuration: 1_528, qualityMultiplier: 0.37)
        check(estimate > 5_000_000 && estimate < 30_000_000, "clip estimate range (\(estimate))")

        let video = ClipSelection(parts: [ClipPart(start: 0, end: 60)], format: .video)
        let audio = ClipSelection(parts: [ClipPart(start: 0, end: 60)], format: .audio)
        let videoBytes = video.estimatedBytes(fullBytes: 1_660_000_000, fullDuration: 1_528, qualityMultiplier: 0.37)
        let audioBytes = audio.estimatedBytes(fullBytes: 1_660_000_000, fullDuration: 1_528, qualityMultiplier: 0.37)
        check(audioBytes < videoBytes, "audio clip smaller than video")

        let vertical = ClipSelection(parts: [ClipPart(start: 0, end: 60)], format: .vertical)
        check(vertical.estimatedBytes(fullBytes: 1_660_000_000, fullDuration: 1_528, qualityMultiplier: 0.37) < videoBytes, "vertical clip smaller")
    }

    static func makeItem() -> DownloadItem {
        DownloadItem(
            title: "Test File.zip",
            sourceHost: "example.com",
            urlString: "https://example.com/file.zip",
            kind: .file,
            formatLabel: "ZIP",
            qualityLabel: "—",
            totalBytes: 1_000_000_000,
            state: .downloading,
            connectionCount: 32,
            baseSpeedPerConnection: 1_000_000,
            seed: 4
        )
    }

    static func engine() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        let normal = DownloadEngine(downloads: [makeItem()], now: start, randomize: false)
        normal.tick(now: start.addingTimeInterval(1))
        check(normal.downloads[0].downloadedBytes > 0, "tick advances")
        check(normal.downloads[0].currentSpeed > 0, "tick measures speed")

        let paused = DownloadEngine(downloads: [makeItem()], now: start, randomize: false)
        paused.tick(now: start.addingTimeInterval(1))
        let reached = paused.downloads[0].downloadedBytes
        paused.pause(paused.downloads[0].id)
        paused.tick(now: start.addingTimeInterval(2))
        equal(paused.downloads[0].downloadedBytes, reached, "pause freezes progress")
        equal(paused.downloads[0].state, .paused, "paused state")
        paused.resume(paused.downloads[0].id)
        paused.tick(now: start.addingTimeInterval(3))
        check(paused.downloads[0].downloadedBytes > reached, "resume continues")

        var almost = makeItem()
        almost.downloadedBytes = 999_000_000
        let finisher = DownloadEngine(downloads: [almost], now: start, randomize: false)
        var completedTitle: String?
        finisher.onComplete = { completedTitle = $0.title }
        finisher.tick(now: start.addingTimeInterval(2))
        equal(finisher.downloads[0].state, .completed, "completion state")
        equal(finisher.downloads[0].progress, 1, "completion progress")
        equal(completedTitle, "Test File.zip", "completion callback")

        // A transfer that lands just short of the end must finish on that tick, not hover at 99%.
        var tail = makeItem()
        tail.totalBytes = 1_000_000_000
        tail.downloadedBytes = 999_400_000
        let tailEngine = DownloadEngine(downloads: [tail], now: start, randomize: false)
        tailEngine.tick(now: start.addingTimeInterval(1))
        equal(tailEngine.downloads[0].state, .completed, "no 99% stall")
        equal(tailEngine.downloads[0].progress, 1, "stalled progress snapped")

        let pathEngine = DownloadEngine(downloads: [makeItem()], now: start, randomize: false)
        pathEngine.setFilePath(pathEngine.downloads[0].id, path: "/tmp/Test File.zip")
        equal(pathEngine.downloads[0].filePath, "/tmp/Test File.zip", "delivered path stored")
        let roundTrip = try? JSONDecoder().decode(
            DownloadItem.self,
            from: JSONEncoder().encode(pathEngine.downloads[0])
        )
        equal(roundTrip?.filePath, "/tmp/Test File.zip", "delivered path persists")

        // Real transfers report their own bytes; the demo animation must leave them alone.
        var live = makeItem()
        live.liveTransfer = true
        live.totalBytes = 0
        live.downloadedBytes = 0
        let liveEngine = DownloadEngine(downloads: [live], now: start, randomize: false)
        var startedID: UUID?
        liveEngine.onLivePending = { startedID = $0.id }
        liveEngine.tick(now: start.addingTimeInterval(1))
        equal(liveEngine.downloads[0].downloadedBytes, 0, "live transfer is not simulated")
        equal(startedID, live.id, "live transfer asked to start")

        liveEngine.liveProgress(live.id, downloaded: 400, total: 1_000, speed: 200)
        equal(liveEngine.downloads[0].progress, 0.4, "live progress comes from bytes")
        equal(liveEngine.downloads[0].totalBytes, 1_000, "live total from the server")

        liveEngine.liveCompleted(live.id, filePath: "/tmp/Movie.mp4", bytes: 1_000)
        equal(liveEngine.downloads[0].state, .completed, "live completion state")
        equal(liveEngine.downloads[0].progress, 1, "live completion progress")
        equal(liveEngine.downloads[0].filePath, "/tmp/Movie.mp4", "live file path")
        equal(liveEngine.activeCount, 0, "finished live item leaves the active list")

        var failing = makeItem()
        failing.liveTransfer = true
        let failEngine = DownloadEngine(downloads: [failing], now: start, randomize: false)
        failEngine.liveFailed(failing.id, message: "No route to host")
        equal(failEngine.downloads[0].state, .failed, "live failure state")
        equal(failEngine.downloads[0].errorMessage, "No route to host", "live failure message")

        var settings = EngineSettings()
        settings.maxConcurrent = 1
        var first = makeItem()
        first.state = .downloading
        var second = makeItem()
        second.title = "Second.zip"
        second.state = .queued
        second.addedAt = start.addingTimeInterval(1)
        let queue = DownloadEngine(downloads: [first, second], settings: settings, now: start, randomize: false)
        equal(queue.downloads.filter { $0.state == .downloading }.count, 1, "concurrency at launch")
        queue.pause(first.id)
        equal(queue.downloads.first(where: { $0.id == second.id })?.state, .downloading, "queued promoted")
        queue.resume(first.id)
        equal(queue.downloads.filter { $0.state == .downloading }.count, 1, "limit still respected")

        var turboSettings = EngineSettings()
        turboSettings.turboEnabled = true
        let turbo = DownloadEngine(downloads: [makeItem()], settings: turboSettings, now: start, randomize: false)
        turbo.tick(now: start.addingTimeInterval(1))
        check(turbo.downloads[0].currentSpeed > normal.downloads[0].currentSpeed, "turbo increases speed")

        equal(Fmt.percent(0.426), "43%", "percent formatting")
        check(DemoData.seedDownloads().count == 6, "demo downloads")
        equal(DemoData.seedDownloads().filter { $0.state == .downloading }.count, 1, "one active demo")
    }

    static func demo() {
        let items = DemoData.seedDownloads()
        check(items.contains { $0.state == .completed }, "completed demo items")
        check(items.contains { $0.kind == .audio }, "audio demo item")
        check(items.contains { $0.kind == .clip }, "clip demo item")
        let clipboard = DemoData.seedClipboard()
        equal(clipboard.count, 4, "demo clipboard")
        check(clipboard.contains { $0.kind == .color }, "color clipboard demo")
    }

    static func license() {
        check(ProKey.looksWellFormed("ELNK-AAAA-BBBB-CCCC-DDDD"), "well-formed key accepted")
        equal(ProKey.normalize(" elnk-aaaa-bbbb-cccc-dddd "), "ELNK-AAAA-BBBB-CCCC-DDDD", "key normalization")
        check(!ProKey.looksWellFormed("AAAA-BBBB-CCCC-DDDD"), "wrong prefix rejected")
        check(!ProKey.looksWellFormed("ELNK-AAAA-BBBB-CCCC"), "short key rejected")
        check(!ProKey.looksWellFormed("ELNK-AAAA-BBBB-CCCC-DDDD-EEEE"), "long key rejected")
        check(!ProKey.looksWellFormed("ELNK-AAAA-BBB!-CCCC-DDDD"), "bad character rejected")

        let now = Date()
        let fresh = License(
            key: "ELNK-AAAA-BBBB-CCCC-DDDD", keyID: "k1", plan: .pro, token: "header.payload.sig",
            expiresAt: now.addingTimeInterval(30 * 86_400), validatedAt: now
        )
        check(fresh.isUsable(now: now), "fresh license is usable")
        check(!fresh.needsRevalidation(now: now), "fresh license needs no revalidation")

        let expired = License(
            key: fresh.key, keyID: nil, plan: .pro, token: "header.payload.sig",
            expiresAt: now.addingTimeInterval(-60), validatedAt: now
        )
        check(!expired.isUsable(now: now), "expired key is refused")

        let stale = License(
            key: fresh.key, keyID: nil, plan: .pro, token: "header.payload.sig",
            expiresAt: now.addingTimeInterval(30 * 86_400),
            validatedAt: now.addingTimeInterval(-8 * 86_400)
        )
        check(!stale.isUsable(now: now), "offline grace runs out after 7 days")
        check(stale.needsRevalidation(now: now), "stale license asks to revalidate")

        equal(LicenseStatus().plan, Plan.free, "no license means Free")
        equal(LicenseStatus(license: expired).plan, Plan.free, "expired key falls back to Free")
        equal(LicenseStatus(license: fresh).plan, Plan.pro, "usable key reports Pro")
        equal(LicenseStatus().entitlements.maxConnections, 4, "free entitlements")

        var settings = EngineSettings()
        settings.connections = 32
        settings.maxConcurrent = 10
        settings.turboEnabled = true
        let free = PlanPolicy.clamp(settings: settings, plan: .free)
        equal(free.connections, 4, "free connection limit")
        equal(free.maxConcurrent, 2, "free concurrency limit")
        check(!free.turboEnabled, "turbo is Pro-only")
        let pro = PlanPolicy.clamp(settings: settings, plan: .pro)
        equal(pro.connections, 32, "pro keeps 32 connections")
        equal(pro.maxConcurrent, 10, "pro keeps 10 concurrent downloads")
        check(pro.turboEnabled, "pro allows turbo")

        check(PlanPolicy.allows(height: 1080, plan: .free), "free allows 1080p")
        check(!PlanPolicy.allows(height: 2160, plan: .free), "free blocks 4K")
        check(PlanPolicy.allows(height: 2160, plan: .pro), "pro allows 4K")
        equal(PlanPolicy.height(ofQuality: "4K 60"), 2160, "4K height parsed")
        equal(PlanPolicy.height(ofQuality: "1080p"), 1080, "1080p height parsed")
        equal(PlanPolicy.height(ofQuality: "320 kbps MP3"), 0, "audio has no height")
    }

    static func unknownSize() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var item = makeItem()
        item.liveTransfer = true
        item.totalBytes = 0
        item.downloadedBytes = 0
        let engine = DownloadEngine(downloads: [item], now: start, randomize: false)
        engine.liveStarted(item.id, totalBytes: nil)
        engine.liveProgress(item.id, downloaded: 12_345, total: nil, speed: 500)

        equal(engine.downloads[0].downloadedBytes, 12_345, "unknown size keeps real bytes")
        equal(engine.downloads[0].hasKnownSize, false, "unknown size stays unknown")
        check(engine.downloads[0].percentText == nil, "no percentage without a content length")
        equal(engine.downloads[0].currentSpeed, 500.0, "speed still measured")
        check(engine.downloads[0].eta == nil, "no ETA without a total")
        check(!engine.downloads[0].activeDetailLine.contains("%"), "unknown size row shows no percent")

        engine.pause(item.id)
        check(engine.downloads[0].activeDetailLine.hasPrefix("Paused"), "paused row says Paused")
        equal(engine.downloads[0].currentSpeed, 0.0, "paused row has no live speed")
    }

    static func pauseContract() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var settings = EngineSettings()
        settings.maxConcurrent = 1
        let engine = DownloadEngine(downloads: [], settings: settings, now: start, randomize: false)
        var pausedIDs: [UUID] = []
        var cancelledIDs: [UUID] = []
        engine.onLivePause = { pausedIDs.append($0) }
        engine.onLiveCancel = { cancelledIDs.append($0) }

        var a = makeItem()
        a.title = "First.zip"
        a.liveTransfer = true
        a.state = .queued
        a.addedAt = start
        var b = makeItem()
        b.title = "Second.zip"
        b.liveTransfer = true
        b.state = .queued
        b.addedAt = start.addingTimeInterval(1)
        engine.add(a)
        engine.add(b)

        equal(engine.downloads.first { $0.id == a.id }?.state, .downloading, "first download runs")
        equal(engine.downloads.first { $0.id == b.id }?.state, .queued, "second waits its turn")

        engine.pause(a.id)
        equal(pausedIDs, [a.id], "pause signals suspend, not removal")
        equal(cancelledIDs.count, 0, "pause must keep the partial file for resume")
        equal(engine.downloads.first { $0.id == a.id }?.state, .paused, "first is paused")
        equal(engine.downloads.first { $0.id == a.id }?.currentSpeed, 0.0, "paused speed is zero")
        equal(engine.downloads.first { $0.id == b.id }?.state, .downloading, "freed slot promotes the queue")

        engine.pauseAll()
        equal(engine.activeCount, 0, "pauseAll stops every live transfer")
        equal(pausedIDs.count, 2, "pauseAll suspends live transfers too")

        engine.remove(a.id)
        equal(cancelledIDs, [a.id], "removal cancels the transfer for good")

        engine.liveFailed(b.id, message: "The connection was lost.")
        equal(engine.downloads.first { $0.id == b.id }?.state, .failed, "failure recorded")
        equal(engine.downloads.first { $0.id == b.id }?.errorMessage, "The connection was lost.", "failure reason kept")
        engine.retry(b.id)
        equal(engine.downloads.first { $0.id == b.id }?.state, .downloading, "retry puts it back to work")

        engine.liveProgress(b.id, downloaded: 999_999_999, total: 1_000, speed: 10)
        equal(engine.downloads.first { $0.id == b.id }?.downloadedBytes, 1_000, "bytes clamp to the declared total")
        equal(engine.downloads.first { $0.id == b.id }?.percentText, "100%", "clamped percent")

        engine.setStatusHint(b.id, hint: "Merging video & audio…")
        equal(engine.downloads.first { $0.id == b.id }?.statusHint, "Merging video & audio…", "status hint set")
        equal(engine.downloads.first { $0.id == b.id }?.progress, 1.0, "status hint reports 100% progress")
        equal(engine.downloads.first { $0.id == b.id }?.percentText, "100%", "status hint reports 100% text")

        var fired = 0
        engine.onComplete = { _ in fired += 1 }
        engine.liveFailed(b.id, message: "gone")
        equal(fired, 0, "failure never fires completion")
        equal(engine.downloads.first { $0.id == b.id }?.statusHint, nil, "status hint cleared on failure")
        engine.setStatusHint(b.id, hint: "Finalizing…")
        engine.liveCompleted(b.id, filePath: "/tmp/First.zip", bytes: 1_000)
        equal(fired, 1, "completion fires once with a real path")
        equal(engine.downloads.first { $0.id == b.id }?.state, .completed, "completed state")
        equal(engine.downloads.first { $0.id == b.id }?.statusHint, nil, "status hint cleared on completion")
        equal(engine.downloads.first { $0.id == b.id }?.currentSpeed, 0.0, "speed stops at completion")
    }

    static func chatGPTAndImages() {
        let oai = LinkInspector.inspect("https://files.oaiusercontent.com/file-BkW3nN8u3f94mNksj3?se=2026-10-27&sig=test")
        check(oai != nil, "ChatGPT image url parses")
        equal(oai?.kind, .file, "ChatGPT image is a file")
        check(oai?.suggestedFileName.hasSuffix(".png") == true, "ChatGPT image gets .png extension, not .zip")

        let data = LinkInspector.inspect("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
        check(data != nil, "data URI parses")
        equal(data?.kind, .file, "data URI is a file")
        check(data?.suggestedFileName.hasSuffix(".png") == true, "data URI gets .png extension")

        let naked = LinkInspector.inspect("files.oaiusercontent.com/file-xyz")
        check(naked != nil, "naked domain parses")
        equal(naked?.kind, .file, "naked domain is a file")
    }
}

MainActor.assumeIsolated {
    Checks.main()
}
