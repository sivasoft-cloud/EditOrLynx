import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    public func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        win.title = "Edit.or.lynx Settings"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.center()
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: settingsView)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }
}
