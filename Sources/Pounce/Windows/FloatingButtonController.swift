import AppKit
import SwiftUI
import PounceCore

@MainActor
final class FloatingButtonController: NSWindowController {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 48),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        let view = FloatingButtonView(
            model: model,
            onOpen: { [weak model] in
                guard let model else { return }
                FloatingButtonController.openLink(model: model)
            },
            onHide: { [weak model] in
                model?.setBrowserButton(false)
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        super.init(window: panel)
        positionDefault()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        positionDefaultIfNeeded()
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true { hide() } else { show() }
    }

    private func positionDefault() {
        guard let screen = NSScreen.main, let window else { return }
        let x = screen.visibleFrame.maxX - 168
        let y = screen.visibleFrame.maxY - 116
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionDefaultIfNeeded() {
        guard let window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        if !visible.intersects(window.frame) {
            positionDefault()
        }
    }

    private static func openLink(model: AppModel) {
        if let text = NSPasteboard.general.string(forType: .string),
           let info = LinkInspector.inspect(text) {
            model.handle(info)
            return
        }
        if let demo = LinkInspector.inspect("https://northlight.films/films/northern-light-making-of") {
            model.presentOptions?(demo)
        }
    }
}

struct FloatingButtonView: View {
    @ObservedObject var model: AppModel
    let onOpen: () -> Void
    let onHide: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                NotchBadge(size: 24)
                Text("Edit.or.lynx")
                    .font(Typo.display(11, .semibold))
                    .foregroundStyle(Pal.text)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Pal.tertiary)
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(Pal.panel.opacity(0.97))
            )
            .overlay(
                Capsule()
                    .strokeBorder(hovering ? Pal.accent.opacity(0.4) : Pal.veil(0.14), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            .scaleEffect(hovering ? 1.03 : 1)
        }
        .frame(width: 140, height: 48)
        .contentShape(Rectangle())
        .onHover { value in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { hovering = value }
        }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button("Grab link from clipboard") { onOpen() }
            Button("Open Edit.or.lynx") {
                model.openNotchMain?()
            }
            Divider()
            Button("Hide Edit.or.lynx Button") { onHide() }
        }
        .help("Edit.or.lynx button — grabs the video link on your clipboard")
    }
}
