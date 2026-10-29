import AppKit
import SwiftUI

@MainActor
public final class MainWindowController: NSWindowController {
    public static let shared = MainWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit.or.lynx Downloader"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = NSSize(width: 720, height: 460)
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("EditOrLynxMainWindow")
        window.center()

        let hosting = NSHostingView(
            rootView: MainWindowView()
                .environmentObject(DownloadEngine.shared)
        )
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        NSApp.setActivationPolicy(.regular)
        guard let window = self.window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func toggle() {
        guard let window = self.window else { return }
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show()
        }
    }
}
