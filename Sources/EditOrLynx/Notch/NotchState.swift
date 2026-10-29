import AppKit
import Combine
import Foundation

import SwiftUI

public enum NotchMode: String, CaseIterable, Identifiable, Equatable {
    case compact = "Compact"
    case hud = "HUD"
    case music = "Music"
    case offer = "Offer"
    case shelf = "Shelf"
    case clipboard = "Clipboard"
    case notes = "Notes"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .compact: return "capsule"
        case .hud: return "arrow.down.circle"
        case .music: return "music.note"
        case .offer: return "sparkles"
        case .shelf: return "square.and.arrow.down.on.square"
        case .clipboard: return "doc.on.clipboard"
        case .notes: return "note.text"
        }
    }
}

@MainActor
public final class NotchState: ObservableObject {
    public static let shared = NotchState()

    @Published public var mode: NotchMode = .compact
    @Published public var isHovered: Bool = false
    @Published public var isLockedExpanded: Bool = false
    
    // 1-Click Offer
    @Published public var detectedOffer: LinkInfo? = nil
    @Published public var selectedQuality: QualityOption? = nil
    @Published public var audioOnlyOffer: Bool = false
    @Published public var offerAutoDelete: Bool = false
    @Published public var offerAddedNotice: Bool = false
    @Published public var offerDismissTimer: Timer? = nil

    // Now Playing Music
    @Published public var nowPlayingTitle: String = "Waiting for Track..."
    @Published public var nowPlayingArtist: String = "Apple Music / Spotify"
    @Published public var isPlayingMusic: Bool = false
    @Published public var playbackProgress: Double = 0.35
    @Published public var spectrumHeights: [CGFloat] = [0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7, 0.5]

    // Quick Notes
    @Published public var quickNotes: String = "" {
        didSet {
            UserDefaults.standard.set(quickNotes, forKey: "pounce_notch_quick_notes")
        }
    }

    // Dynamic Island Dimensions & Customization (Exact 100% Lynx Match)
    @Published public var compactWidth: CGFloat = 214
    @Published public var compactHeight: CGFloat = 34
    @Published public var expandedWidth: CGFloat = 370
    @Published public var expandedHeight: CGFloat = 175
    @Published public var cornerRadius: CGFloat = 24
    @Published public var topInset: CGFloat = 0

    private var spectrumTimer: Timer?

    private init() {
        self.quickNotes = UserDefaults.standard.string(forKey: "pounce_notch_quick_notes") ?? ""
        startSpectrumAnimation()
    }

    public var isExpanded: Bool {
        isHovered || isLockedExpanded || mode != .compact
    }

    public func presentOffer(_ info: LinkInfo) {
        self.detectedOffer = info
        self.selectedQuality = info.qualities.first(where: { $0.recommended }) ?? info.qualities.first
        self.audioOnlyOffer = (info.kind == .audio)
        self.mode = .offer
        self.isLockedExpanded = true

        offerDismissTimer?.invalidate()
        offerDismissTimer = Timer.scheduledTimer(withTimeInterval: 18.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if self?.mode == .offer {
                    self?.dismissOffer()
                }
            }
        }
    }

    public func dismissOffer() {
        offerDismissTimer?.invalidate()
        offerDismissTimer = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.detectedOffer = nil
            self.mode = .compact
            self.isLockedExpanded = false
        }
    }

    public func toggleExpand() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if isExpanded {
                mode = .compact
                isLockedExpanded = false
            } else {
                mode = .hud
                isLockedExpanded = true
            }
        }
    }

    public func selectMode(_ newMode: NotchMode) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.mode = newMode
            self.isLockedExpanded = (newMode != .compact)
        }
    }

    private func startSpectrumAnimation() {
        spectrumTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isPlayingMusic {
                    self.spectrumHeights = (0..<8).map { _ in
                        CGFloat.random(in: 0.25...1.0)
                    }
                } else {
                    self.spectrumHeights = [0.2, 0.3, 0.4, 0.3, 0.5, 0.3, 0.2, 0.2]
                }
            }
        }
    }
}
