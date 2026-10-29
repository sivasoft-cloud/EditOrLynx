import AppKit
import SwiftUI
import PounceCore

final class OptionsPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class OptionsWindowController: NSWindowController {
    private let model: AppModel
    private var keyMonitor: Any?

    init(model: AppModel) {
        self.model = model
        let panel = OptionsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        super.init(window: panel)

        panel.onCancel = { [weak self] in self?.closePanel() }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.window?.isKeyWindow == true else { return event }
            self.closePanel()
            return nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func show(for info: LinkInfo) {
        if info.kind == .playlist {
            showPlaylist(for: info)
        } else {
            showQuality(for: info)
        }
    }

    func showQuality(for info: LinkInfo) {
        let view = DownloadOptionsView(
            model: model,
            info: info,
            onClose: { [weak self] in self?.closePanel() },
            onClip: { [weak self] in self?.showClip(for: info) }
        )
        present(view, size: NSSize(width: 604, height: 548))
    }

    func showPlaylist(for info: LinkInfo) {
        let view = PlaylistOptionsView(
            model: model,
            info: info,
            onClose: { [weak self] in self?.closePanel() }
        )
        present(view, size: NSSize(width: 604, height: 672))
    }

    func showClip(for info: LinkInfo) {
        let view = ClipEditorView(
            model: model,
            info: info,
            onClose: { [weak self] in self?.closePanel() }
        )
        present(view, size: NSSize(width: 804, height: 748))
    }

    func closePanel() {
        window?.orderOut(nil)
    }

    private func present<V: View>(_ view: V, size: NSSize) {
        guard let window else { return }
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setContentSize(size)
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - size.width / 2
            let y = screen.visibleFrame.midY - size.height / 2 + 16
            window.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
