import AppKit
import SwiftUI
import PounceCore

/// The in-app Pro view: glassmorphic dark-mode interface for activating and managing Pro status.
struct ProView: View {
    @ObservedObject var model: AppModel
    var onClose: () -> Void

    @State private var key = ""
    @FocusState private var keyFocused: Bool
    @State private var isPasting = false

    init(model: AppModel, onClose: @escaping () -> Void = {}) {
        self.model = model
        self.onClose = onClose
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                heroHeader

                featuresGrid

                if model.plan == .pro {
                    activeLicenseCard
                } else {
                    keyActivationCard
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        model.plan == .pro
                            ? LinearGradient(colors: [Color(hex: 0x1E7A44), Color(hex: 0x115230)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(hex: 0x2A2E39), Color(hex: 0x15181F)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                    .shadow(
                        color: model.plan == .pro
                            ? Color(red: 0.28, green: 0.78, blue: 0.46).opacity(0.35)
                            : Color.white.opacity(0.08),
                        radius: 8
                    )

                Image(systemName: model.plan == .pro ? "checkmark.seal.fill" : "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(model.plan == .pro ? Color(red: 0.28, green: 0.78, blue: 0.46) : Pal.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(model.plan == .pro ? "Edit.or.lynx PRO Unlocked" : "Unlock Edit.or.lynx PRO")
                    .font(Typo.display(19, .bold))
                    .foregroundStyle(Pal.text)

                Text(model.plan == .pro
                     ? "All professional capabilities are active and unlocked on this Mac."
                     : "Supercharge your downloads with 32 parallel streams, unlimited 4K/8K, Turbo Mode & Studio Lossless Audio.")
                    .font(Typo.body(10.5))
                    .foregroundStyle(Pal.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Pal.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Features Grid (2x3)

    private var featuresGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            proFeatureCard(
                symbol: "bolt.fill",
                title: "16x Turbo Bonding",
                subtitle: "Wi-Fi + iPhone tethered link aggregation",
                color: Pal.accent
            )
            proFeatureCard(
                symbol: "network",
                title: "32 Parallel Streams",
                subtitle: "10 simultaneous downloads at full line speed",
                color: Color(red: 0.35, green: 0.65, blue: 1.0)
            )
            proFeatureCard(
                symbol: "4k.tv.fill",
                title: "4K & 8K 60fps Media",
                subtitle: "Pristine cinema-quality asset capture",
                color: Color(red: 0.95, green: 0.65, blue: 0.25)
            )
            proFeatureCard(
                symbol: "waveform",
                title: "Lossless Studio Audio",
                subtitle: "Studio Master 320k & bit-perfect Lossless audio",
                color: Color(red: 0.28, green: 0.78, blue: 0.46)
            )
            proFeatureCard(
                symbol: "puzzlepiece.extension.fill",
                title: "1-Click Browser Intercept",
                subtitle: "Zero browser downloading — takes over into notch",
                color: Color(red: 0.7, green: 0.45, blue: 0.95)
            )
            proFeatureCard(
                symbol: "scissors",
                title: "Pro Video Clip Studio",
                subtitle: "Vertical 9:16 reels, 1:1 square & high-FPS GIFs",
                color: Color(red: 0.95, green: 0.35, blue: 0.55)
            )
        }
    }

    private func proFeatureCard(symbol: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body(10.5, .semibold))
                    .foregroundStyle(Pal.text)
                Text(subtitle)
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Pal.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.7)
        )
    }

    // MARK: - Active License Card

    private var activeLicenseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))

                VStack(alignment: .leading, spacing: 1) {
                    Text("PRO LIFETIME ACTIVE")
                        .font(Typo.body(11, .bold))
                        .foregroundStyle(Pal.text)
                    Text("Offline validation verified • Unlimited Mac lifetime grant")
                        .font(Typo.body(9))
                        .foregroundStyle(Pal.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color(red: 0.28, green: 0.78, blue: 0.46)).frame(width: 5, height: 5)
                    Text("Active")
                        .font(Typo.mono(8.5, .bold))
                        .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.18), in: Capsule())
            }

            Rectangle().fill(Pal.stroke).frame(height: 0.7)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.licenseStatus.summary)
                        .font(Typo.mono(9.5, .medium))
                        .foregroundStyle(Pal.secondary)
                }

                Spacer()

                Button {
                    model.deactivatePro()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                        Text("Deactivate Pro Plan")
                            .font(Typo.body(10, .semibold))
                    }
                    .foregroundStyle(Pal.red.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Pal.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Pal.red.opacity(0.3), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .help("Switch this Mac back to the Free plan")
            }
        }
        .padding(14)
        .background(Pal.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(red: 0.28, green: 0.78, blue: 0.46).opacity(0.35), lineWidth: 0.9)
        )
    }

    // MARK: - Key Activation Card (Free State)

    private var keyActivationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Pal.accent)
                Text("Activate with Pro Key")
                    .font(Typo.body(11, .semibold))
                    .foregroundStyle(Pal.text)
                Spacer()

                Button {
                    openKeyPage()
                } label: {
                    HStack(spacing: 4) {
                        Text("Claim Free Key")
                            .font(Typo.body(9.5, .medium))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 7.5))
                    }
                    .foregroundStyle(Pal.accent)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }

            HStack(spacing: 8) {
                TextField("Enter or paste Pro Key (e.g. ELNK-XXXX-XXXX...)", text: $key)
                    .textFieldStyle(.plain)
                    .font(Typo.mono(12, .medium))
                    .foregroundStyle(Pal.text)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(Pal.recess, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Pal.stroke, lineWidth: 0.8)
                    )
                    .focused($keyFocused)
                    .onSubmit { activate() }

                Button {
                    pasteFromClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text("Paste")
                            .font(Typo.body(10.5, .medium))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(Pal.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                Button {
                    activate()
                } label: {
                    HStack(spacing: 5) {
                        if model.licenseStatus.isActivating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                            Text("Activate")
                                .font(Typo.body(11, .bold))
                        }
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Pal.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Pal.accent.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || model.licenseStatus.isActivating)
            }

            if let message = model.licenseStatus.message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(message)
                        .font(Typo.body(9.5))
                    Spacer()
                }
                .foregroundStyle(Pal.red)
                .padding(8)
                .background(Pal.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Text("Supports official campaign keys, web claimed keys, and offline VIP activation keys.")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }
        }
        .padding(14)
        .background(Pal.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Actions

    private func activate() {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        keyFocused = false
        model.activatePro(trimmed)
    }

    private func pasteFromClipboard() {
        if let str = NSPasteboard.general.string(forType: .string) {
            key = str.trimmingCharacters(in: .whitespacesAndNewlines)
            activate()
        }
    }

    private func openKeyPage() {
        guard let url = URL(string: LicenseConfig.proKeyPageURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Compatibility alias for any existing references
struct ProModalView: View {
    @ObservedObject var model: AppModel
    var onClose: () -> Void = {}

    init(model: AppModel, onClose: @escaping () -> Void = {}) {
        self.model = model
        self.onClose = onClose
    }

    var body: some View {
        ProView(model: model, onClose: onClose)
    }
}
