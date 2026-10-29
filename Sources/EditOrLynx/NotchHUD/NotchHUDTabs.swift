import SwiftUI

public enum NotchHUDTab: String, CaseIterable, Identifiable {
    case downloads
    case media
    case shelf
    case battery

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .downloads: return "arrow.down.circle.fill"
        case .media:     return "music.note"
        case .shelf:     return "tray.full.fill"
        case .battery:   return "battery.100"
        }
    }

    public var title: String {
        switch self {
        case .downloads: return "Downloads"
        case .media:     return "Now Playing"
        case .shelf:     return "Drop Shelf"
        case .battery:   return "Battery"
        }
    }
}
