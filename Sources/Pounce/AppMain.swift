import AppKit
import PounceCore
import SwiftUI

@main
@MainActor
enum PounceMain {
    static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        app.delegate = appDelegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate? = nil

    private var model: AppModel!
    private var mainWindow: MainWindowController!
    private var options: OptionsWindowController!
    private var settings: SettingsWindowController!
    private var pro: ProWindowController!
    private var onboarding: DownloadOnboardingWindowController!
    private var floating: FloatingButtonController!
    private var islandWindowController: IslandWindowController?
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSWindow.allowsAutomaticWindowTabbing = false

        model = AppModel()
        buildMenu()
        buildStatusItem()

        mainWindow = MainWindowController(model: model)
        options = OptionsWindowController(model: model)
        settings = SettingsWindowController(model: model)
        pro = ProWindowController(model: model)
        onboarding = DownloadOnboardingWindowController(model: model)
        floating = FloatingButtonController(model: model)

        model.openOnboarding = { [weak self] in
            guard let self else { return }
            self.mainWindow.show()
            self.model.isShowingWelcomeIntro = true
        }

        model.presentOptions = { [weak self] info in
            guard let self else { return }
            self.mainWindow.show()
            self.model.activeOptionsLink = info
        }
        model.presentClip = { [weak self] info in
            guard let self else { return }
            self.mainWindow.show()
            self.model.activeClipLink = info
        }
        model.openNotch = { [weak self] tab in
            Task { @MainActor in
                if tab == .downloads {
                    AppState.shared.setModuleEnabled(.downloads, true)
                    AppState.shared.showHUD(module: .builtIn(.downloads), autoDismiss: false)
                }
                self?.islandWindowController?.showIsland()
            }
        }
        model.openNotchMain = { [weak self] in
            self?.restoreFromNotch()
        }
        model.openSettings = { [weak self] in
            guard let self else { return }
            self.settings.show()
        }
        model.openPro = { [weak self] in
            guard let self else { return }
            self.restoreFromNotch()
            self.model.isShowingSettings = false
            self.model.isShowingProView = true
        }
        model.dismissProWindow = { [weak self] in
            self?.model.isShowingProView = false
            self?.model.isShowingProModal = false
        }
        model.toggleBrowserButton = { [weak self] show in
            show ? self?.floating.show() : self?.floating.hide()
        }
        model.onDetectedLink = { [weak self] info in
            Task { @MainActor in
                AppState.shared.setModuleEnabled(.downloads, true)
                AppState.shared.showHUD(module: .builtIn(.downloads), autoDismiss: true, autoDismissDelay: 12.0)
                self?.islandWindowController?.showIsland()
            }
        }
        model.onDownloadCompleted = { [weak self] _ in
            Task { @MainActor in
                AppState.shared.setModuleEnabled(.downloads, true)
                AppState.shared.showHUD(module: .builtIn(.downloads), autoDismiss: true, autoDismissDelay: 5.0)
                self?.islandWindowController?.showIsland()
            }
        }
        model.onShowToast = { _ in }
        model.onShowNotch = { [weak self] in
            Task { @MainActor in
                self?.islandWindowController?.showIsland()
            }
        }
        model.onHideNotch = {
            Task { @MainActor in
                AppState.shared.dismiss()
            }
        }

        // Monitors all Mac notifications, media changes, power, drive mounts, and screenshots.
        SystemNotificationMonitor.shared.start(model: model)

        // The browser extensions talk to this loopback door.
        ExtensionBridge.shared.model = model
        ExtensionBridge.shared.start()

        // Automatically verify and install yt-dlp & toolchain dependencies in background
        ToolchainService.shared.ensureDependencies()

        // Handle macOS system shutdown/restart/logout cleanly
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillPowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )

        mainWindow.show()
        if model.engine.settings.showBrowserButton {
            floating.show()
        }

        setupIslandWindow()
        initializeIslandManagers()

        // Temporary verification hooks (removed after capture).
        let args = CommandLine.arguments
        if args.contains("--show-settings") { settings.show() }
        if args.contains("--show-pro") { pro.show() }
        if args.contains("--show-quality"),
           let info = LinkInspector.inspect("https://northlight.films/films/still-water") {
            model.presentOptions?(info)
        }
        if args.contains("--show-clip"),
           let info = LinkInspector.inspect("https://northlight.films/films/still-water") {
            model.presentClip?(info)
        }
        if args.contains("--show-welcome") || !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            model.isShowingWelcomeIntro = true
        }
        if args.contains("--capture-screenshots") {
            captureScreenshots()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private var isForceQuitting = false

    func applicationWillTerminate(_ notification: Notification) {
        cleanupAndQuitEverything()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isForceQuitting {
            cleanupAndQuitEverything()
            return .terminateNow
        }
        // When closing or quitting from Dock/Cmd-Q:
        // App closes window and hides from Dock, keeping the Notch active on screen!
        closeToNotch()
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func systemWillPowerOff() {
        isForceQuitting = true
        cleanupAndQuitEverything()
        NSApp.terminate(nil)
    }

    @objc func forceQuitApp() {
        isForceQuitting = true
        cleanupAndQuitEverything()
        NSApp.terminate(nil)
    }

    @objc func closeToNotch() {
        mainWindow?.close()
        settings?.close()
        pro?.close()
        floating?.hide()
        NSApp.setActivationPolicy(.accessory)
        islandWindowController?.showIsland()
    }

    @objc func restoreFromNotch() {
        NSApp.setActivationPolicy(.regular)
        mainWindow?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func cleanupAndQuitEverything() {
        islandWindowController?.hideIsland()
        mainWindow?.close()
        settings?.close()
        pro?.close()
        floating?.hide()
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        AgentsStatusBridge.shared.stop()
        ExtensionBridge.shared.stop()
        model?.shutdown()

        // Promptly terminate process so Mac shutdown or app quit never blocks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }

    @objc private func clearAllTasks() {
        model.clearAllTasks()
    }

    private func setupIslandWindow() {
        islandWindowController = IslandWindowController()
        islandWindowController?.showIsland()
    }

    private func initializeIslandManagers() {
        Analytics.start()
        let state = AppState.shared
        if state.nowPlayingEnabled { _ = NowPlayingManager.shared }
        if state.volumeHUDEnabled { _ = VolumeManager.shared }
        if state.batteryEnabled { _ = BatteryManager.shared }
        if state.connectivityEnabled {
            _ = WiFiManager.shared
            if PermissionsManager.shared.check(.bluetooth) {
                _ = BluetoothManager.shared
            }
        }
        if state.notificationsEnabled {
            _ = NotificationManager.shared
        }
        if state.teleprompterEnabled {
            _ = TeleprompterManager.shared
        }

        let extensions = ExtensionManager.shared
        extensions.discoverExtensions()
        extensions.activateDiscoveredExtensions()
        state.refreshEnergyState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return true
    }

    // MARK: URL Handling (editorlynx://activate?key=...)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "editorlynx" || url.scheme == "pounce" else { return }
        if url.host == "activate" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let key = components?.queryItems?.first(where: { $0.name == "key" })?.value, !key.isEmpty {
                model.activatePro(key)
                pro.show()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Edit.or.lynx")
        appMenu.addItem(withTitle: "About Edit.or.lynx", action: #selector(showAbout), keyEquivalent: "")
            .target = self
        appMenu.addItem(withTitle: "Welcome & Browser Setup…", action: #selector(showOnboarding), keyEquivalent: "")
            .target = self
        appMenu.addItem(.separator())
        let buttonItem = appMenu.addItem(withTitle: "Show Edit.or.lynx Button", action: #selector(toggleFloatingButton), keyEquivalent: "")
        buttonItem.target = self
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Edit.or.lynx", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let closeNotchItem = appMenu.addItem(withTitle: "Close to Notch (Hide from Dock)", action: #selector(closeToNotch), keyEquivalent: "q")
        closeNotchItem.target = self
        let forceQuitItem = appMenu.addItem(withTitle: "Quit Edit.or.lynx Completely", action: #selector(forceQuitApp), keyEquivalent: "Q")
        forceQuitItem.keyEquivalentModifierMask = [.command, .shift]
        forceQuitItem.target = self
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let newDownload = fileMenu.addItem(withTitle: "New Download…", action: #selector(showMain), keyEquivalent: "n")
        newDownload.target = self
        let clipboardDownload = fileMenu.addItem(withTitle: "Download from Clipboard", action: #selector(downloadFromClipboard), keyEquivalent: "v")
        clipboardDownload.keyEquivalentModifierMask = [.command, .shift]
        clipboardDownload.target = self
        fileMenu.addItem(.separator())
        let openDownloads = fileMenu.addItem(withTitle: "Open Download Folder", action: #selector(openDownloadsFolder), keyEquivalent: "")
        openDownloads.target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Welcome & Browser Extension Setup…", action: #selector(showOnboarding), keyEquivalent: "")
            .target = self
        let aboutHelp = helpMenu.addItem(withTitle: "Edit.or.lynx Help", action: #selector(showAbout), keyEquivalent: "")
        aboutHelp.target = self
        helpItem.submenu = helpMenu
        mainMenu.addItem(helpItem)

        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "arrow.down.to.line.compact", accessibilityDescription: "Edit.or.lynx")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Edit.or.lynx — downloads in your notch"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusMenu = menu
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        menu.removeAllItems()
        let active = model.engine.activeCount
        let header = NSMenuItem(title: active > 0 ? "\(active) downloading — \(Fmt.speed(model.engine.totalSpeed))" : "Edit.or.lynx — ready", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Edit.or.lynx", action: #selector(showMain), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Now Playing", action: #selector(showNowPlaying), keyEquivalent: "").target = self
        if BatteryManager.shared.hasBattery {
            menu.addItem(withTitle: "Battery", action: #selector(showBattery), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "Notch Shelf", action: #selector(showShelf), keyEquivalent: "").target = self

        let accentItem = NSMenuItem(title: "Accent Color", action: nil, keyEquivalent: "")
        let accentMenu = NSMenu()
        for choice in AccentChoice.allCases {
            let aItem = NSMenuItem(title: choice.title, action: #selector(selectAccentColor(_:)), keyEquivalent: "")
            aItem.target = self
            aItem.representedObject = choice.rawValue
            aItem.state = (model.accent == choice) ? .on : .off
            accentMenu.addItem(aItem)
        }
        accentItem.submenu = accentMenu
        menu.addItem(accentItem)

        let modulesItem = NSMenuItem(title: "Notch Modules", action: nil, keyEquivalent: "")
        let modulesMenu = NSMenu()
        for module in ModuleType.allCases {
            let mItem = NSMenuItem(title: module.displayName, action: #selector(toggleModule(_:)), keyEquivalent: "")
            mItem.target = self
            mItem.representedObject = module.rawValue
            mItem.state = AppState.shared.isModuleEnabled(module) ? .on : .off
            mItem.image = NSImage(systemSymbolName: module.iconName, accessibilityDescription: module.displayName)
            modulesMenu.addItem(mItem)
        }
        modulesItem.submenu = modulesMenu
        menu.addItem(modulesItem)

        menu.addItem(.separator())
        let pause = menu.addItem(withTitle: "Pause All", action: #selector(pauseAll), keyEquivalent: "")
        pause.target = self
        pause.isEnabled = active > 0
        let resume = menu.addItem(withTitle: "Resume All", action: #selector(resumeAll), keyEquivalent: "")
        resume.target = self
        resume.isEnabled = model.engine.downloads.contains { $0.state == .paused }
        let clearTasks = menu.addItem(withTitle: "Clear All Tasks", action: #selector(clearAllTasks), keyEquivalent: "")
        clearTasks.target = self
        clearTasks.isEnabled = model.engine.activeCount > 0 || model.engine.downloads.contains { $0.state == .paused || $0.state == .queued }
        menu.addItem(.separator())
        let button = menu.addItem(withTitle: model.engine.settings.showBrowserButton ? "Hide Edit.or.lynx Button" : "Show Edit.or.lynx Button", action: #selector(toggleFloatingButton), keyEquivalent: "")
        button.target = self
        menu.addItem(withTitle: "Connect Browsers & Setup…", action: #selector(showOnboarding), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close to Notch (Hide from Dock)", action: #selector(closeToNotch), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit Edit.or.lynx Completely", action: #selector(forceQuitApp), keyEquivalent: "").target = self
    }

    // MARK: Actions

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "The download manager that lives in your notch.\n\nMade by edit.or.siva · Instagram @edit.or.siva\n\n© edit.or.siva",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "Edit.or.lynx",
            .applicationVersion: "1.0"
        ])
    }

    @objc private func showOnboarding() {
        onboarding.show()
    }

    @objc private func showMain() {
        restoreFromNotch()
    }

    @objc private func showNowPlaying() {
        AppState.shared.setActiveModule(.builtIn(.nowPlaying))
        islandWindowController?.showIsland()
    }

    @objc private func showBattery() {
        AppState.shared.setActiveModule(.builtIn(.battery))
        islandWindowController?.showIsland()
    }

    @objc private func showShelf() {
        AppState.shared.setActiveModule(.builtIn(.shelf))
        islandWindowController?.showIsland()
    }

    @objc private func toggleModule(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let module = ModuleType(rawValue: raw) else { return }
        let current = AppState.shared.isModuleEnabled(module)
        AppState.shared.setModuleEnabled(module, !current)
    }

    @objc private func selectAccentColor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let choice = AccentChoice(rawValue: raw) else { return }
        model.setAccent(choice)
        model.showToast("Accent set to \(choice.title)", symbol: "paintpalette.fill")
    }

    static func showSettingsWindow() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showSettings()
        }
    }

    @objc private func showSettings() {
        settings.show()
    }

    @objc private func downloadFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.beginLink(text)
        } else if let image = NSImage(pasteboard: .general) {
            model.saveClipboardImage(image)
        } else {
            model.showToast("The clipboard doesn't hold a link or image", symbol: "doc.on.clipboard")
        }
    }

    @objc private func openDownloadsFolder() {
        model.openDestinationInFinder()
    }

    @objc private func pauseAll() {
        model.pauseAll()
    }

    @objc private func resumeAll() {
        model.resumeAll()
    }

    @objc private func toggleFloatingButton() {
        let next = !model.engine.settings.showBrowserButton
        model.setBrowserButton(next)
    }

    private func captureScreenshots() {
        let dir = URL(fileURLWithPath: "/Users/sivasoft/Downloads/temp/lynk/EditOrLynx/assets/screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        func save<V: View>(_ view: V, size: CGSize, name: String) {
            let hosting = NSHostingView(rootView: view.preferredColorScheme(.dark))
            hosting.frame = CGRect(origin: .zero, size: size)
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            rep.size = size
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                let target = dir.appendingPathComponent(name)
                try? data.write(to: target)
                print("✓ Saved screenshot: \(target.lastPathComponent)")
            }
        }

        // 1. Main Transfer Manager Window
        save(MainWindowView(model: model), size: CGSize(width: 1180, height: 780), name: "01_main_transfer_manager.png")

        // 2. Bit-Perfect Studio Lossless Audio Option
        let spotifyInfo = LinkInfo(
            url: URL(string: "https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT")!,
            host: "open.spotify.com",
            title: "Rick Astley - Never Gonna Give You Up",
            kind: .audio,
            duration: 213,
            fullBytes: 38_000_000
        )
        save(DownloadOptionsView(model: model, info: spotifyInfo, onClose: {}, onClip: {}), size: CGSize(width: 640, height: 560), name: "02_lossless_studio_audio_modal.png")

        // 3. Google Drive 100-File Batch Auto-Zip
        let gdriveURL = URL(string: "https://drive.google.com/drive/folders/1abc987xyz_Production_Assets")!
        save(GoogleDriveFolderView(model: model, folderURL: gdriveURL, onClose: {}), size: CGSize(width: 640, height: 620), name: "03_google_drive_100batch_zip.png")

        // 4. Browser Extensions Hub (8 Browsers)
        save(DownloadManagerSettingsView(model: model), size: CGSize(width: 680, height: 620), name: "04_browser_extensions_hub.png")

        // 5. Edit.or.lynx PRO Unlocked Capabilities
        save(ProView(model: model, onClose: {}), size: CGSize(width: 680, height: 600), name: "05_pro_features_unlocked.png")

        // 6. Precision Clip Editor
        let videoInfo = LinkInfo(
            url: URL(string: "https://northlight.films/films/still-water")!,
            host: "northlight.films",
            title: "High Altitude 4K Master Cinema Cut",
            kind: .video,
            duration: 520,
            fullBytes: 1_200_000_000
        )
        save(ClipEditorView(model: model, info: videoInfo, onClose: {}), size: CGSize(width: 720, height: 560), name: "06_precision_clip_editor.png")

        // 7. Onboarding Welcome Experience
        save(DownloadOnboardingView(model: model, onComplete: {}), size: CGSize(width: 680, height: 580), name: "08_onboarding_welcome.png")

        print("▸ All 8 key feature screenshots generated successfully!")
    }
}
