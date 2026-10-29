import AppKit
import Carbon.HIToolbox

/// Clean Notch Window (NSPanel) modeled after Notchy's window architecture.
/// Bypasses default AppKit frame constraints so it stays perfectly aligned with the hardware notch.
final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private static let showInScreenRecordingsDefaultsKey = "general.showInScreenRecordings"

    /// Critical override from Notchy:
    /// Default NSWindow.constrainFrameRect prevents windows from touching or overlapping the menu bar / notch.
    /// Overriding this to return the unmodified frame allows the notch window to sit flush against the physical bezel.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == [.command] && event.keyCode == UInt16(kVK_ANSI_Q) {
                AppDelegate.shared?.forceQuitApp()
                return true
            }
            if modifiers == [.command] && event.keyCode == UInt16(kVK_ANSI_W) {
                AppState.shared.dismiss()
                return true
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    init() {
        let initialCompactSize = ScreenDetector.primaryScreen
            .flatMap(ScreenDetector.compactIslandMetrics(screen:))?
            .size ?? Constants.compactSize

        super.init(
            contentRect: NSRect(
                x: 0, y: 0,
                width: initialCompactSize.width,
                height: initialCompactSize.height
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false
        acceptsMouseMovedEvents = true

        let shouldShowInRecordings = UserDefaults.standard.object(
            forKey: Self.showInScreenRecordingsDefaultsKey
        ) as? Bool ?? true
        setVisibleInScreenRecordings(shouldShowInRecordings)
    }

    func setVisibleInScreenRecordings(_ visible: Bool) {
        sharingType = visible ? .readOnly : .none
    }
}
