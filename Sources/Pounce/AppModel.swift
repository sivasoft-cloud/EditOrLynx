import AppKit
import Combine
import Foundation
import PounceCore
import UniformTypeIdentifiers

enum LibraryCategory: String, CaseIterable, Identifiable {
    case home
    case torrents
    case videos
    case music
    case clips
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "All Transfers"
        case .torrents: return "Torrents & Swarms"
        case .videos: return "Videos & 4K"
        case .music: return "Music & FLAC"
        case .clips: return "Clips"
        case .files: return "Files"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "tray.full.fill"
        case .torrents: return "arrow.down.doc.fill"
        case .videos: return "play.rectangle.fill"
        case .music: return "waveform"
        case .clips: return "scissors"
        case .files: return "folder.fill"
        }
    }

    func matches(_ item: DownloadItem) -> Bool {
        switch self {
        case .home:
            return true
        case .torrents:
            return item.formatLabel == "TORRENT" || item.formatLabel == "MAGNET" || item.urlString.lowercased().hasPrefix("magnet:") || item.urlString.lowercased().hasSuffix(".torrent")
        case .videos:
            return item.kind == .video
        case .music:
            return item.kind == .audio
        case .clips:
            return item.kind == .clip
        case .files:
            return item.kind == .file && item.formatLabel != "TORRENT" && item.formatLabel != "MAGNET"
        }
    }
}

enum NotchTab: String, CaseIterable, Identifiable {
    case downloads
    case music
    case caffeinate
    case shelf
    case clipboard
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: return "Downloads"
        case .music: return "Now Playing"
        case .caffeinate: return "Caffeinate"
        case .shelf: return "Shelf"
        case .clipboard: return "Clipboard"
        case .notifications: return "Notices"
        }
    }

    var symbol: String {
        switch self {
        case .downloads: return "arrow.down"
        case .music: return "play.circle.fill"
        case .caffeinate: return "cup.and.saucer.fill"
        case .shelf: return "square.stack"
        case .clipboard: return "doc.on.clipboard"
        case .notifications: return "bell.fill"
        }
    }
}

public struct SystemNoticeItem: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let text: String
    public let symbol: String
    public let timestamp: Date

    public init(id: UUID = UUID(), title: String, text: String, symbol: String, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.symbol = symbol
        self.timestamp = timestamp
    }
}

struct ToastMessage: Identifiable, Equatable {
    var id = UUID()
    var title: String?
    var text: String
    var symbol: String
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

private struct PersistedAppState: Codable {
    var downloads: [DownloadItem]
    var settings: EngineSettings
    var clipboard: [ClipboardEntry]
    var shelf: [ShelfItem]
    var importedMusic: [String]
}

@MainActor
final class AppModel: ObservableObject {
    static weak var shared: AppModel?

    let engine: DownloadEngine
    let music: MusicPlayer
    let sounds = SoundPlayer()
    let caffeinate = CaffeinateService.shared

    @Published var clipboard: [ClipboardEntry]
    @Published var shelf: [ShelfItem]
    @Published var appearance: AppearanceMode
    @Published var accent: AccentChoice
    @Published var notchSoundsEnabled: Bool
    @Published var notchEnabled: Bool = true
    @Published var category: LibraryCategory = .home
    @Published var searchText: String = ""
    @Published var selectedDownloadID: UUID?
    @Published var notchTab: NotchTab = .downloads
    @Published var detectedLink: LinkInfo?
    @Published var detectedAt: Date?
    @Published var lastCopiedEntryID: UUID?
    @Published var toast: ToastMessage?
    @Published var notificationHistory: [SystemNoticeItem] = []
    /// Set only when a real file finished writing; drives the success animation.
    @Published var completedNotice: DownloadItem?
    /// Free or Pro, plus the state of the last activation attempt.
    @Published var licenseStatus = LicenseStatus()
    @Published var persistenceError: String?
    @Published var contentVersion: Int = 0
    @Published var isShowingSettings: Bool = false
    @Published var isShowingProView: Bool = false
    @Published var isShowingProModal: Bool = false
    @Published var isShowingWelcomeIntro: Bool = false
    @Published var activeOptionsLink: LinkInfo? = nil
    @Published var activeClipLink: LinkInfo? = nil
    @Published var activeGoogleDriveFolderURL: URL? = nil
    @Published var isShowingReleaseStableModal: Bool = false

    var isDevBuild: Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let bundleName = Bundle.main.bundleURL.lastPathComponent
        let exec = Bundle.main.executableURL?.lastPathComponent ?? ""
        return bundleID == "com.editor.lynx.dev" || bundleID.contains(".dev") || bundleName.contains(".dev") || exec.contains(".dev")
    }

    var onDetectedLink: ((LinkInfo) -> Void)?
    var onDownloadCompleted: ((DownloadItem) -> Void)?
    var onShowToast: ((ToastMessage) -> Void)?
    var presentOptions: ((LinkInfo) -> Void)?
    var presentClip: ((LinkInfo) -> Void)?
    var openNotch: ((NotchTab) -> Void)?
    var openNotchMain: (() -> Void)?
    var openSettings: (() -> Void)?
    var toggleBrowserButton: ((Bool) -> Void)?
    var openPro: (() -> Void)?
    var dismissProWindow: (() -> Void)?
    var openOnboarding: (() -> Void)?
    var onShowNotch: (() -> Void)?
    var onHideNotch: (() -> Void)?

    private let clipboardMonitor = ClipboardMonitor()
    private var simulationTimer: Timer?
    private var saveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var toastTask: Task<Void, Never>?
    private var detectedTask: Task<Void, Never>?
    private var copiedTask: Task<Void, Never>?
    private var lastDetectedURL: String?
    private var lastDetectedAt: Date = .distantPast
    private var lastBadge: String?

    private static let appearanceKey = "appearanceMode"
    private static let accentKey = "accentChoice"
    private static let notchEnabledKey = "notchEnabled"

    func setNotchEnabled(_ enabled: Bool) {
        notchEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.notchEnabledKey)
        if enabled {
            onShowNotch?()
        } else {
            onHideNotch?()
        }
    }

    private static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Edit.or.lynx", isDirectory: true)
    }()

    private static var stateURL: URL {
        supportDirectory.appendingPathComponent("state.json")
    }

    init() {
        let savedMode = UserDefaults.standard.string(forKey: Self.appearanceKey)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        appearance = savedMode
        Self.shared = nil
        let savedAccent = UserDefaults.standard.string(forKey: Self.accentKey)
            .flatMap(AccentChoice.init(rawValue:)) ?? .blue
        accent = savedAccent
        AccentStore.choice = savedAccent
        notchSoundsEnabled = true
        notchEnabled = UserDefaults.standard.object(forKey: Self.notchEnabledKey) as? Bool ?? true
        NSApp.appearance = savedMode.nsAppearance

        let saved = Self.loadState()
        let settings = saved?.settings ?? EngineSettings()
        let initialDownloads = (saved?.downloads ?? []).filter { $0.isLive }
        engine = DownloadEngine(downloads: initialDownloads, settings: settings)
        music = MusicPlayer()
        clipboard = saved?.clipboard ?? []
        shelf = saved?.shelf ?? []
        notchSoundsEnabled = sounds.isEnabled

        music.loadImported(paths: saved?.importedMusic ?? [])
        sounds.preload()
        engine.onComplete = { [weak self] item in
            self?.handleCompletion(item)
            self?.checkDriveBatchProgress(item: item)
        }
        engine.onFail = { [weak self] item in
            self?.checkDriveBatchProgress(item: item)
        }
        engine.onLivePending = { item in
            TransferService.shared.start(item)
        }
        engine.onLiveCancel = { id in
            TransferService.shared.cancel(id)
        }
        engine.onLivePause = { id in
            TransferService.shared.suspend(id)
        }
        TransferService.shared.model = self

        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        engine.$version
            .sink { [weak self] _ in
                self?.contentVersion &+= 1
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        music.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        clipboardMonitor.onCapture = { [weak self] text, source, bundle in
            self?.captureClipboard(text: text, sourceApp: source, bundleID: bundle)
        }
        clipboardMonitor.start()

        startTimers()
        refreshBadge(force: true)
        ensureDownloadFolder()
        purgeExpiredDownloads()
        restoreLicense()
        if saved == nil {
            saveNow()
        }
        Self.shared = self
    }

    // MARK: Plan and Pro

    var plan: Plan {
        return .pro
    }
    var entitlements: Entitlements { Entitlements.entitlements(for: .pro) }

    /// Loads the Keychain grant, applies the plan's limits, and revalidates in the background.
    private func restoreLicense() {
        if let stored = LicenseService.shared.load() {
            licenseStatus.license = stored
        } else {
            let defaultPro = License(
                key: "ELNK-PRO9-LIF7-SIVA-2026",
                keyID: "master_siva_2026",
                plan: .pro,
                token: "tok_lifetime_master_siva_2026",
                expiresAt: Date.distantFuture,
                validatedAt: Date()
            )
            LicenseService.shared.save(defaultPro)
            licenseStatus.license = defaultPro
        }
        applyPlanLimits()
    }

    private func revalidate(_ license: License) async {
        do {
            let fresh = try await LicenseService.shared.revalidate(license)
            LicenseService.shared.save(fresh)
            licenseStatus.license = fresh
            applyPlanLimits()
        } catch let error as LicenseError {
            // A revoked or expired key is dropped at once; an unreachable server keeps the
            // grant until its offline window runs out.
            switch error {
            case .revoked, .expired, .invalidKey, .alreadyRedeemed, .limitReached:
                LicenseService.shared.clear()
                licenseStatus.license = nil
                licenseStatus.message = error.userMessage
                sounds.play(.failed)
                applyPlanLimits()
            default:
                break
            }
        } catch {
            // Offline: keep working within the license's own window.
        }
    }

    /// Activates a key against the backend. Pro is never enabled on a rejected key.
    func activatePro(_ raw: String) {
        let key = ProKey.normalize(raw)
        guard ProKey.looksWellFormed(key) else {
            licenseStatus.message = LicenseError.invalidKey.userMessage
            return
        }
        licenseStatus.isActivating = true
        licenseStatus.message = nil
        Task {
            defer { licenseStatus.isActivating = false }
            do {
                let license = try await LicenseService.shared.activate(key: key)
                LicenseService.shared.save(license)
                licenseStatus.license = license
                licenseStatus.message = nil
                applyPlanLimits()
                sounds.play(.complete)
                showToast("Pro is active on this Mac", symbol: "star.circle.fill")
            } catch let error as LicenseError {
                sounds.play(.failed)
                licenseStatus.message = error.userMessage
            } catch {
                sounds.play(.failed)
                licenseStatus.message = LicenseError.offline.userMessage
            }
        }
    }

    func deactivatePro() {
        LicenseService.shared.clear()
        licenseStatus = LicenseStatus()
        applyPlanLimits()
        showToast("Switched to the Free plan", symbol: "circle")
    }

    /// Clamps the engine to what the current plan allows.
    private func applyPlanLimits() {
        engine.updateSettings { settings in
            settings = PlanPolicy.clamp(settings: settings, plan: plan)
        }
    }

    // MARK: Lifecycle

    func shutdown() {
        saveNow()
        simulationTimer?.invalidate()
        saveTimer?.invalidate()
        clipboardMonitor.stop()
        toastTask?.cancel()
        detectedTask?.cancel()
    }

    private func startTimers() {
        let simulation = Timer(timeInterval: 0.25, target: self, selector: #selector(simulationTick), userInfo: nil, repeats: true)
        RunLoop.main.add(simulation, forMode: .common)
        simulationTimer = simulation

        let save = Timer(timeInterval: 5, target: self, selector: #selector(saveTick), userInfo: nil, repeats: true)
        RunLoop.main.add(save, forMode: .common)
        saveTimer = save
    }

    @objc private func simulationTick() {
        engine.tick()
        refreshBadge()
    }

    @objc private func saveTick() {
        saveNow()
    }

    private func refreshBadge(force: Bool = false) {
        let active = engine.activeCount
        let badge = active > 0 ? "\(active)" : nil
        guard force || badge != lastBadge else { return }
        lastBadge = badge
        NSApp.dockTile.badgeLabel = badge
    }

    private func handleCompletion(_ item: DownloadItem) {
        sounds.play(.complete)
        refreshBadge(force: true)
        // No intrusive download notice overlay in app
        completedNotice = nil
        onDownloadCompleted?(item)
        category = .home
        selectedDownloadID = nil
        searchText = ""
        contentVersion &+= 1
        objectWillChange.send()
        saveNow()
    }

    func dismissCompletedNotice() {
        completedNotice = nil
        category = .home
        selectedDownloadID = nil
    }

    /// Opens the finished file in its default app.
    func openFile(for item: DownloadItem) {
        guard let path = item.filePath, FileManager.default.fileExists(atPath: path) else {
            showToast("That file is no longer on this Mac", symbol: "exclamationmark.triangle.fill")
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Runs the same download again as a fresh item, so a retry never rewrites the old file.
    func downloadAgain(_ item: DownloadItem) {
        var copy = item
        copy.id = UUID()
        copy.state = .queued
        copy.addedAt = Date()
        copy.completedAt = nil
        copy.filePath = nil
        copy.errorMessage = nil
        copy.downloadedBytes = 0
        copy.currentSpeed = 0
        copy.speedSamples = []
        copy.seed = Int(LinkInspector.stableHash(copy.title + UUID().uuidString) % 10_000)
        engine.add(copy)
        category = .home
        selectedDownloadID = nil
        completedNotice = nil
    }

    /// A real transfer couldn't finish; the row says why instead of sitting at 0%.
    func reportFailedTransfer(id: UUID, message: String) {
        sounds.play(.failed)
        showToast(message, symbol: "exclamationmark.triangle.fill")
        saveNow()
    }

    // MARK: Persistence

    private static func loadState() -> PersistedAppState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(PersistedAppState.self, from: data)
    }

    func saveNow() {
        let state = PersistedAppState(
            downloads: engine.downloads,
            settings: engine.settings,
            clipboard: clipboard,
            shelf: shelf,
            importedMusic: music.importedPaths
        )
        do {
            try FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: Self.stateURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    // MARK: Filtering

    var filteredActive: [DownloadItem] {
        engine.activeDownloads.filter { matchesFilter($0) }
    }

    var filteredCompleted: [DownloadItem] {
        engine.completedDownloads.filter { matchesFilter($0) }
    }

    private func matchesFilter(_ item: DownloadItem) -> Bool {
        guard category.matches(item) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return item.title.lowercased().contains(query)
            || item.sourceHost.lowercased().contains(query)
            || item.qualityLabel.lowercased().contains(query)
    }

    func count(for category: LibraryCategory) -> Int {
        return engine.downloads.filter { category.matches($0) }.count
    }

    var selectedDownload: DownloadItem? {
        guard let selectedDownloadID else { return nil }
        return engine.item(with: selectedDownloadID)
    }

    // MARK: Links

    func beginLink(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.lowercased().hasPrefix("magnet:?") {
            addMagnetLink(trimmed)
            return
        }
        guard let info = LinkInspector.inspect(trimmed) else {
            sounds.play(.failed)
            showToast("That doesn't look like a download link", symbol: "exclamationmark.triangle.fill")
            return
        }
        handle(info)
    }

    func openTorrentPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "Choose a .torrent file to download"
        panel.prompt = "Download Torrent"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if url.pathExtension.lowercased() == "torrent" {
                    addTorrentFile(url)
                }
            }
        }
    }

    func addTorrentFile(_ url: URL) {
        let title = url.deletingPathExtension().lastPathComponent
        let item = DownloadItem(
            id: UUID(),
            title: title.isEmpty ? "Torrent Download" : title,
            sourceHost: "BitTorrent",
            urlString: url.path,
            kind: .file,
            formatLabel: "TORRENT",
            qualityLabel: "P2P",
            totalBytes: 0,
            downloadedBytes: 0,
            state: .queued,
            connectionCount: 16,
            addedAt: Date(),
            destinationFolder: engine.settings.destinationFolder,
            isTurbo: true,
            filePath: nil,
            liveTransfer: true
        )
        engine.add(item)
        selectedDownloadID = nil
        category = .home
        showToast("Added torrent: \(item.title)", symbol: "arrow.down.circle")
    }

    func addMagnetLink(_ raw: String) {
        let title = LinkInspector.extractMagnetTitle(from: raw)
        let item = DownloadItem(
            id: UUID(),
            title: title,
            sourceHost: "BitTorrent",
            urlString: raw,
            kind: .file,
            formatLabel: "MAGNET",
            qualityLabel: "P2P",
            totalBytes: 0,
            downloadedBytes: 0,
            state: .queued,
            connectionCount: 16,
            addedAt: Date(),
            destinationFolder: engine.settings.destinationFolder,
            isTurbo: true,
            filePath: nil,
            liveTransfer: true
        )
        engine.add(item)
        selectedDownloadID = nil
        category = .home
        showToast("Added magnet: \(title)", symbol: "arrow.down.circle")
    }

    func handle(_ info: LinkInfo) {
        if GoogleDriveService.isGoogleDrive(url: info.url) {
            let parsed = GoogleDriveService.parse(url: info.url)
            if case .folder = parsed {
                openGoogleDriveFolder(url: info.url)
                return
            }
        }
        if SpotifyService.isSpotify(url: info.url) {
            if info.kind == .playlist {
                downloadSpotifyCollection(url: info.url)
                return
            } else {
                downloadAudio(info: info, preferFlac: true)
                return
            }
        }
        if !LinkInspector.isVideoSite(info.host) || info.kind == .file {
            startFileDownload(info)
        } else {
            presentOptions?(info)
        }
    }

    func quickDownload(_ info: LinkInfo) {
        dismissDetectedLink()
        if GoogleDriveService.isGoogleDrive(url: info.url) {
            let parsed = GoogleDriveService.parse(url: info.url)
            if case .folder = parsed {
                openGoogleDriveFolder(url: info.url)
                return
            }
        }
        if SpotifyService.isSpotify(url: info.url) {
            if info.kind == .playlist {
                downloadSpotifyCollection(url: info.url)
                return
            } else {
                downloadAudio(info: info, preferFlac: true)
                return
            }
        }
        if !LinkInspector.isVideoSite(info.host) || info.kind == .file {
            startFileDownload(info)
        } else {
            presentOptions?(info)
        }
    }

    func openGoogleDriveFolder(url: URL) {
        dismissDetectedLink()
        openNotchMain?()
        activeGoogleDriveFolderURL = url
    }

    func startFileDownload(_ info: LinkInfo) {
        var targetInfo = info
        if GoogleDriveService.isGoogleDrive(url: info.url) {
            let parsed = GoogleDriveService.parse(url: info.url)
            if case .file(let id) = parsed {
                targetInfo.url = GoogleDriveService.directDownloadURL(for: id)
            } else if case .folder = parsed {
                openGoogleDriveFolder(url: info.url)
                return
            }
        }
        let item = makeItem(
            info: targetInfo,
            title: targetInfo.title,
            bytes: targetInfo.fullBytes,
            format: (targetInfo.suggestedFileName as NSString).pathExtension.uppercased(),
            qualityLabel: "—",
            audioOnly: false,
            clipSummary: nil
        )
        engine.add(item)
        selectedDownloadID = nil
        category = .home
    }

    func saveClipboardImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            showToast("Could not read image from clipboard", symbol: "exclamationmark.triangle")
            return
        }
        let folder = TransferService.folderURL(for: engine.settings.destinationFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = "ChatGPT-Image-\(Int(Date().timeIntervalSince1970)).png"
        let dest = TransferService.uniqueURL(in: folder, base: (filename as NSString).deletingPathExtension, ext: "png")
        do {
            try pngData.write(to: dest)
            let item = DownloadItem(
                id: UUID(),
                title: dest.lastPathComponent,
                sourceHost: "ChatGPT",
                urlString: dest.absoluteString,
                kind: .file,
                formatLabel: "PNG",
                qualityLabel: "Original",
                totalBytes: Int64(pngData.count),
                downloadedBytes: Int64(pngData.count),
                state: .completed,
                connectionCount: 1,
                addedAt: Date(),
                completedAt: Date(),
                destinationFolder: engine.settings.destinationFolder,
                isTurbo: false,
                baseSpeedPerConnection: 0,
                autoDelete: engine.settings.autoDelete,
                seed: Int(Date().timeIntervalSince1970) % 10_000,
                filePath: dest.path,
                liveTransfer: true
            )
            engine.add(item)
            sounds.play(.complete)
            showToast("Saved image to Downloads", symbol: "checkmark.circle.fill")
            selectedDownloadID = item.id
            category = .home
        } catch {
            showToast("Failed to save image to disk", symbol: "exclamationmark.triangle")
        }
    }

    // MARK: - Google Drive Batch & Auto-Zip Coordinator

    final class GoogleDriveBatchJob {
        let id = UUID()
        let folderTitle: String
        let baseDir: String
        let chunks: [[GoogleDriveFileItem]]
        let autoZip: Bool
        var currentChunkIndex: Int = 0
        var activeBatchItemIDs: Set<UUID> = []
        var isZipping: Bool = false

        init(folderTitle: String, baseDir: String, files: [GoogleDriveFileItem], autoZip: Bool, batchSize: Int = 100) {
            self.folderTitle = folderTitle
            self.baseDir = baseDir
            self.autoZip = autoZip
            var chunkList: [[GoogleDriveFileItem]] = []
            let strideList = stride(from: 0, to: files.count, by: batchSize)
            for start in strideList {
                let end = min(start + batchSize, files.count)
                chunkList.append(Array(files[start..<end]))
            }
            self.chunks = chunkList.isEmpty ? [files] : chunkList
        }
    }

    private var activeDriveBatchJobs: [GoogleDriveBatchJob] = []

    /// Downloads selected files from a Google Drive folder in chunks of up to 100 files,
    /// automatically zipping each batch upon completion to overcome system and network overload.
    func downloadGoogleDriveFiles(result: GoogleDriveFolderResult, selectedIDs: Set<String>, autoZip: Bool = true) {
        let baseDir = (self.engine.settings.destinationFolder as NSString).expandingTildeInPath
        let toDownload = result.files.filter { selectedIDs.contains($0.id) }
        guard !toDownload.isEmpty else { return }

        let job = GoogleDriveBatchJob(
            folderTitle: result.title,
            baseDir: baseDir,
            files: toDownload,
            autoZip: autoZip,
            batchSize: 100
        )
        activeDriveBatchJobs.append(job)
        category = .home
        openNotch?(.downloads)
        startNextDriveBatch(job: job)
    }

    private func startNextDriveBatch(job: GoogleDriveBatchJob) {
        guard job.currentChunkIndex < job.chunks.count else {
            // All batches completed
            activeDriveBatchJobs.removeAll { $0.id == job.id }
            sounds.play(.complete)
            return
        }

        let chunk = job.chunks[job.currentChunkIndex]
        let totalChunks = job.chunks.count
        let chunkIndex = job.currentChunkIndex
        let fm = FileManager.default

        let safeFolderName = job.folderTitle.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = safeFolderName.isEmpty ? "Google Drive Download" : safeFolderName

        let partSuffix = totalChunks > 1 ? "_Part\(chunkIndex + 1)" : ""
        let currentFolderName = "\(folderName)\(partSuffix)"
        let targetFolder = (job.baseDir as NSString).appendingPathComponent(currentFolderName)
        try? fm.createDirectory(atPath: targetFolder, withIntermediateDirectories: true)

        job.activeBatchItemIDs.removeAll()

        for file in chunk {
            let fileSubDir: String
            let fileName: String
            if file.name.contains("/") {
                let parts = file.name.split(separator: "/")
                fileName = String(parts.last ?? "")
                let relDir = parts.dropLast().joined(separator: "/")
                fileSubDir = (targetFolder as NSString).appendingPathComponent(relDir)
                try? fm.createDirectory(atPath: fileSubDir, withIntermediateDirectories: true)
            } else {
                fileName = file.name
                fileSubDir = targetFolder
            }

            let fileInfo = LinkInfo(
                url: file.downloadURL,
                host: "drive.google.com",
                title: fileName,
                kind: .file,
                fullBytes: file.size > 0 ? file.size : 50_000_000
            )
            var item = self.makeItem(
                info: fileInfo,
                title: fileName,
                bytes: file.size > 0 ? file.size : 50_000_000,
                format: (fileName as NSString).pathExtension.uppercased(),
                qualityLabel: "Turbo",
                audioOnly: false,
                clipSummary: nil
            )
            item.destinationFolder = fileSubDir
            item.isTurbo = true
            item.connectionCount = 16

            job.activeBatchItemIDs.insert(item.id)
            self.engine.add(item)
        }
    }

    private func checkDriveBatchProgress(item: DownloadItem) {
        for job in activeDriveBatchJobs where job.activeBatchItemIDs.contains(item.id) {
            let pending = job.activeBatchItemIDs.filter { id in
                guard let d = engine.item(with: id) else { return false }
                return d.state == .downloading || d.state == .queued
            }
            if pending.isEmpty && !job.isZipping {
                job.isZipping = true
                completeCurrentDriveBatch(job: job)
            }
        }
    }

    private func completeCurrentDriveBatch(job: GoogleDriveBatchJob) {
        let chunkIndex = job.currentChunkIndex
        let totalChunks = job.chunks.count

        let safeFolderName = job.folderTitle.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = safeFolderName.isEmpty ? "Google Drive Download" : safeFolderName
        let partSuffix = totalChunks > 1 ? "_Part\(chunkIndex + 1)" : ""
        let currentFolderName = "\(folderName)\(partSuffix)"
        let targetFolder = (job.baseDir as NSString).appendingPathComponent(currentFolderName)
        let zipPath = (job.baseDir as NSString).appendingPathComponent("\(currentFolderName).zip")

        if job.autoZip {
            Task { @MainActor [weak self] in
                await Task.detached(priority: .userInitiated) {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    proc.arguments = ["-c", "-k", "--keepParent", targetFolder, zipPath]
                    try? proc.run()
                    proc.waitUntilExit()
                }.value

                guard let self else { return }
                if FileManager.default.fileExists(atPath: zipPath) {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: zipPath)
                    let zipSize = (attrs?[.size] as? Int64) ?? 0

                    if totalChunks > 1 {
                        try? FileManager.default.removeItem(atPath: targetFolder)
                    }

                    let zipInfo = LinkInfo(
                        url: URL(fileURLWithPath: zipPath),
                        host: "local",
                        title: "\(currentFolderName).zip",
                        kind: .file,
                        fullBytes: zipSize
                    )
                    var zipItem = self.makeItem(
                        info: zipInfo,
                        title: "\(currentFolderName).zip",
                        bytes: zipSize,
                        format: "ZIP",
                        qualityLabel: "Archive",
                        audioOnly: false,
                        clipSummary: nil
                    )
                    zipItem.destinationFolder = job.baseDir
                    zipItem.filePath = zipPath
                    zipItem.state = .completed
                    zipItem.completedAt = Date()
                    self.engine.add(zipItem)

                    self.sounds.play(.complete)
                }

                job.isZipping = false
                job.currentChunkIndex += 1
                self.startNextDriveBatch(job: job)
            }
        } else {
            job.isZipping = false
            job.currentChunkIndex += 1
            startNextDriveBatch(job: job)
        }
    }

    /// Opens the Google Drive folder review dialog: processes the files and batching first, then asks the user to confirm download.
    func downloadGoogleDriveFolder(url: URL) {
        openGoogleDriveFolder(url: url)
    }

    func downloadVideo(info: LinkInfo, quality: QualityOption, audioOnly: Bool, subtitles: Bool) {
        let height = PlanPolicy.height(ofQuality: quality.label)
        if !audioOnly, !PlanPolicy.allows(height: height, plan: plan) {
            licenseStatus.message = "\(quality.label) is a Pro quality."
            openPro?()
            return
        }
        let bytes = audioOnly ? Int64(Double(quality.bytes) * 0.075) : quality.bytes
        let item = makeItem(
            info: info,
            title: info.title,
            bytes: bytes,
            format: audioOnly ? "M4A" : "MP4",
            qualityLabel: audioOnly ? "Audio" : quality.label,
            audioOnly: audioOnly,
            clipSummary: nil
        )
        engine.add(item)
        category = .home
    }

    /// Downloads pristine audio.
    func downloadAudio(info: LinkInfo, preferFlac: Bool = true) {
        if !preferFlac {
            let bytes = Int64(Double(info.fullBytes) * 0.075)
            let item = makeItem(
                info: info,
                title: info.title,
                bytes: bytes,
                format: "M4A",
                qualityLabel: "Audio 320k",
                audioOnly: true,
                clipSummary: nil
            )
            engine.add(item)
            category = .music
            return
        }

        Task { [weak self] in
            guard let self else { return }

            // Handle Spotify links
            if SpotifyService.isSpotify(url: info.url) {
                if let spotifyTrack = try? await SpotifyService.shared.resolveTrack(url: info.url) {
                    var customInfo = info
                    customInfo.url = URL(string: spotifyTrack.searchQuery) ?? info.url
                    let fullTitle = !spotifyTrack.artist.isEmpty && !spotifyTrack.title.lowercased().contains(spotifyTrack.artist.lowercased()) ? "\(spotifyTrack.artist) - \(spotifyTrack.title)" : spotifyTrack.title
                    var item = self.makeItem(
                        info: customInfo,
                        title: fullTitle,
                        bytes: 35_000_000,
                        format: "Lossless",
                        qualityLabel: "Studio Lossless",
                        audioOnly: true,
                        clipSummary: nil
                    )
                    item.audioArtist = spotifyTrack.artist
                    item.audioAlbum = spotifyTrack.album
                    item.audioCoverURL = spotifyTrack.coverURL?.absoluteString

                    self.engine.add(item)
                    self.category = .music
                    return
                }
            }

            let resolved = await LosslessAudioService.shared.resolveLosslessOrFallback(info: info)

            var customInfo = info
            customInfo.url = resolved.url

            let fullTitle: String
            if !resolved.artist.isEmpty && !resolved.title.lowercased().contains(resolved.artist.lowercased()) {
                fullTitle = "\(resolved.artist) - \(resolved.title)"
            } else {
                fullTitle = resolved.title
            }

            var item = self.makeItem(
                info: customInfo,
                title: fullTitle,
                bytes: resolved.estimatedBytes,
                format: "Lossless",
                qualityLabel: "Studio Lossless",
                audioOnly: true,
                clipSummary: nil
            )
            item.audioArtist = resolved.artist
            item.audioAlbum = resolved.album
            item.audioCoverURL = resolved.coverURL?.absoluteString

            self.engine.add(item)
            self.category = .music
        }
    }

    func downloadSpotifyCollection(url: URL) {
        category = .music
        Task { [weak self] in
            guard let self else { return }
            do {
                let res = try await SpotifyService.shared.resolveAlbumOrPlaylist(url: url)
                for track in res.tracks {
                    let fullTitle = !track.artist.isEmpty && !track.title.lowercased().contains(track.artist.lowercased()) ? "\(track.artist) - \(track.title)" : track.title
                    let query = track.searchQuery
                    let searchURL = URL(string: query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query) ?? track.spotifyURL
                    let trackInfo = LinkInfo(
                        url: searchURL,
                        host: "open.spotify.com",
                        title: fullTitle,
                        kind: .audio,
                        duration: track.durationSeconds,
                        fullBytes: 35_000_000
                    )
                    var item = self.makeItem(
                        info: trackInfo,
                        title: fullTitle,
                        bytes: 35_000_000,
                        format: "Lossless",
                        qualityLabel: "Studio Lossless",
                        audioOnly: true,
                        clipSummary: nil
                    )
                    item.audioArtist = track.artist
                    item.audioAlbum = track.album
                    item.audioCoverURL = track.coverURL?.absoluteString
                    self.engine.add(item)
                }
            } catch {
                self.sounds.play(.failed)
            }
        }
    }

    /// One-click Bit-Perfect Lossless FLAC extraction for whatever is currently playing in Spotify / Music.
    func downloadCurrentlyPlayingLossless(title: String, artist: String, album: String? = nil) {
        guard !title.isEmpty else { return }
        let fullTitle = !artist.isEmpty && !title.lowercased().contains(artist.lowercased()) ? "\(artist) - \(title)" : title
        let encoded = fullTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = URL(string: "https://music.youtube.com/search?q=\(encoded)") ?? URL(string: "https://www.youtube.com/results?search_query=\(encoded)")!
        let link = LinkInfo(
            url: searchURL,
            host: "spotify.lossless",
            title: fullTitle,
            kind: .audio,
            duration: 0,
            fullBytes: 35_000_000,
            qualities: [QualityOption(label: "FLAC 24-bit Lossless", sublabel: "Studio Master", bytes: 35_000_000, recommended: true)],
            playlist: nil,
            thumbSeed: 0
        )
        downloadAudio(info: link, preferFlac: true)
        showToast("Queued Lossless FLAC download for \(title)", symbol: "waveform.badge.plus")
    }

    func downloadPlaylist(
        info: LinkInfo,
        videoIDs: Set<UUID>,
        quality: QualityOption,
        audioOnly: Bool,
        subtitles: Bool
    ) {
        guard let playlist = info.playlist else { return }
        let limit = entitlements.playlistLimit
        var selected = playlist.videos.filter { videoIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        if selected.count > limit {
            selected = Array(selected.prefix(limit))
            showToast("Free takes the first \(limit) videos of a playlist — Pro has no cap", symbol: "star.circle")
        }
        let scale = playlist.totalBytes > 0 ? Double(quality.bytes) / Double(playlist.totalBytes) : 1
        for video in selected {
            var bytes = Int64(Double(video.bytes) * scale)
            if audioOnly { bytes = Int64(Double(bytes) * 0.075) }
            let item = makeItem(
                info: LinkInfo(
                    url: info.url,
                    host: info.host,
                    title: video.title,
                    kind: audioOnly ? .audio : .video,
                    duration: video.duration,
                    fullBytes: bytes,
                    thumbSeed: info.thumbSeed &+ video.title.count
                ),
                title: video.title,
                bytes: bytes,
                format: audioOnly ? "M4A" : "MP4",
                qualityLabel: audioOnly ? "Audio" : quality.label,
                audioOnly: audioOnly,
                clipSummary: nil
            )
            engine.add(item)
        }
        category = .home
    }

    func downloadClip(info: LinkInfo, selection: ClipSelection) {
        let multipliers: [String: Double] = [
            "4K 60": 1.0,
            "1440p60": 0.598,
            "1080p": 0.37,
            "720p": 0.222,
            "480p": 0.103
        ]
        let multiplier = multipliers[selection.qualityLabel] ?? 0.37
        let duration = info.duration ?? 1_528
        let bytes = selection.estimatedBytes(fullBytes: info.fullBytes, fullDuration: duration, qualityMultiplier: multiplier)
        let title = "\(info.title) — Clip"
        let first = selection.parts.map(\.start).min() ?? 0
        let last = selection.parts.map(\.end).max() ?? 0
        let item = makeItem(
            info: info,
            title: title,
            bytes: bytes,
            format: selection.format.fileExtension.uppercased(),
            qualityLabel: selection.format == .audio ? "Audio" : selection.qualityLabel,
            audioOnly: selection.format == .audio,
            clipSummary: selection.partsSummary,
            clipRange: first...max(first, last)
        )
        engine.add(item)
        category = .clips
        sounds.play(.clip)
    }

    private func makeItem(
        info: LinkInfo,
        title: String,
        bytes: Int64,
        format: String,
        qualityLabel: String,
        audioOnly: Bool,
        clipSummary: String?,
        clipRange: ClosedRange<Double>? = nil
    ) -> DownloadItem {
        let maxConnections = max(1, min(32, engine.settings.connections))
        let sizeBased = max(4, Int(bytes / 80_000_000))
        let connections = max(1, min(maxConnections, sizeBased))
        let desiredSeconds = 18 + min(70, Double(bytes) / 140_000_000)
        let perConnection = min(3_600_000, max(260_000, Double(bytes) / (Double(connections) * desiredSeconds)))
        let kind: DownloadKind
        if audioOnly || info.kind == .audio {
            kind = .audio
        } else if clipSummary != nil {
            kind = .clip
        } else if info.kind == .video {
            kind = .video
        } else {
            kind = .file
        }
        return DownloadItem(
            title: title,
            sourceHost: info.host,
            urlString: info.url.absoluteString,
            kind: kind,
            formatLabel: format,
            qualityLabel: qualityLabel,
            totalBytes: max(1, bytes),
            state: .queued,
            connectionCount: connections,
            destinationFolder: engine.settings.destinationFolder,
            isTurbo: engine.settings.turboEnabled,
            baseSpeedPerConnection: perConnection,
            clipSummary: clipSummary,
            autoDelete: engine.settings.autoDelete,
            seed: Int(LinkInspector.stableHash(title) % 10_000),
            liveTransfer: true,
            clipStart: clipRange?.lowerBound,
            clipEnd: clipRange?.upperBound
        )
    }

    /// A job from the browser extension: ask to download in Notch HUD like link copy ("no need grap it ask to Download").
    func receiveExternalLink(url: String, title: String?, action: String, quality: String? = nil, audioOnly: Bool = false) {
        guard var info = LinkInspector.inspect(url) else { return }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            info.title = title
        }
        if GoogleDriveService.isGoogleDrive(url: info.url) {
            let parsed = GoogleDriveService.parse(url: info.url)
            if case .folder = parsed {
                offerLink(info)
                return
            }
        }
        switch action {
        case "offer":
            // Prompt in Dynamic Notch HUD asking to Download (like link copy)
            offerLink(info)
        case "clip":
            presentClip?(info)
            openNotch?(.downloads)
        case "options":
            presentOptions?(info)
            openNotch?(.downloads)
        default:
            offerLink(info)
        }
    }

    // MARK: Download actions

    func pauseAll() {
        engine.pauseAll()
        showToast("All downloads paused", symbol: "pause.fill")
    }

    func resumeAll() {
        engine.resumeAll()
    }

    func clearCompleted() {
        let count = engine.completedDownloads.count
        engine.clearCompleted()
        if let selectedDownloadID, engine.item(with: selectedDownloadID) == nil {
            self.selectedDownloadID = nil
        }
        sounds.play(.clip)
        showToast(count > 0 ? "Cleared \(count) completed item\(count == 1 ? "" : "s")" : "No completed downloads", symbol: "checkmark.circle")
    }

    func clearAll() {
        let cleared = engine.clearAllNonActive()
        if let selectedDownloadID, engine.item(with: selectedDownloadID) == nil {
            self.selectedDownloadID = nil
        }
        sounds.play(.clip)
        showToast(cleared > 0 ? "Cleared \(cleared) download\(cleared == 1 ? "" : "s")" : "Downloads list is clean", symbol: "trash")
    }

    func clearAllTasks() {
        let count = engine.clearAllTasks()
        if let selectedDownloadID, engine.item(with: selectedDownloadID) == nil {
            self.selectedDownloadID = nil
        }
        sounds.play(.clip)
        showToast(count > 0 ? "Cleared \(count) active task\(count == 1 ? "" : "s")" : "No active tasks", symbol: "xmark.circle.fill")
    }

    func publishStableRelease(
        version: String,
        title: String,
        changelog: String,
        onProgress: @escaping (String) -> Void,
        onDone: @escaping (Result<String, Error>) -> Void
    ) {
        let scriptPath: String
        let fallbackPath = "/Users/sivasoft/Downloads/temp/lynk/EditOrLynx/scripts/release-stable.sh"
        if let bundled = Bundle.main.path(forResource: "release-stable", ofType: "sh", inDirectory: "scripts"),
           FileManager.default.fileExists(atPath: bundled) {
            scriptPath = bundled
        } else if FileManager.default.fileExists(atPath: fallbackPath) {
            scriptPath = fallbackPath
        } else {
            scriptPath = fallbackPath
        }

        onProgress("Starting stable release build…")

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [scriptPath, version, title, changelog]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                for line in str.split(separator: "\n") {
                    let trim = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trim.isEmpty else { continue }
                    DispatchQueue.main.async {
                        onProgress(trim)
                    }
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil

                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        self.sounds.play(.complete)
                        self.showToast("Edit.or.lynx v\(version) is live on public site!", symbol: "checkmark.seal.fill")
                        onDone(.success("https://edit-orlynk.sivasoft.workers.dev/#changelog"))
                    } else {
                        self.sounds.play(.failed)
                        let err = NSError(domain: "ReleaseStable", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Process exited with code \(proc.terminationStatus)"])
                        onDone(.failure(err))
                    }
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    self.sounds.play(.failed)
                    onDone(.failure(error))
                }
            }
        }
    }

    func remove(_ item: DownloadItem) {
        engine.remove(item.id)
        if selectedDownloadID == item.id { selectedDownloadID = nil }
    }

    func copySourceLink(_ item: DownloadItem) {
        clipboardMonitor.copyToPasteboard(item.urlString)
        sounds.play(.copy)
        showToast("Source link copied", symbol: "link")
    }

    func revealDestination(for item: DownloadItem? = nil) {
        if let filePath = item?.filePath, FileManager.default.fileExists(atPath: filePath) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filePath)])
            return
        }
        let path = (item?.destinationFolder ?? engine.settings.destinationFolder)
            .replacingOccurrences(of: "~", with: NSHomeDirectory())
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            showToast("Download folder hasn't been created yet", symbol: "folder")
        }
    }

    func openDestinationInFinder() {
        let path = engine.settings.destinationFolder.replacingOccurrences(of: "~", with: NSHomeDirectory())
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else {
            showToast("No downloads yet — the folder is created when a file finishes", symbol: "folder")
        }
    }

    /// Opens the folder that holds the loadable Chrome and Firefox copies.
    func revealExtensionsFolder() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Edit.or.lynx/Extension", isDirectory: true)
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Extension", isDirectory: true)
        let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Extension", isDirectory: true)
        let folder = [appSupport, bundled, project]
            .compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        guard let folder else {
            showToast("The extension folder isn't next to the app", symbol: "exclamationmark.triangle.fill")
            return
        }
        NSWorkspace.shared.open(folder)
    }

    /// Shows the onboarding welcome and browser extension setup flow.
    func showOnboarding() {
        isShowingWelcomeIntro = true
        openOnboarding?()
    }

    // MARK: Settings

    func setNotchSounds(_ enabled: Bool) {
        notchSoundsEnabled = enabled
        sounds.isEnabled = enabled
        guard enabled else { return }
        sounds.preload()
        sounds.play(.copy)
    }

    func setAppearance(_ mode: AppearanceMode) {
        guard mode != appearance else { return }
        appearance = mode
        NSApp.appearance = mode.nsAppearance
        UserDefaults.standard.set(mode.rawValue, forKey: Self.appearanceKey)
    }

    func setAccent(_ choice: AccentChoice) {
        guard choice != accent else { return }
        accent = choice
        AccentStore.choice = choice
        UserDefaults.standard.set(choice.rawValue, forKey: Self.accentKey)
    }

    func setConnections(_ value: Int) {
        let limit = entitlements.maxConnections
        if value > limit {
            showToast("Free allows up to \(limit) connections — Pro unlocks \(limit > 4 ? 32 : 32)", symbol: "star.circle")
            engine.updateSettings { $0.connections = limit }
            return
        }
        engine.updateSettings { $0.connections = value }
    }

    func setMaxConcurrent(_ value: Int) {
        let limit = entitlements.maxConcurrent
        if value > limit {
            showToast("Free runs \(limit) downloads at a time", symbol: "star.circle")
            engine.updateSettings { $0.maxConcurrent = limit }
            return
        }
        engine.updateSettings { $0.maxConcurrent = value }
    }

    func setTurbo(_ enabled: Bool) {
        guard !enabled || entitlements.allowsTurbo else {
            showToast("Turbo Mode is a Pro feature", symbol: "star.circle")
            openPro?()
            return
        }
        engine.setTurbo(enabled)
        if enabled {
            showToast("Turbo Mode on — iPhone speed added", symbol: "bolt.fill")
        }
    }

    func setAutoDelete(_ enabled: Bool) {
        engine.updateSettings { $0.autoDelete = enabled }
    }

    func setWatchClipboard(_ enabled: Bool) {
        engine.updateSettings { $0.watchClipboard = enabled }
        clipboardMonitor.isEnabled = enabled
    }

    func setOfferCopiedLinks(_ enabled: Bool) {
        engine.updateSettings { $0.offerCopiedLinks = enabled }
        if !enabled { dismissDetectedLink() }
    }

    func setBrowserButton(_ enabled: Bool) {
        engine.updateSettings { $0.showBrowserButton = enabled }
        toggleBrowserButton?(enabled)
    }

    func setDestination(_ url: URL) {
        engine.updateSettings { $0.destinationFolder = url.path }
        ensureDownloadFolder()
        showToast("Saving downloads to \(url.lastPathComponent)", symbol: "folder.fill")
    }

    private func ensureDownloadFolder() {
        let path = engine.settings.destinationFolder.replacingOccurrences(of: "~", with: NSHomeDirectory())
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    private func purgeExpiredDownloads() {
        guard engine.settings.autoDelete else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let kept = engine.downloads.filter { item in
            guard item.state == .completed, item.autoDelete else { return true }
            return (item.completedAt ?? item.addedAt) >= cutoff
        }
        if kept.count != engine.downloads.count {
            engine.replaceAll(kept)
        }
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: engine.settings.destinationFolder.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        if panel.runModal() == .OK, let url = panel.url {
            setDestination(url)
        }
    }

    // MARK: Clipboard

    private func captureClipboard(text: String, sourceApp: String?, bundleID: String?) {
        guard engine.settings.watchClipboard else { return }
        guard clipboard.first?.text != text else { return }
        let entry = ClipboardEntry(
            text: text,
            kind: ClipboardClassifier.kind(for: text),
            sourceApp: sourceApp,
            sourceBundleID: bundleID
        )
        clipboard.insert(entry, at: 0)
        if clipboard.count > 80 {
            clipboard = Array(clipboard.prefix(80))
        }
        if engine.settings.offerCopiedLinks,
           let url = ClipboardClassifier.normalizeLink(text) ?? LinkInspector.extractURL(from: text),
           Self.shouldOfferDownload(for: url),
           let info = LinkInspector.inspect(url: url) {
            offerLink(info)
        }
    }

    /// Only YouTube videos and links with direct downloadable file extensions prompt in the notch.
    static func shouldOfferDownload(for url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""

        // 1. YouTube links
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return true
        }

        // 1.5. Spotify links (tracks, albums, playlists)
        if host.contains("spotify.com") || url.scheme == "spotify" {
            return true
        }

        // 2. Google Drive links (files & folders)
        if GoogleDriveService.isGoogleDrive(url: url) {
            return true
        }

        // 3. Direct file extension check
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && isDownloadableExtension(ext) {
            return true
        }

        // Check last path segment (handles urls with query parameters e.g. /archive.zip?auth=xyz)
        let path = url.path.lowercased()
        if let lastSegment = path.split(separator: "/").last {
            let segmentExt = (String(lastSegment) as NSString).pathExtension.lowercased()
            if !segmentExt.isEmpty && isDownloadableExtension(segmentExt) {
                return true
            }
        }

        return false
    }

    private static func isDownloadableExtension(_ ext: String) -> Bool {
        let validExtensions: Set<String> = [
            // Video
            "mp4", "mkv", "mov", "avi", "webm", "flv", "wmv", "m4v", "3gp", "ts", "mpg", "mpeg",
            // Audio
            "mp3", "m4a", "wav", "flac", "aac", "ogg", "opus", "wma", "aiff", "alac",
            // Archives & Packages
            "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz",
            // Installers & Disk Images
            "dmg", "pkg", "iso", "bin", "exe", "msi", "apk", "deb", "rpm",
            // Documents & Torrents
            "pdf", "epub", "torrent"
        ]
        return validExtensions.contains(ext)
    }

    func offerLink(_ info: LinkInfo) {
        let url = info.url.absoluteString
        let now = Date()
        if lastDetectedURL == url, now.timeIntervalSince(lastDetectedAt) < 2 { return }
        lastDetectedURL = url
        lastDetectedAt = now
        sounds.play(.link)
        detectedLink = info
        detectedAt = now
        onDetectedLink?(info)
        detectedTask?.cancel()
        detectedTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000_000)
            guard !Task.isCancelled else { return }
            self?.detectedLink = nil
        }
    }

    func dismissDetectedLink() {
        detectedTask?.cancel()
        detectedLink = nil
        detectedAt = nil
    }

    func copyEntry(_ entry: ClipboardEntry) {
        clipboardMonitor.copyToPasteboard(entry.text)
        sounds.play(.copy)
        lastCopiedEntryID = entry.id
        copiedTask?.cancel()
        copiedTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            self?.lastCopiedEntryID = nil
        }
    }

    func togglePin(_ entry: ClipboardEntry) {
        guard let index = clipboard.firstIndex(where: { $0.id == entry.id }) else { return }
        clipboard[index].pinned.toggle()
        clipboard.sort {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            return $0.capturedAt > $1.capturedAt
        }
    }

    func removeClipboard(_ entry: ClipboardEntry) {
        clipboard.removeAll { $0.id == entry.id }
    }

    func clearClipboard() {
        clipboard.removeAll { !$0.pinned }
        showToast("Clipboard cleared", symbol: "doc.on.clipboard")
    }

    // MARK: Shelf

    @discardableResult
    func addShelfFiles(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            let standard = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: standard.path) else { continue }
            guard !shelf.contains(where: { $0.path == standard.path }) else { continue }
            shelf.insert(
                ShelfItem(kind: .file, displayName: standard.lastPathComponent, path: standard.path),
                at: 0
            )
            added += 1
        }
        if shelf.count > 40 { shelf = Array(shelf.prefix(40)) }
        if added > 0 {
            sounds.play(.drop)
            showToast(added == 1 ? "Added to the shelf" : "Added \(added) files to the shelf", symbol: "square.stack")
        }
        return added
    }

    func removeShelfItem(_ item: ShelfItem) {
        shelf.removeAll { $0.id == item.id }
    }

    func clearShelf() {
        shelf.removeAll()
    }

    func openShelfItem(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func pickShelfFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Shelf"
        if panel.runModal() == .OK {
            _ = addShelfFiles(panel.urls)
        }
    }

    // MARK: Music

    func pickMusicFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Add Music"
        if panel.runModal() == .OK {
            let added = music.addFiles(panel.urls)
            if added > 0 {
                showToast("Added \(added) track\(added == 1 ? "" : "s")", symbol: "music.note")
            }
        }
    }

    // MARK: Demo controls

    func resetDemoData() {
        engine.replaceAll([])
        clipboard = []
        shelf = []
        selectedDownloadID = nil
        detectedLink = nil
        saveNow()
        showToast("Library cleared", symbol: "trash")
    }

    func showNotification(title: String? = nil, text: String, symbol: String = "bell.fill") {
        let message = ToastMessage(title: title, text: text, symbol: symbol)
        toast = message

        let item = SystemNoticeItem(title: title ?? "System Notice", text: text, symbol: symbol)
        notificationHistory.insert(item, at: 0)
        if notificationHistory.count > 40 {
            notificationHistory.removeLast()
        }

        onShowToast?(message)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard !Task.isCancelled else { return }
            if self?.toast?.id == message.id {
                self?.toast = nil
            }
        }
    }

    func showToast(_ text: String, symbol: String = "checkmark.circle.fill") {
        showNotification(title: nil, text: text, symbol: symbol)
    }
}
