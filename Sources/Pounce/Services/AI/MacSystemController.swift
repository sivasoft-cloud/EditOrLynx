import Foundation
import AppKit

@MainActor
public final class MacSystemController {
    public static let shared = MacSystemController()

    private init() {}

    // MARK: - Natural Command Execution

    public func executeCommand(_ input: String) async -> (success: Bool, message: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Volume controls
        if text.contains("volume") {
            let digits = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let level = Int(digits), level >= 0 && level <= 100 {
                setVolume(percent: level)
                return (true, "Volume set to \(level)%")
            }
            if text.contains("up") || text.contains("increase") {
                adjustVolume(by: 10)
                return (true, "Volume increased +10%")
            }
            if text.contains("down") || text.contains("decrease") {
                adjustVolume(by: -10)
                return (true, "Volume decreased -10%")
            }
            if text.contains("mute") {
                toggleMute()
                return (true, "Audio muted / unmuted")
            }
        }

        if text == "mute" || text == "unmute" {
            toggleMute()
            return (true, "Audio muted / unmuted")
        }

        // Appearance / Dark Mode
        if text.contains("dark mode") || text.contains("light mode") || text.contains("theme") {
            let isDark = toggleDarkMode()
            return (true, isDark ? "Dark mode enabled 🌙" : "Light mode enabled ☀️")
        }

        // Screen / Lock
        if text.contains("lock") {
            lockScreen()
            return (true, "Mac screen locked 🔒")
        }
        if text.contains("sleep display") || text.contains("sleep screen") {
            sleepDisplay()
            return (true, "Display put to sleep 💤")
        }

        // Media Playback
        if text.contains("play") || text.contains("pause") {
            mediaControl(action: "playpause")
            return (true, "Playback toggled ⏯")
        }
        if text.contains("next") || text.contains("skip") {
            mediaControl(action: "next")
            return (true, "Skipped to next track ⏭")
        }
        if text.contains("previous") || text.contains("back") {
            mediaControl(action: "previous")
            return (true, "Back to previous track ⏮")
        }

        // Apps
        if text.hasPrefix("open ") || text.hasPrefix("launch ") {
            let appName = text.replacingOccurrences(of: "open ", with: "").replacingOccurrences(of: "launch ", with: "").trimmingCharacters(in: .whitespaces)
            let res = openApp(name: appName)
            return (res, res ? "Opened \(appName.capitalized) 🚀" : "Could not find app '\(appName)'")
        }

        // Downloads
        if text.contains("pause all") || text.contains("pause download") {
            AppModel.shared?.pauseAll()
            return (true, "All downloads paused ⏸")
        }
        if text.contains("resume all") || text.contains("resume download") {
            AppModel.shared?.resumeAll()
            return (true, "All downloads resumed ▶️")
        }
        if text.contains("download folder") || text.contains("open downloads") {
            AppModel.shared?.openDestinationInFinder()
            return (true, "Opened Downloads folder in Finder 📁")
        }

        // Screenshot
        if text.contains("screenshot") || text.contains("capture screen") {
            let file = takeScreenshot()
            return (true, "Screenshot saved to \(file) 📸")
        }

        // Empty Trash
        if text.contains("empty trash") {
            emptyTrash()
            return (true, "Trash emptied 🗑")
        }

        // Memory Boost / Purge
        if text.contains("boost") || text.contains("purge") || text.contains("clean ram") || text.contains("free memory") {
            purgeMemory()
            return (true, "Purged inactive memory & boosted macOS 🚀")
        }

        // Battery / Power
        if text.contains("battery") {
            let batt = getBatteryInfo()
            return (true, batt)
        }
        if text.contains("low power") || text.contains("battery saver") {
            enableLowPowerMode()
            return (true, "Low Power Mode enabled ⚡")
        }

        // Fallback: run in shell or invoke universal AI
        if text.hasPrefix("sh ") || text.hasPrefix("exec ") || text.hasPrefix("$ ") {
            let cmd = text.replacingOccurrences(of: "sh ", with: "").replacingOccurrences(of: "exec ", with: "").replacingOccurrences(of: "$ ", with: "")
            let out = runShellCommand(cmd)
            return (true, out.isEmpty ? "Executed command." : out)
        }

        return (false, "Unrecognized command. Try 'volume 50', 'dark mode', 'screenshot', 'open Spotify', 'lock screen'...")
    }

    // MARK: - Native Actions

    public func setVolume(percent: Int) {
        let clamped = max(0, min(100, percent))
        runAppleScript("set volume output volume \(clamped)")
    }

    public func adjustVolume(by delta: Int) {
        let script = "set cur to output volume of (get volume settings)\nset volume output volume (cur + \(delta))"
        runAppleScript(script)
    }

    public func toggleMute() {
        let script = "set cur to output muted of (get volume settings)\nset volume output muted (not cur)"
        runAppleScript(script)
    }

    @discardableResult
    public func toggleDarkMode() -> Bool {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
                return dark mode
            end tell
        end tell
        """
        let res = runAppleScript(script)
        return res.contains("true")
    }

    public func lockScreen() {
        let script = """
        tell application "System Events" to keystroke "q" using {command down, control down}
        """
        runAppleScript(script)
    }

    public func sleepDisplay() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["displaysleepnow"]
        try? p.run()
    }

    public func openApp(name: String) -> Bool {
        let candidates = [
            "/System/Applications/\(name.capitalized).app",
            "/Applications/\(name.capitalized).app",
            "/System/Applications/Utilities/\(name.capitalized).app",
            "/Applications/\(name).app"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                let url = URL(fileURLWithPath: c)
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                return true
            }
        }
        return NSWorkspace.shared.open(URL(string: "\(name):") ?? URL(fileURLWithPath: "/Applications"))
    }

    public func mediaControl(action: String) {
        switch action {
        case "playpause":
            runAppleScript("tell application \"System Events\" to key code 49") // or media key
        case "next":
            NowPlayingManager.shared.nextTrack()
        case "previous":
            NowPlayingManager.shared.previousTrack()
        default:
            break
        }
    }

    public func takeScreenshot() -> String {
        let path = NSHomeDirectory() + "/Desktop/Screenshot-\(Int(Date().timeIntervalSince1970)).png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", path]
        try? p.run()
        p.waitUntilExit()
        return "Desktop"
    }

    public func emptyTrash() {
        let script = "tell application \"Finder\" to empty trash"
        runAppleScript(script)
    }

    public func purgeMemory() {
        _ = runShellCommand("sync && /usr/sbin/purge 2>/dev/null || true")
    }

    public func enableLowPowerMode() {
        _ = runShellCommand("/usr/bin/pmset -a lowpowermode 1 2>/dev/null || true")
    }

    public func getBatteryInfo() -> String {
        let out = runShellCommand("/usr/bin/pmset -g batt")
        if out.contains("AC Power") {
            return "Connected to AC Power 🔌"
        }
        if let range = out.range(of: #"(\d+)%"#, options: .regularExpression) {
            let pct = out[range]
            let isCharging = out.contains("charging")
            return "Battery: \(pct)\(isCharging ? " (Charging ⚡)" : "")"
        }
        return "Battery status normal"
    }

    public func runShellCommand(_ command: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", command]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String {
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            if let err = error {
                return "Error: \(err)"
            }
            return output.stringValue ?? "OK"
        }
        return ""
    }
}
