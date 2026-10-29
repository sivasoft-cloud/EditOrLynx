import AppKit
import SwiftUI

/// Interactive Jelly Blob (Puff) living inside the notch.
/// Draws procedurally using `PuffCanvas` with real-time spring physics,
/// eye gaze tracking, and poke/pet reactions.
/// Pauses when idle to maintain 0% CPU footprint.
struct PuffNotchView: View {
    var size: CGFloat = 24
    var mood: AvatarMood = .idle

    @StateObject private var brain = CharacterBrain()
    @AppStorage("avatarPalette") private var paletteId: String = "aurora"
    @AppStorage("puff.look") private var puffLookRaw: String = "blob/sprout/jelly"
    @State private var localGaze: CGPoint = .zero
    @State private var isHovering: Bool = false
    @State private var lastInteraction: Date = Date()

    private var isAnimationPaused: Bool {
        !isHovering && Date().timeIntervalSince(lastInteraction) > 2.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isAnimationPaused)) { (context: TimelineViewDefaultContext) in
            let date = context.date
            let t = date.timeIntervalSinceReferenceDate
            let palette = AvatarPalette.named(paletteId)

            let phys = PuffPhysics(
                squash: brain.squash,
                hop: brain.hop,
                sway: brain.sway,
                eyeBoost: brain.eyeBoost,
                expression: brain.current,
                hearts: brain.hearts.map { (date.timeIntervalSince($0.born), $0.x) }
            )

            PuffCanvas(
                size: size,
                mood: mood,
                palette: palette,
                t: t,
                gaze: localGaze,
                phys: phys
            )
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                lastInteraction = Date()
                brain.hover(hovering)
            }
            .onTapGesture {
                lastInteraction = Date()
                brain.poke()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        lastInteraction = Date()
                        let nx = (value.location.x / size - 0.5) * 2.0
                        let ny = (value.location.y / size - 0.5) * 2.0
                        localGaze = CGPoint(x: min(max(nx, -1), 1), y: min(max(ny, -1), 1))
                        brain.pet(x: value.location.x)
                    }
                    .onEnded { _ in
                        localGaze = .zero
                        lastInteraction = Date()
                    }
            )
            .onChange(of: date) { newDate in
                brain.step(newDate, doneAt: nil, dragging: false)
            }
        }
    }
}
