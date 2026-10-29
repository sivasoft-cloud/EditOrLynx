import Foundation
import Combine
import SwiftUI
import AppKit

public enum Theme {
    public static let primary = Color.white
    public static let secondary = Color.white.opacity(0.7)
    public static let tertiary = Color.white.opacity(0.4)
    public static let accent = Color(hex: 0x0A84FF)
    public static let glow = [Color.blue, Color.purple, Color.cyan]
    public static let hairline = Color.white.opacity(0.12)
}

public enum Prefs {
    public static let characterSounds = "character.sounds"
    public static let name = "Edit.or.lynx"
    public static let desktopReactions = "desktop.reactions"
    public static let desktopSleep = "desktop.sleep"
    public static let desktopDance = "desktop.dance"

    public static func on(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

public final class AnimationPolicy: ObservableObject {
    public static let shared = AnimationPolicy()
    @Published public var eco = false
}

public enum NotchMode: Equatable {
    case closed
    case expanded
}

@MainActor
public final class NotchController: ObservableObject {
    public static let shared = NotchController()
    @Published public var mode: NotchMode = .closed
    @Published public var expandedSize = CGSize(width: 400, height: 180)
    @Published public var notchSize = CGSize(width: 200, height: 32)
    public var fileDrag = false
    public var onboarding = false

    public func expand(pinned: Bool = false, focus: Bool = false) {
        AppState.shared.open()
    }
    public func peekaboo(hold: TimeInterval = 2.4) {
        AppState.shared.expand()
    }
}

public enum VoicePhase: Equatable {
    case speaking, listening, hearing, standby, thinking, starting, off
}

public struct NowPlayingMeta: Equatable {
    public var playing: Bool = false
    public var title: String = ""
    public var artist: String = ""
    public var app: String? = nil

    public init(playing: Bool = false, title: String = "", artist: String = "", app: String? = nil) {
        self.playing = playing
        self.title = title
        self.artist = artist
        self.app = app
    }
}

@MainActor
public final class Backend: ObservableObject {
    public static let shared = Backend()
    @Published public var connected = true
    @Published public var busy = false
    @Published public var approvals: [String] = []
    @Published public var voicePhase: VoicePhase = .off
    @Published public var lastTool = ""
    @Published public var listening = false
    @Published public var lastTextAt: Date? = nil
    @Published public var lastErrorAt: Date? = nil
    @Published public var lastDoneAt: Date? = nil
    @Published public var micLevel: Double = 0
    @Published public var speechLevel: Double = 0
    @Published public var nowPlaying = NowPlayingMeta()
    @Published public var lastAnswer: String = ""

    public func attachDropped(_ urls: [URL]) {}
    public func stop() {}
    public func send(_ text: String) {}
}

@MainActor
public final class HandsFree: ObservableObject {
    public static let shared = HandsFree()

    public enum Phase: Equatable {
        case listening, hearing, thinking, standby, speaking, starting, off
    }

    @Published public var isOn = false
    @Published public var phase: Phase = .off
    @Published public var transcript: String = ""
    @Published public var speechLevel: Double = 0

    public func toggle() {
        isOn.toggle()
        phase = isOn ? .listening : .off
    }

    public func start() {
        isOn = true
        phase = .listening
    }
}

public struct ProactiveProposal {
    public var title: String = "Plan your day"
    public var actionLabel: String = "Plan"
    public init(title: String = "Plan your day", actionLabel: String = "Plan") {
        self.title = title
        self.actionLabel = actionLabel
    }
}

public final class ProactiveManager {
    public var proposals: [ProactiveProposal] = []
    public func act(_ p: ProactiveProposal) {}
}

public enum HubModuleKind {
    case chat
}

@MainActor
public final class Hub: ObservableObject {
    public static let shared = Hub()
    public var proactive = ProactiveManager()
    public var module: HubModuleKind = .chat
}

public enum ToolHost {
    public static var notch: NotchController? { NotchController.shared }
}

public enum AppLog {
    public static func write(_ msg: String) {
        #if DEBUG
        print("[Companion] \(msg)")
        #endif
    }
}

public enum SpeechText {
    public static func strip(_ text: String) -> String { text }
    public static func clean(_ text: String) -> String { text }
}

public extension String {
    var tool: String { self }
}

public func opennotchDir(_ sub: String) -> String {
    let dir = NSHomeDirectory() + "/Library/Application Support/Edit.or.lynx/\(sub)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}
