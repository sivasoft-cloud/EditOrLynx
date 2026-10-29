import SwiftUI
import AppKit

@main
struct EditOrLynxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(DownloadEngine.shared)
                .frame(minWidth: 680, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Edit.or.lynx") {
                    SettingsWindowController.shared.show()
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize Notch Engine
        NotchWindowController.shared.setup()

        // 2. Initialize Browser Bridge
        BrowserBridge.shared.onDownloadRequested = { url, customFilename in
            _ = DownloadEngine.shared.startDownload(url: url, customFilename: customFilename)
        }

        // 3. Initialize Clipboard Monitor
        _ = ClipboardMonitor.shared

        // 4. Setup Status Item (Menu Bar Icon)
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.horizontal.circle.fill", accessibilityDescription: "Edit.or.lynx")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit.or.lynx Downloader", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Downloader Window", action: #selector(showMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Toggle Notch HUD", action: #selector(toggleNotch), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Edit.or.lynx", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NotchPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func toggleNotch() {
        NotchWindowController.shared.toggleExpanded()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
