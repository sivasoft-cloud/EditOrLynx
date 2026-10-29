import SwiftUI
import PounceCore

struct DownloadRow: View {
    let item: DownloadItem
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject var appModel: AppModel
    @State private var hovering = false
    @State private var hoveredAction: String? = nil
    @State private var justCompleted = false

    init(item: DownloadItem, isSelected: Bool, model: AppModel, onSelect: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.appModel = model
        self.onSelect = onSelect
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                isSelected
                    ? Color.white.opacity(0.12)
                    : (hovering ? Color.white.opacity(0.065) : Color.white.opacity(0.035))
            )
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isSelected
                    ? Color.white.opacity(0.25)
                    : (hovering ? Color.white.opacity(0.12) : Color.white.opacity(0.05)),
                lineWidth: isSelected ? 1.0 : 0.7
            )
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            metadataSection
            Spacer(minLength: 12)
            actionAndStatusSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(rowBackground)
        .overlay(rowBorder)
        .scaleEffect(hovering ? 1.02 : 1.0)
        .contentShape(Rectangle())
        .onHover { value in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                hovering = value
            }
        }
        .onTapGesture(perform: onSelect)
        .contextMenu { contextMenuItems }
        .onChange(of: item.state) { _ in
            if item.state == .completed {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    justCompleted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        justCompleted = false
                    }
                }
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            FilmThumb(
                seed: item.seed,
                kind: item.kind,
                size: 42,
                corner: 9
            )

            // Resolution / Format mini pill badge
            Text(item.formatLabel.isEmpty ? "4K" : item.formatLabel.uppercased())
                .font(Typo.mono(7, .bold))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.black.opacity(0.65), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                .offset(x: 2, y: 3)
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.title)
                    .font(Typo.body(12.5, .semibold))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)

                statusTag
            }

            // File metadata: Format, Resolution, Size, Speed / ETA
            HStack(spacing: 6) {
                if item.formatLabel.uppercased() == "FLAC" || item.formatLabel.uppercased() == "LOSSLESS" {
                    Text("LOSSLESS")
                        .font(Typo.body(7.5, .bold))
                        .foregroundStyle(Pal.onAccent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Pal.systemAccent, in: Capsule())
                }

                if item.qualityLabel != "—" {
                    Text(item.qualityLabel)
                        .font(Typo.mono(10, .medium))
                        .foregroundStyle(Pal.secondary)
                    Text("•")
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                }

                Text(item.sizeText)
                    .font(Typo.mono(10, .medium))
                    .foregroundStyle(Pal.secondary)

                if item.state == .downloading {
                    Text("•")
                        .font(Typo.body(8))
                        .foregroundStyle(Pal.tertiary)
                    if item.currentSpeed > 0 {
                        Text(Fmt.speed(item.currentSpeed) + (item.statusHint.map { " • " + $0 } ?? ""))
                            .font(Typo.mono(10, .semibold))
                            .foregroundStyle(Pal.systemAccent)
                    } else {
                        Text(item.statusHint ?? "Connecting…")
                            .font(Typo.mono(10, .semibold))
                            .foregroundStyle(Pal.systemAccent)
                    }
                }
            }

            // Smooth linear progress bar for active items
            if item.state.isActive {
                let barValue: Double = item.totalBytes > 0 ? max(0.02, min(1.0, item.progress)) : 0.05
                ProgressView(value: barValue)
                    .progressViewStyle(.linear)
                    .tint(item.state == .failed ? Pal.red : Pal.systemAccent)
                    .frame(height: 3)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Status Tag (Animated Scale Pop & Color Crossfade)

    private var statusTag: some View {
        Group {
            if item.state == .completed {
                HStack(spacing: 3.5) {
                    Circle()
                        .fill(Color(red: 0.22, green: 0.76, blue: 0.44))
                        .frame(width: 4.5, height: 4.5)
                    Text("Completed")
                        .font(Typo.body(8.5, .bold))
                }
                .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.46))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.18), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.18, green: 0.65, blue: 0.38).opacity(0.35), lineWidth: 0.6))
            } else if item.state == .downloading {
                HStack(spacing: 3.5) {
                    Circle()
                        .fill(Pal.systemAccent)
                        .frame(width: 4.5, height: 4.5)
                    Text("Downloading")
                        .font(Typo.body(8.5, .bold))
                }
                .foregroundStyle(Pal.systemAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Pal.systemAccent.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(Pal.systemAccent.opacity(0.3), lineWidth: 0.6))
            } else if item.state == .paused {
                Text("Paused")
                    .font(Typo.body(8.5, .bold))
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08), in: Capsule())
            } else if item.state == .failed {
                Text("Failed")
                    .font(Typo.body(8.5, .bold))
                    .foregroundStyle(Pal.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Pal.red.opacity(0.14), in: Capsule())
            } else {
                Text("Queued")
                    .font(Typo.body(8.5, .bold))
                    .foregroundStyle(Pal.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
        }
        .scaleEffect(justCompleted ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: justCompleted)
    }

    // MARK: - Inline SF Symbol Action Icons (Reveal on Hover)

    private var actionAndStatusSection: some View {
        HStack(spacing: 6) {
            // Percent text
            Text(item.state == .completed ? "100%" : (item.percentText ?? "—"))
                .font(Typo.mono(11, .bold))
                .foregroundStyle(item.state == .completed ? Color(red: 0.28, green: 0.78, blue: 0.46) : Pal.secondary)
                .frame(width: 44, alignment: .trailing)

            // Action icons container with hover reveal
            HStack(spacing: 4) {
                if item.state == .completed {
                    rowIconButton(symbol: "folder", help: "Show in Finder") {
                        appModel.revealDestination(for: item)
                    }
                    rowIconButton(symbol: "link", help: "Copy Link") {
                        appModel.copySourceLink(item)
                    }
                    rowIconButton(symbol: "xmark", help: "Remove") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appModel.remove(item)
                        }
                    }
                } else {
                    rowIconButton(
                        symbol: item.state == .downloading ? "pause.fill" : "play.fill",
                        help: item.state == .downloading ? "Pause" : "Resume"
                    ) {
                        appModel.engine.toggle(item.id)
                    }
                    rowIconButton(symbol: "link", help: "Copy Link") {
                        appModel.copySourceLink(item)
                    }
                    rowIconButton(symbol: "xmark", help: "Cancel") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appModel.remove(item)
                        }
                    }
                }
            }
            .opacity(hovering ? 1.0 : 0.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hovering)
        }
    }

    private func rowIconButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredAction == symbol

        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isHovered ? Pal.text : Pal.tertiary)
                .frame(width: 24, height: 24)
                .background(
                    isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.04),
                    in: Circle()
                )
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hoveredAction = $0 ? symbol : nil }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        if item.state == .completed {
            Button("Open File") { appModel.openFile(for: item) }
            Button("Show in Finder") { appModel.revealDestination(for: item) }
            Button("Copy Source Link") { appModel.copySourceLink(item) }
            Divider()
            Button("Remove from List") { appModel.remove(item) }
        } else {
            Button(item.state == .downloading ? "Pause" : "Resume") {
                appModel.engine.toggle(item.id)
            }
            Button("Copy Source Link") { appModel.copySourceLink(item) }
            Button("Show Download Folder") { appModel.revealDestination(for: item) }
            Divider()
            Button("Stop Download") { appModel.remove(item) }
        }
    }
}
