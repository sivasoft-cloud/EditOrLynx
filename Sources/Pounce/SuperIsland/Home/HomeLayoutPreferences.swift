import SwiftUI

enum HomePanel: String, CaseIterable, Identifiable {
    case none
    case nowPlaying
    case downloads
    case clipboard
    case quickNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Empty"
        case .nowPlaying: return "Now Playing"
        case .downloads: return "Downloads"
        case .clipboard: return "Clipboard"
        case .quickNote: return "Quick Note"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "minus.circle"
        case .nowPlaying: return "music.note"
        case .downloads: return "arrow.down.circle.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .quickNote: return "square.and.pencil"
        }
    }

    var module: ModuleType? {
        switch self {
        case .none: return nil
        case .nowPlaying: return .nowPlaying
        case .downloads: return .downloads
        case .clipboard: return .clipboard
        case .quickNote: return .quickNote
        }
    }
}

enum AnimationLevel: String, CaseIterable, Identifiable {
    case full
    case subtle
    case reduced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "Full"
        case .subtle: return "Subtle"
        case .reduced: return "Reduced"
        }
    }

    var bounceLimit: Double {
        switch self {
        case .full: return 0.5
        case .subtle: return 0.08
        case .reduced: return 0
        }
    }
}
