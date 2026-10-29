import AppKit
import AVFoundation
import Combine
import Foundation
import PounceCore

struct MusicTrack: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var url: URL?
    var seed: Int
    var isDemo: Bool
}

public struct MusicSearchResult: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: String?
    public let duration: TimeInterval
    public let previewURL: String?

    public init(id: String, title: String, artist: String, album: String, artworkURL: String?, duration: TimeInterval, previewURL: String?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.previewURL = previewURL
    }
}

@MainActor
final class MusicPlayer: NSObject, ObservableObject {
    @Published private(set) var tracks: [MusicTrack] = []
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published var searchText = "" {
        didSet {
            searchMusic(query: searchText)
        }
    }
    @Published public private(set) var searchResults: [MusicSearchResult] = []
    @Published public private(set) var isSearching: Bool = false
    private var searchTask: Task<Void, Never>?
    @Published var volume: Double = 0.75 {
        didSet {
            player?.volume = Float(volume)
            streamPlayer?.volume = Float(volume)
        }
    }
    @Published private(set) var lastError: String?

    private var player: AVAudioPlayer?
    private var streamPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var streamItemEndObserver: NSObjectProtocol?
    private var streamItemStatusObserver: NSKeyValueObservation?
    private var timer: Timer?
    private var startedDemo = false
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        loadDemoTracks()

        SystemMediaService.shared.$currentTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        SystemMediaService.shared.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var hasSystemMedia: Bool {
        if isPlaying {
            return false
        }
        guard let sys = SystemMediaService.shared.currentTrack else { return false }
        return SystemMediaService.shared.isPlaying || sys.appName == "Spotify" || sys.appName == "Music"
    }

    var systemTrack: SystemMediaTrack? {
        SystemMediaService.shared.currentTrack
    }

    var isSystemPlaying: Bool {
        SystemMediaService.shared.isPlaying
    }

    var activeTitle: String {
        if isPlaying, let current = currentTrack {
            return current.title
        }
        if let sys = systemTrack, (isSystemPlaying || sys.appName == "Spotify" || sys.appName == "Music") {
            return sys.title
        }
        return currentTrack?.title ?? "Nothing playing"
    }

    var activeArtist: String {
        if isPlaying, let current = currentTrack {
            return current.artist
        }
        if let sys = systemTrack, (isSystemPlaying || sys.appName == "Spotify" || sys.appName == "Music") {
            return sys.artist.isEmpty ? sys.appName : sys.artist
        }
        return currentTrack?.artist ?? "Choose a track below"
    }

    var isAnyPlaying: Bool {
        isSystemPlaying || isPlaying
    }

    var filteredTracks: [MusicTrack] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return tracks }
        let query = searchText.lowercased()
        return tracks.filter {
            $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query) || $0.album.lowercased().contains(query)
        }
    }

    var importedPaths: [String] {
        tracks.filter { !$0.isDemo }.compactMap { $0.url?.path }
    }

    var progress: Double {
        guard let currentTrack, currentTrack.duration > 0 else { return 0 }
        return min(1, max(0, currentTime / currentTrack.duration))
    }

    func loadImported(paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        for url in urls.reversed() {
            _ = insertTrack(url: url, atFront: true, announce: false)
        }
    }

    @discardableResult
    func addFiles(_ urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            if insertTrack(url: url, atFront: false, announce: false) {
                added += 1
            }
        }
        if added > 0, currentTrack == nil, let first = tracks.first {
            prepare(first, autoplay: false)
        }
        return added
    }

    @discardableResult
    private func insertTrack(url: URL, atFront: Bool, announce: Bool) -> Bool {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { return false }
        if tracks.contains(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) { return false }
        guard let audio = try? AVAudioPlayer(contentsOf: url) else {
            lastError = "Could not read \(url.lastPathComponent)"
            return false
        }
        let name = (url.lastPathComponent as NSString).deletingPathExtension
        let track = MusicTrack(
            title: name.replacingOccurrences(of: "_", with: " "),
            artist: "Your Library",
            album: url.deletingLastPathComponent().lastPathComponent,
            duration: audio.duration,
            url: url,
            seed: tracks.count + 20,
            isDemo: false
        )
        if atFront { tracks.insert(track, at: 0) } else { tracks.append(track) }
        return true
    }

    func play(_ track: MusicTrack) {
        if isSystemPlaying {
            SystemMediaService.shared.togglePlayPause()
        }
        if currentTrack?.id == track.id, isPlaying {
            pause()
            return
        }
        prepare(track, autoplay: true)
    }

    func toggle() {
        if isPlaying {
            pause()
            return
        }
        if let player {
            player.play()
            isPlaying = true
            startTimer()
            return
        }
        if let streamPlayer {
            streamPlayer.play()
            isPlaying = true
            return
        }
        if isSystemPlaying {
            SystemMediaService.shared.togglePlayPause()
            return
        }
        if let sys = systemTrack, (sys.appName == "Spotify" || sys.appName == "Music") {
            SystemMediaService.shared.togglePlayPause()
            return
        }
        if let currentTrack {
            prepare(currentTrack, autoplay: true)
        } else if let first = tracks.first {
            prepare(first, autoplay: true)
        }
    }

    func pause() {
        if isSystemPlaying {
            SystemMediaService.shared.togglePlayPause()
        }
        player?.pause()
        streamPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func next() {
        if isPlaying {
            guard let currentTrack, let index = tracks.firstIndex(where: { $0.id == currentTrack.id }), !tracks.isEmpty else { return }
            prepare(tracks[(index + 1) % tracks.count], autoplay: isPlaying)
            return
        }
        if hasSystemMedia {
            SystemMediaService.shared.nextTrack()
            return
        }
        guard let currentTrack, let index = tracks.firstIndex(where: { $0.id == currentTrack.id }), !tracks.isEmpty else { return }
        prepare(tracks[(index + 1) % tracks.count], autoplay: isPlaying)
    }

    func previous() {
        if isPlaying {
            if currentTime > 4 {
                seek(to: 0)
                return
            }
            guard let currentTrack, let index = tracks.firstIndex(where: { $0.id == currentTrack.id }), !tracks.isEmpty else { return }
            prepare(tracks[(index - 1 + tracks.count) % tracks.count], autoplay: isPlaying)
            return
        }
        if hasSystemMedia {
            SystemMediaService.shared.previousTrack()
            return
        }
        guard let currentTrack, let index = tracks.firstIndex(where: { $0.id == currentTrack.id }), !tracks.isEmpty else { return }
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        prepare(tracks[(index - 1 + tracks.count) % tracks.count], autoplay: isPlaying)
    }

    func seek(to time: TimeInterval) {
        currentTime = time
        if let player {
            player.currentTime = min(player.duration, max(0, time))
            currentTime = player.currentTime
        } else if let streamPlayer {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            streamPlayer.seek(to: cmTime)
        }
    }

    func seek(fraction: Double) {
        guard let currentTrack else { return }
        seek(to: currentTrack.duration * min(1, max(0, fraction)))
    }

    private func prepare(_ track: MusicTrack, autoplay: Bool) {
        stopTimer()
        player?.stop()
        player = nil

        if let token = timeObserverToken {
            streamPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let obs = streamItemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            streamItemEndObserver = nil
        }
        streamPlayer?.pause()
        streamPlayer = nil

        guard let url = track.url else {
            currentTrack = track
            isPlaying = false
            lastError = "This track is not available"
            return
        }

        currentTrack = track
        currentTime = 0
        lastError = nil

        if url.isFileURL {
            do {
                let audio = try AVAudioPlayer(contentsOf: url)
                audio.volume = Float(volume)
                audio.numberOfLoops = 0
                audio.delegate = self
                audio.prepareToPlay()
                player = audio
                if autoplay {
                    audio.play()
                    isPlaying = true
                    startTimer()
                } else {
                    isPlaying = false
                }
            } catch {
                isPlaying = false
                lastError = "Could not play \(track.title)"
            }
        } else {
            // Streaming HTTP / HTTPS (Apple Music preview or lossless studio stream)
            streamItemStatusObserver?.invalidate()
            streamItemStatusObserver = nil

            let item = AVPlayerItem(url: url)
            let sPlayer = AVPlayer(playerItem: item)
            sPlayer.volume = Float(volume)
            sPlayer.automaticallyWaitsToMinimizeStalling = true
            self.streamPlayer = sPlayer

            streamItemEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleTrackFinished(true)
                }
            }

            streamItemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] pItem, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if pItem.status == .failed {
                        self.isPlaying = false
                        self.lastError = pItem.error?.localizedDescription ?? "Playback error"
                    } else if pItem.status == .readyToPlay && self.isPlaying {
                        self.streamPlayer?.play()
                    }
                }
            }

            timeObserverToken = sPlayer.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                Task { @MainActor [weak self] in
                    guard let self, self.isPlaying else { return }
                    let secs = time.seconds
                    if secs.isFinite && !secs.isNaN {
                        self.currentTime = secs
                    }
                }
            }

            if autoplay {
                isPlaying = true
                sPlayer.play()
            } else {
                isPlaying = false
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 0.2, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        if !player.isPlaying && isPlaying {
            isPlaying = false
            stopTimer()
        }
    }

    private func loadDemoTracks() {
        // Sample audio removed per user request.
    }

    /// Searches for a song, artist or album in Spotify and starts playback.
    func searchAndPlaySpotify(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed

        if isPlaying {
            pause()
        }

        let script = """
        tell application "Spotify"
            activate
            open location "spotify:search:\(encoded)"
            delay 0.5
            play
        end tell
        """
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&errorInfo)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SystemMediaService.shared.refresh()
        }
    }

    /// Searches Apple/iTunes Music database in real time for Spotify search list.
    func searchMusic(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask?.cancel()
        isSearching = true

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                await MainActor.run { self?.isSearching = false }
                return
            }

            var parsed: [MusicSearchResult] = []

            // 1. Query Apple Music / iTunes globally
            if let itunesURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=25") {
                if let (data, _) = try? await URLSession.shared.data(from: itunesURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    for item in results {
                        let trackId = "\(item["trackId"] ?? UUID().uuidString)"
                        let trackName = item["trackName"] as? String ?? ""
                        let artistName = item["artistName"] as? String ?? ""
                        let albumName = item["collectionName"] as? String ?? ""
                        let artwork = (item["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100bb", with: "300x300bb")
                        let millis = item["trackTimeMillis"] as? Double ?? 0
                        let preview = item["previewUrl"] as? String
                        if !trackName.isEmpty {
                            parsed.append(MusicSearchResult(
                                id: trackId,
                                title: trackName,
                                artist: artistName,
                                album: albumName,
                                artworkURL: artwork,
                                duration: millis / 1000.0,
                                previewURL: preview
                            ))
                        }
                    }
                }
            }

            // 2. Query Studio Master API (JioSaavn) for Tamil & Indian songs
            if parsed.count < 8, let saavnURL = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&q=\(encoded)&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=10") {
                var req = URLRequest(url: saavnURL)
                req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                if let (sData, _) = try? await URLSession.shared.data(for: req),
                   let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
                   let sResults = sJson["results"] as? [[String: Any]] {
                    for sSong in sResults {
                        let title = (sSong["title"] as? String) ?? ""
                        if title.isEmpty || parsed.contains(where: { $0.title.lowercased() == title.lowercased() }) { continue }

                        let sId = (sSong["id"] as? String) ?? UUID().uuidString
                        let more = sSong["more_info"] as? [String: Any]
                        let artist = (more?["primary_artists"] as? String) ?? (more?["singers"] as? String) ?? (sSong["subtitle"] as? String) ?? ""
                        let album = (more?["album"] as? String) ?? ""
                        let durStr = (more?["duration"] as? String) ?? "220"
                        let duration = Double(durStr) ?? 220.0
                        let art = (sSong["image"] as? String)?.replacingOccurrences(of: "150x150.jpg", with: "500x500.jpg")

                        var previewURL: String? = nil
                        if let enc = more?["encrypted_media_url"] as? String,
                           let dec = LosslessAudioService.shared.decryptSaavnMediaURL(encURL: enc) {
                            previewURL = dec.replacingOccurrences(of: "_96.mp4", with: "_320.mp4").replacingOccurrences(of: "_160.mp4", with: "_320.mp4")
                        }

                        parsed.append(MusicSearchResult(
                            id: "saavn_\(sId)",
                            title: title.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#039;", with: "'").replacingOccurrences(of: "&amp;", with: "&"),
                            artist: artist.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#039;", with: "'").replacingOccurrences(of: "&amp;", with: "&"),
                            album: album.replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#039;", with: "'").replacingOccurrences(of: "&amp;", with: "&"),
                            artworkURL: art,
                            duration: duration,
                            previewURL: previewURL
                        ))
                    }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.searchResults = parsed
                self?.isSearching = false
            }
        }
    }

    /// Plays the chosen search result directly inside the Notch player.
    func playSearchResult(_ result: MusicSearchResult) {
        if isSystemPlaying {
            SystemMediaService.shared.togglePlayPause()
        }

        let streamURL = result.previewURL.flatMap(URL.init(string:))
        let track = MusicTrack(
            title: result.title,
            artist: result.artist,
            album: result.album,
            duration: result.duration > 0 ? result.duration : 210,
            url: streamURL,
            seed: Int(LinkInspector.stableHash(result.title) % 10_000),
            isDemo: false
        )

        if !tracks.contains(where: { $0.title == track.title && $0.artist == track.artist }) {
            tracks.insert(track, at: 0)
        }

        if let streamURL {
            prepare(track, autoplay: true)
        } else {
            // Asynchronously resolve playable stream URL via JioSaavn or yt-dlp -g
            isSearching = true
            Task { [weak self] in
                guard let self else { return }
                var resolvedURL: URL? = nil
                let songQuery = "\(result.artist) \(result.title)"
                if let hq = await LosslessAudioService.shared.searchHighQualityAudio(query: songQuery) {
                    resolvedURL = hq.url
                } else if let tool = TransferService.tool("yt-dlp") {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: tool)
                    proc.standardInput = FileHandle.nullDevice
                    proc.arguments = ["-g", "-f", "bestaudio/best", "ytsearch1:\(songQuery) audio"]
                    let pipe = Pipe()
                    proc.standardOutput = pipe
                    proc.standardError = Pipe()
                    if (try? proc.run()) != nil {
                        proc.waitUntilExit()
                        if proc.terminationStatus == 0 {
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            if let outStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               let firstLine = outStr.components(separatedBy: .newlines).first,
                               let u = URL(string: firstLine) {
                                resolvedURL = u
                            }
                        }
                    }
                }
                await MainActor.run {
                    self.isSearching = false
                    if let resolvedURL {
                        var playableTrack = track
                        playableTrack.url = resolvedURL
                        self.prepare(playableTrack, autoplay: true)
                    } else {
                        self.lastError = "Could not find stream for \(result.title)"
                    }
                }
            }
        }
    }
}

extension MusicPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handleTrackFinished(flag)
        }
    }

    private func handleTrackFinished(_ flag: Bool) {
        guard flag else { isPlaying = false; return }
        let wasPlaying = isPlaying
        if let currentTrack, let index = tracks.firstIndex(where: { $0.id == currentTrack.id }), tracks.count > 1 {
            prepare(tracks[(index + 1) % tracks.count], autoplay: wasPlaying)
        } else {
            seek(to: 0)
            pause()
        }
    }
}
