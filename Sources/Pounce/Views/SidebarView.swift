import SwiftUI
import PounceCore

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @State private var hoveredItem: String? = nil

    private var turboBinding: Binding<Bool> {
        Binding(
            get: { model.engine.settings.turboEnabled },
            set: { model.setTurbo($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Header: App Title & Soft Emerald PRO Badge
            topHeader
                .padding(.top, 42)
                .padding(.bottom, 22)
                .padding(.horizontal, 14)

            // Navigation Menu
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Section 1: TRANSFERS
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TRANSFERS")
                            .font(Typo.body(9, .bold))
                            .tracking(1.0)
                            .foregroundStyle(Pal.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)

                        navRow(category: .home, title: "All Transfers", symbol: "tray.full.fill")
                        navRow(category: .torrents, title: "Torrents & Swarms", symbol: "arrow.down.doc.fill")
                    }

                    // Section 2: MEDIA & FILES
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MEDIA & FILES")
                            .font(Typo.body(9, .bold))
                            .tracking(1.0)
                            .foregroundStyle(Pal.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)

                        navRow(category: .videos, title: "Videos & 4K", symbol: "play.rectangle.fill")
                        navRow(category: .music, title: "Music & FLAC", symbol: "waveform")
                        navRow(category: .clips, title: "Clips", symbol: "scissors")
                        navRow(category: .files, title: "Files", symbol: "folder.fill")
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 20)

            // Bottom Section:
            // 1. Turbo Mode with .toggleStyle(.switch)
            // 2. Pro Lifetime Active informational card
            // 3. Bottom-aligned Settings gear icon
            // (Strictly NO Notch button here)
            VStack(spacing: 10) {
                turboModeSection
                proLifetimeCard
                welcomeIntroButton
                settingsButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 242)
        .background(.thinMaterial)
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack(spacing: 10) {
            PounceMark(size: 28, glow: false)

            Text("Edit.or.lynx")
                .font(Typo.display(15, .bold))
                .foregroundStyle(Pal.text)

            Spacer()

            if model.plan == .pro {
                // Soft Emerald PRO Badge (Active Pro plan tier only)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingSettings = false
                        model.isShowingProView.toggle()
                    }
                } label: {
                    Text("PRO")
                        .font(Typo.mono(9, .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.18), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.35), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .help("Edit.or.lynx Pro Active — Click to view inside app")
            } else {
                // Free Plan Badge with 1-click Pro upgrade
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        model.isShowingSettings = false
                        model.isShowingProView.toggle()
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Text("FREE")
                            .font(Typo.mono(8.5, .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Pal.secondary)
                        Image(systemName: "sparkles")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Pal.accent)
                    }
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.7)
                    )
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .help("Free Plan — Click to unlock Pro inside app")
            }
        }
    }

    // MARK: - Navigation Row

    private func navRow(category: LibraryCategory, title: String, symbol: String) -> some View {
        let isSelected = !model.isShowingSettings && model.category == category
        let isHovered = hoveredItem == category.rawValue
        let count = model.count(for: category)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                model.isShowingSettings = false
                model.isShowingProView = false
                model.category = category
            }
        } label: {
            HStack(spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(Typo.body(12, isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Pal.text : Pal.secondary)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(Typo.mono(9.5, .medium))
                        .foregroundStyle(isSelected ? Pal.text : Pal.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.12) : Pal.recess.opacity(0.6))
                        )
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.1)
                            : (isHovered ? Color.white.opacity(0.05) : Color.clear)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .onHover { hoveredItem = $0 ? category.rawValue : nil }
    }

    // MARK: - Turbo Mode Section (.toggleStyle(.switch))

    private var turboModeSection: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Pal.recess)
                    .frame(width: 26, height: 26)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.engine.settings.turboEnabled ? Pal.systemAccent : Pal.tertiary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Turbo Mode")
                    .font(Typo.body(11, .semibold))
                    .foregroundStyle(Pal.text)
                Text("16x Bonding")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }

            Spacer()

            Toggle("", isOn: turboBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Pro Lifetime Active / Plan Card

    @ViewBuilder
    private var proLifetimeCard: some View {
        let isHovered = hoveredItem == "pro_card"
        let isActive = model.isShowingProView

        if model.plan == .pro {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    model.isShowingSettings = false
                    model.isShowingProView.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("Pro Lifetime Active")
                            .font(Typo.body(10.5, .bold))
                            .foregroundStyle(Pal.text)
                        Text("Unlimited Turbo • 4K & 8K HDR")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.secondary)
                    }

                    Spacer()

                    Button {
                        model.deactivatePro()
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Pal.tertiary)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .noFocusOutline()
                    .help("Deactivate Pro Plan")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    isActive ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isActive
                                ? Color(red: 0.28, green: 0.78, blue: 0.46)
                                : Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.3),
                            lineWidth: 0.8
                        )
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .noFocusOutline()
            .onHover { hoveredItem = $0 ? "pro_card" : nil }
            .help("Edit.or.lynx Pro Lifetime — Click to manage in app")
        } else {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    model.isShowingSettings = false
                    model.isShowingProView.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Pal.accent)

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("Free Plan Active")
                            .font(Typo.body(10.5, .semibold))
                            .foregroundStyle(Pal.text)
                        Text("Tap to activate Pro features")
                            .font(Typo.body(8.5))
                            .foregroundStyle(Pal.tertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Pal.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    isActive ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(.ultraThinMaterial),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isActive ? Pal.accent : Pal.stroke, lineWidth: 0.8)
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .noFocusOutline()
            .onHover { hoveredItem = $0 ? "pro_card" : nil }
            .help("Free Plan — Click to activate Pro inside app")
        }
    }

    // MARK: - Bottom-Aligned Settings Gear Icon

    private var settingsButton: some View {
        let isHovered = hoveredItem == "settings"
        let isActive = model.isShowingSettings

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                model.isShowingProView = false
                model.isShowingSettings.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Label("Settings", systemImage: isActive ? "gearshape.fill" : "gearshape")
                    .font(Typo.body(11.5, .medium))
                    .foregroundStyle(isActive ? Pal.text : (isHovered ? Pal.text : Pal.secondary))

                Spacer()

                if isActive {
                    Circle()
                        .fill(Pal.systemAccent)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .onHover { hoveredItem = $0 ? "settings" : nil }
    }

    // MARK: - Welcome Intro Button (Replay macOS authentic setup)

    private var welcomeIntroButton: some View {
        let isHovered = hoveredItem == "welcome_intro"
        let isActive = model.isShowingWelcomeIntro

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                model.isShowingWelcomeIntro = true
            }
        } label: {
            HStack(spacing: 8) {
                Label("Welcome Intro", systemImage: "sparkles")
                    .font(Typo.body(11.5, .medium))
                    .foregroundStyle(isActive ? Pal.accent : (isHovered ? Pal.text : Pal.secondary))

                Spacer()

                Image(systemName: "hand.wave")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Pal.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Pal.accent.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .onHover { hoveredItem = $0 ? "welcome_intro" : nil }
        .help("Play macOS Authentic Setup Intro & Browser Configuration")
    }
}
