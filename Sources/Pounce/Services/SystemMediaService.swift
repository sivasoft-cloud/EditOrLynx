import AppKit
import Foundation

public struct SystemMediaTrack: Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var isPlaying: Bool
    public var appName: String
    public var bundleIdentifier: String
    public var appIcon: NSImage?
    public var artwork: NSImage?

    public static func == (lhs: SystemMediaTrack, rhs: SystemMediaTrack) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.appName == rhs.appName
    }
}

@MainActor
public final class SystemMediaService: ObservableObject {
    public static let shared = SystemMediaService()

    @Published public private(set) var currentTrack: SystemMediaTrack?
    @Published public private(set) var isPlaying: Bool = false

    private typealias MRGetNowPlayingInfoType = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias MRGetIsPlayingType = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias MRGetPIDType = @convention(c) (DispatchQueue, @escaping (pid_t) -> Void) -> Void
    private typealias MRSendCommandType = @convention(c) (Int, CFDictionary?) -> Bool
    private typealias MRRegisterNotificationsType = @convention(c) (DispatchQueue) -> Void

    private var getNowPlayingInfo: MRGetNowPlayingInfoType?
    private var getIsPlaying: MRGetIsPlayingType?
    private var getPID: MRGetPIDType?
    private var sendCommand: MRSendCommandType?

    private var pollTimer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private var isRefreshing = false

    private init() {
        loadFramework()
        startMonitoring()
    }

    private func loadFramework() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else { return }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfo = unsafeBitCast(sym, to: MRGetNowPlayingInfoType.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            getIsPlaying = unsafeBitCast(sym, to: MRGetIsPlayingType.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            getPID = unsafeBitCast(sym, to: MRGetPIDType.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(sym, to: MRSendCommandType.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            let registerFn = unsafeBitCast(sym, to: MRRegisterNotificationsType.self)
            registerFn(DispatchQueue.main)
        }
    }

    public func startMonitoring() {
        // MediaRemote notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil
        )

        // Native Distributed Notifications for Spotify & Apple Music
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        refresh()
    }

    @objc private func handleNotification() {
        Task { @MainActor in
            refresh()
        }
    }

    public func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task.detached(priority: .utility) { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.isRefreshing = false
                }
            }

            // 1. Check Spotify in background
            if let spotifyTrack = Self.querySpotifyBackground() {
                await MainActor.run {
                    self?.currentTrack = spotifyTrack
                    self?.isPlaying = spotifyTrack.isPlaying
                }
                return
            }

            // 2. Check Apple Music in background
            if let musicTrack = Self.queryAppleMusicBackground() {
                await MainActor.run {
                    self?.currentTrack = musicTrack
                    self?.isPlaying = musicTrack.isPlaying
                }
                return
            }

            // 3. Fallback to MediaRemote
            await MainActor.run {
                self?.refreshMediaRemote()
            }
        }
    }

    private func refreshMediaRemote() {
        guard let getInfo = getNowPlayingInfo else {
            self.currentTrack = nil
            self.isPlaying = false
            return
        }

        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            guard let dict = info as? [String: Any], !dict.isEmpty else {
                self.currentTrack = nil
                self.isPlaying = false
                return
            }
            let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.currentTrack = nil
                self.isPlaying = false
                return
            }
            let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            let elapsed = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
            let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            let artwork = artworkData.flatMap { NSImage(data: $0) }

            self.getIsPlaying?(DispatchQueue.main) { [weak self] playing in
                guard let self else { return }
                self.isPlaying = playing

                self.getPID?(DispatchQueue.main) { [weak self] pid in
                    guard let self else { return }
                    var appName = "Media"
                    var bundleID = ""
                    var appIcon: NSImage?
                    if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                        appName = app.localizedName ?? "Media"
                        bundleID = app.bundleIdentifier ?? ""
                        appIcon = app.icon
                    }
                    self.currentTrack = SystemMediaTrack(
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        elapsedTime: elapsed,
                        isPlaying: playing,
                        appName: appName,
                        bundleIdentifier: bundleID,
                        appIcon: appIcon,
                        artwork: artwork ?? appIcon
                    )
                }
            }
        }
    }

    // MARK: - Spotify Integration (Background Non-Blocking)

    nonisolated private static func querySpotifyBackground() -> SystemMediaTrack? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first else {
            return nil
        }

        let scriptText = """
        tell application "Spotify"
            if player state is stopped then
                return "stopped"
            end if
            set pState to player state as string
            set tName to ""
            set tArtist to ""
            set tAlbum to ""
            set tPos to 0
            set tDur to 0
            set tArt to ""
            try
                set tName to name of current track
            end try
            try
                set tArtist to artist of current track
            end try
            try
                set tAlbum to album of current track
            end try
            try
                set tPos to player position
            end try
            try
                set tDur to (duration of current track) / 1000
            end try
            try
                set tArt to artwork url of current track
            end try
            return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tPos & "|||" & tDur & "|||" & tArt
        end tell
        """
        guard let script = NSAppleScript(source: scriptText) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil, let raw = descriptor.stringValue, raw != "stopped" else {
            return nil
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let pState = parts[0].lowercased()
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let pos = Double(parts[4]) ?? 0
        let dur = Double(parts[5]) ?? 0
        let isPlaying = (pState == "playing")

        return SystemMediaTrack(
            title: title,
            artist: artist,
            album: album,
            duration: dur,
            elapsedTime: pos,
            isPlaying: isPlaying,
            appName: "Spotify",
            bundleIdentifier: "com.spotify.client",
            appIcon: app.icon,
            artwork: app.icon
        )
    }

    // MARK: - Apple Music Integration (Background Non-Blocking)

    nonisolated private static func queryAppleMusicBackground() -> SystemMediaTrack? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
            return nil
        }

        let scriptText = """
        tell application "Music"
            if player state is stopped then
                return "stopped"
            end if
            set pState to player state as string
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tPos to player position
            set tDur to duration of current track
            return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tPos & "|||" & tDur
        end tell
        """
        guard let script = NSAppleScript(source: scriptText) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil, let raw = descriptor.stringValue, raw != "stopped" else {
            return nil
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let pState = parts[0].lowercased()
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let pos = Double(parts[4]) ?? 0
        let dur = Double(parts[5]) ?? 0
        let isPlaying = (pState == "playing")

        return SystemMediaTrack(
            title: title,
            artist: artist,
            album: album,
            duration: dur,
            elapsedTime: pos,
            isPlaying: isPlaying,
            appName: "Music",
            bundleIdentifier: "com.apple.Music",
            appIcon: app.icon,
            artwork: app.icon
        )
    }

    private func fetchArtwork(url: URL, cacheKey: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            Task { @MainActor in
                self?.artworkCache[cacheKey] = image
                if self?.currentTrack?.bundleIdentifier == "com.spotify.client" {
                    self?.currentTrack?.artwork = image
                }
            }
        }.resume()
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        if currentTrack?.bundleIdentifier == "com.spotify.client" {
            let ok = executeAppleScript("tell application \"Spotify\" to playpause")
            if !ok, let sendCommand {
                _ = sendCommand(2, nil)
            }
            refresh()
            return
        }
        if currentTrack?.bundleIdentifier == "com.apple.Music" {
            let ok = executeAppleScript("tell application \"Music\" to playpause")
            if !ok, let sendCommand {
                _ = sendCommand(2, nil)
            }
            refresh()
            return
        }

        if let sendCommand {
            _ = sendCommand(2, nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.refresh()
            }
        }
    }

    public func nextTrack() {
        if currentTrack?.bundleIdentifier == "com.spotify.client" {
            let ok = executeAppleScript("tell application \"Spotify\" to next track")
            if !ok, let sendCommand {
                _ = sendCommand(4, nil)
            }
            refresh()
            return
        }
        if currentTrack?.bundleIdentifier == "com.apple.Music" {
            let ok = executeAppleScript("tell application \"Music\" to next track")
            if !ok, let sendCommand {
                _ = sendCommand(4, nil)
            }
            refresh()
            return
        }

        if let sendCommand {
            _ = sendCommand(4, nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.refresh()
            }
        }
    }

    public func previousTrack() {
        if currentTrack?.bundleIdentifier == "com.spotify.client" {
            let ok = executeAppleScript("tell application \"Spotify\" to previous track")
            if !ok, let sendCommand {
                _ = sendCommand(5, nil)
            }
            refresh()
            return
        }
        if currentTrack?.bundleIdentifier == "com.apple.Music" {
            let ok = executeAppleScript("tell application \"Music\" to previous track")
            if !ok, let sendCommand {
                _ = sendCommand(5, nil)
            }
            refresh()
            return
        }

        if let sendCommand {
            _ = sendCommand(5, nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.refresh()
            }
        }
    }

    public func seek(to position: TimeInterval) {
        if currentTrack?.bundleIdentifier == "com.spotify.client" {
            executeAppleScript("tell application \"Spotify\" to set player position to \(position)")
            currentTrack?.elapsedTime = position
            return
        }
        if currentTrack?.bundleIdentifier == "com.apple.Music" {
            executeAppleScript("tell application \"Music\" to set player position to \(position)")
            currentTrack?.elapsedTime = position
            return
        }
    }

    @discardableResult
    private func executeAppleScript(_ source: String) -> Bool {
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        let res = script?.executeAndReturnError(&errorInfo)
        return errorInfo == nil && res != nil
    }
}
