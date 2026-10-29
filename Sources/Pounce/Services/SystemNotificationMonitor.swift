import AppKit
import Foundation
import IOKit.ps
import CoreAudio
import AudioToolbox
import PounceCore

/// Observes system-wide macOS notifications and events (CoreAudio volume changes,
/// AirDrop received files, screenshots, power connection, external drives, sleep/wake,
/// media changes, app lifecycle) and routes them into the Notch.
@MainActor
final class SystemNotificationMonitor {
    static let shared = SystemNotificationMonitor()

    weak var model: AppModel?

    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var powerRunLoopSource: CFRunLoopSource?
    private var lastPowerState: String?
    private var lastNotificationTime: Date = .distantPast
    private var lastNoticeKey: String = ""

    // MARK: - CoreAudio Volume & Device Monitor
    private var currentOutputDeviceID: AudioObjectID = 0
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var lastObservedVolume: Int = -1
    private var lastObservedMute: Bool = false

    // MARK: - AirDrop & Downloads Folder Monitoring
    private var downloadsFolderSource: DispatchSourceFileSystemObject?
    private var downloadsFolderFD: Int32 = -1
    private var knownDownloadFileNames: Set<String> = []

    private init() {}

    func start(model: AppModel) {
        self.model = model
        stop()

        installDistributedObservers()
        installWorkspaceObservers()
        installPowerSourceMonitor()
        installVolumeMonitor()
        installDownloadsMonitor()
    }

    func stop() {
        for obs in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        distributedObservers.removeAll()

        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()

        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            powerRunLoopSource = nil
        }

        // Clean up CoreAudio listeners
        detachFromCurrentDefaultDevice()
        if let changeBlock = deviceChangeListenerBlock {
            var defaultDeviceAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                DispatchQueue.main,
                changeBlock
            )
            deviceChangeListenerBlock = nil
        }

        // Clean up Downloads monitor
        if let source = downloadsFolderSource {
            source.cancel()
            downloadsFolderSource = nil
            downloadsFolderFD = -1
        }
    }

    // MARK: - CoreAudio System Volume & Output Device Monitoring

    private func installVolumeMonitor() {
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let changeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleDefaultDeviceChanged()
            }
        }
        self.deviceChangeListenerBlock = changeBlock

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            changeBlock
        )

        attachToCurrentDefaultDevice()
    }

    private func attachToCurrentDefaultDevice() {
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == 0, deviceID != 0 else { return }

        detachFromCurrentDefaultDevice()
        self.currentOutputDeviceID = deviceID

        // Cache initial volume
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &vol) == 0 {
            lastObservedVolume = Int((vol * 100.0).rounded())
        }

        // Cache initial mute
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isMutedInt: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &isMutedInt) == 0 {
            lastObservedMute = (isMutedInt != 0)
        }

        // Register volume listener
        let vBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.checkVolumeChange()
            }
        }
        self.volumeListenerBlock = vBlock
        AudioObjectAddPropertyListenerBlock(deviceID, &volAddress, DispatchQueue.main, vBlock)

        // Register mute listener
        let mBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.checkVolumeChange()
            }
        }
        self.muteListenerBlock = mBlock
        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, mBlock)
    }

    private func detachFromCurrentDefaultDevice() {
        guard currentOutputDeviceID != 0 else { return }

        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let vBlock = volumeListenerBlock {
            AudioObjectRemovePropertyListenerBlock(currentOutputDeviceID, &volAddress, DispatchQueue.main, vBlock)
            volumeListenerBlock = nil
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if let mBlock = muteListenerBlock {
            AudioObjectRemovePropertyListenerBlock(currentOutputDeviceID, &muteAddress, DispatchQueue.main, mBlock)
            muteListenerBlock = nil
        }

        currentOutputDeviceID = 0
    }

    private func handleDefaultDeviceChanged() {
        attachToCurrentDefaultDevice()
        let name = getDeviceName(deviceID: currentOutputDeviceID)
        postNotice(title: "Audio Output Changed", text: name, symbol: "speaker.wave.2.fill")
    }

    private func getDeviceName(deviceID: AudioObjectID) -> String {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: CFString?
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        if AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &cfName) == 0, let name = cfName as String? {
            return name
        }
        return "Audio Output"
    }

    private func checkVolumeChange() {
        guard currentOutputDeviceID != 0 else { return }

        // Check Mute
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var isMutedInt: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let isMuted: Bool
        if AudioObjectGetPropertyData(currentOutputDeviceID, &muteAddress, 0, nil, &muteSize, &isMutedInt) == 0 {
            isMuted = (isMutedInt != 0)
        } else {
            isMuted = false
        }

        // Check Volume
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var percent = lastObservedVolume
        if AudioObjectGetPropertyData(currentOutputDeviceID, &volAddress, 0, nil, &volSize, &vol) == 0 {
            percent = max(0, min(100, Int((vol * 100.0).rounded())))
        }

        // Handle mute change
        if isMuted != lastObservedMute {
            lastObservedMute = isMuted
            if isMuted {
                model?.showNotification(title: "Volume", text: "Muted", symbol: "speaker.slash.fill")
                return
            }
        }

        // Handle volume change
        if percent != lastObservedVolume {
            lastObservedVolume = percent
            let symbol: String
            if percent == 0 || isMuted {
                symbol = "speaker.slash.fill"
            } else if percent < 33 {
                symbol = "speaker.wave.1.fill"
            } else if percent < 66 {
                symbol = "speaker.wave.2.fill"
            } else {
                symbol = "speaker.wave.3.fill"
            }
            model?.showNotification(title: "Volume: \(percent)%", text: getDeviceName(deviceID: currentOutputDeviceID), symbol: symbol)
        }
    }

    // MARK: - AirDrop & Downloads Folder Monitoring

    private func installDownloadsMonitor() {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ("~/Downloads" as NSString).expandingTildeInPath
        let fd = open(downloadsPath, O_EVTONLY)
        guard fd >= 0 else { return }
        downloadsFolderFD = fd

        // Seed initial files so existing files don't trigger alerts
        if let existing = try? FileManager.default.contentsOfDirectory(atPath: downloadsPath) {
            knownDownloadFileNames = Set(existing)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.checkDownloadsChanges(in: downloadsPath)
        }

        source.setCancelHandler {
            close(fd)
        }

        downloadsFolderSource = source
        source.resume()
    }

    private func checkDownloadsChanges(in path: String) {
        guard let currentFiles = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }
        let currentSet = Set(currentFiles)
        let added = currentSet.subtracting(knownDownloadFileNames)
        knownDownloadFileNames = currentSet

        for fileName in added {
            // Ignore hidden files and temporary partial downloads
            if fileName.hasPrefix(".") || fileName.hasSuffix(".download") || fileName.hasSuffix(".crdownload") || fileName.hasSuffix(".part") || fileName.hasSuffix(".tmp") {
                continue
            }
            let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)

            // Detect AirDrop transfer
            if isAirDropFile(at: fileURL) {
                postNotice(title: "AirDrop Received", text: fileName, symbol: "airdrop")
            } else {
                postNotice(title: "File Saved", text: fileName, symbol: "arrow.down.doc.fill")
            }
        }
    }

    private func isAirDropFile(at url: URL) -> Bool {
        let length = getxattr(url.path, "com.apple.quarantine", nil, 0, 0, 0)
        guard length > 0 else { return false }
        var buffer = [CChar](repeating: 0, count: length + 1)
        getxattr(url.path, "com.apple.quarantine", &buffer, length, 0, 0)
        let str = String(cString: buffer)
        return str.contains("sharingd")
    }

    // MARK: - Distributed macOS System Events

    private func installDistributedObservers() {
        let center = DistributedNotificationCenter.default()

        // 1. Apple Music / iTunes Now Playing
        let musicObs = center.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in self?.handlePlayerInfo(notif, player: "Apple Music") }
        }
        distributedObservers.append(musicObs)

        // 2. Spotify Playback Change
        let spotifyObs = center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in self?.handlePlayerInfo(notif, player: "Spotify") }
        }
        distributedObservers.append(spotifyObs)

        // 3. macOS Screenshot capture
        let screenObs = center.addObserver(
            forName: NSNotification.Name("com.apple.screencapture.screenCaptured"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Screenshot Captured", text: "Saved to your desktop / clipboard", symbol: "camera.viewfinder") }
        }
        distributedObservers.append(screenObs)

        // 4. macOS Screen Lock
        let lockObs = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Screen Locked", text: "Mac display protected", symbol: "lock.fill") }
        }
        distributedObservers.append(lockObs)

        // 5. macOS Screen Unlock
        let unlockObs = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Screen Unlocked", text: "Welcome back", symbol: "lock.open.fill") }
        }
        distributedObservers.append(unlockObs)

        // 6. System Appearance (Dark / Light Theme switch)
        let themeObs = center.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Theme Changed", text: "System interface appearance updated", symbol: "circle.lefthalf.filled") }
        }
        distributedObservers.append(themeObs)

        // 7. Keyboard Input Language Source Change (English <-> Tamil etc.)
        let inputObs = center.addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Keyboard Switched", text: "Input language updated", symbol: "keyboard") }
        }
        distributedObservers.append(inputObs)

    }

    // MARK: - Workspace Events (Sleep, Wake, Volume Mount/Unmount, App Lifecycle)

    private func installWorkspaceObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter

        // App Launched
        let launchObs = wsCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let name = app?.localizedName ?? "Application"
                if app?.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.postNotice(title: "App Opened", text: "\(name) is now running", symbol: "app.badge.checkmark")
                }
            }
        }
        workspaceObservers.append(launchObs)

        // App Terminated
        let termObs = wsCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let name = app?.localizedName ?? "Application"
                if app?.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.postNotice(title: "App Closed", text: "\(name) quit", symbol: "xmark.app")
                }
            }
        }
        workspaceObservers.append(termObs)

        // Volume mounted (USB, DMG, External Drive)
        let mountObs = wsCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                let volURL = notif.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                let name = volURL?.lastPathComponent ?? "External Disk"
                self?.postNotice(title: "Drive Connected", text: "\(name) mounted", symbol: "externaldrive.badge.plus")
            }
        }
        workspaceObservers.append(mountObs)

        // Volume unmounted / ejected
        let unmountObs = wsCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor in
                let volURL = notif.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                let name = volURL?.lastPathComponent ?? "External Disk"
                self?.postNotice(title: "Drive Ejected", text: "\(name) safely disconnected", symbol: "eject.circle.fill")
            }
        }
        workspaceObservers.append(unmountObs)

        // Mac sleep
        let sleepObs = wsCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Mac Sleeping", text: "All background transfers paused", symbol: "moon.stars.fill") }
        }
        workspaceObservers.append(sleepObs)

        // Mac wake
        let wakeObs = wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Mac Awake", text: "Ready to download and multitask", symbol: "sun.max.fill") }
        }
        workspaceObservers.append(wakeObs)

        // Space / Mission Control Switch
        let spaceObs = wsCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.postNotice(title: "Desktop Switched", text: "Active space changed", symbol: "rectangle.split.2x1") }
        }
        workspaceObservers.append(spaceObs)
    }

    // MARK: - Battery & Power Monitoring

    private func installPowerSourceMonitor() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let loopSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<SystemNotificationMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in monitor.checkPowerState() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
            self.powerRunLoopSource = loopSource
        }

        // Cache initial state
        updatePowerStateSilent()
    }

    private func checkPowerState() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        let powerSource = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? ""
        let currentCap = (desc[kIOPSCurrentCapacityKey as String] as? Int) ?? 100
        let stateTag = "\(powerSource)-\(isCharging)"

        if let last = lastPowerState, last != stateTag {
            if isCharging || powerSource == (kIOPSACPowerValue as String) {
                postNotice(title: "Power Connected", text: "Charging • \(currentCap)%", symbol: "bolt.badge.automatic.fill")
            } else {
                postNotice(title: "On Battery Power", text: "\(currentCap)% remaining", symbol: "battery.75")
            }
        }
        lastPowerState = stateTag
    }

    private func updatePowerStateSilent() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return
        }
        let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        let powerSource = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? ""
        lastPowerState = "\(powerSource)-\(isCharging)"
    }

    // MARK: - Handlers

    private func handlePlayerInfo(_ notif: Notification, player: String) {
        guard let info = notif.userInfo else { return }
        let state = (info["Player State"] as? String) ?? (info["playerState"] as? String) ?? ""
        guard state.lowercased() == "playing" else { return }

        let name = (info["Name"] as? String) ?? (info["trackName"] as? String) ?? ""
        let artist = (info["Artist"] as? String) ?? (info["artist"] as? String) ?? ""
        guard !name.isEmpty else { return }

        let text = artist.isEmpty ? name : "\(name) • \(artist)"
        postNotice(title: "\(player) Playing", text: text, symbol: "music.note")
    }

    private func postNotice(title: String, text: String, symbol: String) {
        // When in standby / idle mode, suppress spontaneous notifications so notch remains peaceful
        guard AppState.shared.currentState != .compact || AppState.shared.activeModule != nil else {
            return
        }

        let key = "\(title):\(text)"
        let now = Date()
        // Deduplicate identical notice within 2.0s while allowing different notifications immediately
        if key == lastNoticeKey && now.timeIntervalSince(lastNotificationTime) < 2.0 {
            return
        }
        lastNoticeKey = key
        lastNotificationTime = now
        model?.showNotification(title: title, text: text, symbol: symbol)
        NotificationManager.shared.postSystemNotice(title: title, text: text, symbol: symbol)
    }
}
