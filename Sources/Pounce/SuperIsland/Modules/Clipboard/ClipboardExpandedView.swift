import SwiftUI
import AppKit
import PounceCore

struct ClipboardExpandedView: View {
    @ObservedObject var appState = AppState.shared
    @State private var copiedID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: 0x0A84FF))
                    Text("Clipboard & Links")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                if let model = AppModel.shared, !model.clipboard.isEmpty {
                    Text("\(model.clipboard.count) items")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Button {
                        model.clearClipboard()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Detected Link Offer Card
            if let model = AppModel.shared, let link = model.detectedLink {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: 0x0A84FF).opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: 0x0A84FF))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title.isEmpty ? link.host : link.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(link.host) · Ready to download")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Button {
                            model.presentOptions?(link)
                        } label: {
                            Text("Options")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.quickDownload(link)
                        } label: {
                            Text("Download")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: 0x0A84FF), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0x0A84FF).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(hex: 0x0A84FF).opacity(0.35), lineWidth: 0.8)
                )
            }

            // Clipboard Entries List
            if let model = AppModel.shared, !model.clipboard.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(model.clipboard.prefix(12)) { entry in
                            clipboardRow(entry, model: model)
                        }
                    }
                }
                .frame(maxHeight: 180)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Clipboard history is empty")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func clipboardRow(_ entry: ClipboardEntry, model: AppModel) -> some View {
        let isCopied = copiedID == entry.id
        let isURL = entry.text.hasPrefix("http://") || entry.text.hasPrefix("https://")

        return HStack(spacing: 8) {
            Image(systemName: entry.pinned ? "pin.fill" : (isURL ? "link" : "doc.text"))
                .font(.system(size: 11))
                .foregroundColor(entry.pinned ? Color(hex: 0xF59E0B) : (isURL ? Color(hex: 0x0A84FF) : .white.opacity(0.5)))
                .frame(width: 14)

            Text(entry.text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            HStack(spacing: 4) {
                if isURL {
                    Button {
                        model.beginLink(entry.text)
                    } label: {
                        Text("Download")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(hex: 0x0A84FF))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: 0x0A84FF).opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    model.copyEntry(entry)
                    copiedID = entry.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedID == entry.id { copiedID = nil }
                    }
                } label: {
                    Text(isCopied ? "Copied" : "Copy")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(isCopied ? .green : .white.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    model.togglePin(entry)
                } label: {
                    Image(systemName: entry.pinned ? "pin.slash.fill" : "pin")
                        .font(.system(size: 9.5))
                        .foregroundColor(entry.pinned ? Color(hex: 0xF59E0B) : .white.opacity(0.45))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)

                Button {
                    model.removeClipboard(entry)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            model.copyEntry(entry)
            copiedID = entry.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedID == entry.id { copiedID = nil }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(entry.pinned ? 0.07 : 0.03))
        )
    }
}
