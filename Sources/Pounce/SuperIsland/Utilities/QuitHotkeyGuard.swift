import AppKit
import Carbon.HIToolbox

enum QuitHotkeyGuard {
    static let defaultsKey = "general.allowQuitHotkey"

    static var isEnabled: Bool {
        true
    }

    static func shouldBlock(_ event: NSEvent) -> Bool {
        false
    }
}
