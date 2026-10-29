import SwiftUI
import PounceCore

struct GoogleDriveFolderView: View {
    @ObservedObject var model: AppModel
    let folderURL: URL
    let onClose: () -> Void

    @State private var loading = true
    @State private var errorMessage: String? = nil
    @State private var result: GoogleDriveFolderResult? = nil
    @State private var selectedIDs: Set<String> = []
    @State private var isDownloading = false
    @State private var autoZip: Bool = true

    private var totalBytes: Int64 {
        guard let result else { return 0 }
        let selectedFiles = result.files.filter { selectedIDs.contains($0.id) }
        return selectedFiles.reduce(Int64(0)) { $0 + $1.size }
    }

    private var folderName: String {
        let title = result?.title ?? "Google Drive Folder"
        let safe = title.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return safe.isEmpty ? "Google Drive Folder" : safe
    }

    var body: some View {
        PanelChrome {
            VStack(spacing: 0) {
                // Header
                headerView
                Rectangle().fill(Pal.stroke).frame(height: 0.8)

                if loading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let res = result {
                    contentView(res)
                }

                Rectangle().fill(Pal.stroke).frame(height: 0.8)
                footerView
            }
        }
        .task {
            await loadFolder()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill.badge.gearshape")
                .font(.system(size: 26))
                .foregroundStyle(Pal.systemAccent)
                .frame(width: 44, height: 44)
                .background(Pal.systemAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("GOOGLE DRIVE FOLDER")
                        .font(Typo.body(7.5, .bold))
                        .tracking(0.7)
                        .foregroundStyle(Pal.systemAccent)
                    Text("•")
                        .foregroundStyle(Pal.tertiary)
                    Text("16x Turbo Batch")
                        .font(Typo.body(7.5, .medium))
                        .foregroundStyle(Pal.secondary)
                }

                Text(result?.title ?? "Google Drive Folder")
                    .font(Typo.body(13, .semibold))
                    .foregroundStyle(Pal.text)
                    .lineLimit(1)

                Text("\(result?.files.count ?? 0) files • \(Fmt.bytes(Double(result?.totalBytes ?? 0))) total")
                    .font(Typo.body(9.5))
                    .foregroundStyle(Pal.tertiary)
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Pal.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .noFocusOutline()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
                .padding(.bottom, 4)
            Text("Processing Google Drive Folder…")
                .font(Typo.body(11, .semibold))
                .foregroundStyle(Pal.text)
            Text("Indexing folder files and preparing 100-file zip batch packages.")
                .font(Typo.body(9.5))
                .foregroundStyle(Pal.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Error View
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(hex: 0xFBBF24))
            Text("Couldn't List Folder Files")
                .font(Typo.body(12, .semibold))
                .foregroundStyle(Pal.text)
            Text(msg)
                .font(Typo.body(9.5))
                .foregroundStyle(Pal.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button {
                Task { await loadFolder() }
            } label: {
                Text("Try Again")
                    .font(Typo.body(9.5, .semibold))
                    .foregroundStyle(Pal.text)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(Pal.elevated, in: Capsule())
            }
            .buttonStyle(.plain)
            .noFocusOutline()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Content View
    private func contentView(_ res: GoogleDriveFolderResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Destination Notice Banner
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Pal.systemAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-creates folder in Downloads:")
                        .font(Typo.body(8, .bold))
                        .foregroundStyle(Pal.tertiary)
                    Text("~/Downloads/\(folderName)/")
                        .font(Typo.mono(9, .semibold))
                        .foregroundStyle(Pal.text)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Pal.systemAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Pal.systemAccent.opacity(0.2), lineWidth: 0.6)
            )

            // Auto-Zip & 100-File Batch Mode Banner / Control
            Button {
                autoZip.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: autoZip ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(autoZip ? Pal.systemAccent : Pal.tertiary)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Pal.systemAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("Zip Files After Download")
                                .font(Typo.body(9.5, .semibold))
                                .foregroundStyle(Pal.text)
                            Text("100 files/batch chunking")
                                .font(Typo.mono(8, .bold))
                                .foregroundStyle(Pal.systemAccent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Pal.systemAccent.opacity(0.12), in: Capsule())
                        }
                        Text("Overcomes overload by downloading 100 files, auto-zipping, then proceeding to next 100 files.")
                            .font(Typo.body(8))
                            .foregroundStyle(Pal.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(autoZip ? Pal.systemAccent.opacity(0.3) : Pal.stroke, lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .noFocusOutline()

            // Selection Controls
            HStack(spacing: 8) {
                Button {
                    if selectedIDs.count == res.files.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(res.files.map(\.id))
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: selectedIDs.count == res.files.count ? "checkmark.square.fill" : "square")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Pal.systemAccent)
                        Text(selectedIDs.count == res.files.count ? "Deselect All" : "Select All")
                            .font(Typo.body(9.5, .medium))
                            .foregroundStyle(Pal.secondary)
                    }
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                Spacer()

                Text("\(selectedIDs.count) of \(res.files.count) files selected")
                    .font(Typo.body(9))
                    .foregroundStyle(Pal.tertiary)
            }
            .padding(.top, 2)

            // Scrollable File List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(res.files) { file in
                        fileRow(file)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity)
    }

    // MARK: - File Row
    private func fileRow(_ file: GoogleDriveFileItem) -> some View {
        let isSelected = selectedIDs.contains(file.id)
        return Button {
            if isSelected {
                selectedIDs.remove(file.id)
            } else {
                selectedIDs.insert(file.id)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Pal.systemAccent : Pal.tertiary)

                Image(systemName: iconForFilename(file.name))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(colorForFilename(file.name))
                    .frame(width: 18)

                Text(file.name)
                    .font(Typo.body(10, .medium))
                    .foregroundStyle(isSelected ? Pal.text : Pal.secondary)
                    .lineLimit(1)

                Spacer()

                Text(Fmt.bytes(Double(file.size)))
                    .font(Typo.mono(8.5, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.045) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? Pal.stroke : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusOutline()
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.bytes(Double(totalBytes)))
                    .font(Typo.mono(11, .semibold))
                    .foregroundStyle(Pal.text)
                Text("\(selectedIDs.count) files selected • 16x Turbo")
                    .font(Typo.body(8.5))
                    .foregroundStyle(Pal.tertiary)
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(Typo.body(10.5, .medium))
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            .noFocusOutline()

            Button {
                guard let res = result, !selectedIDs.isEmpty else { return }
                isDownloading = true
                model.downloadGoogleDriveFiles(result: res, selectedIDs: selectedIDs, autoZip: autoZip)
                onClose()
            } label: {
                let batchCount = max(1, (selectedIDs.count + 99) / 100)
                let buttonLabel = autoZip
                    ? (batchCount > 1 ? "Download & Zip (\(selectedIDs.count) Files in \(batchCount) Batches)" : "Download & Zip (\(selectedIDs.count) Files)")
                    : "Download All (\(selectedIDs.count) Files)"

                HStack(spacing: 6) {
                    Image(systemName: autoZip ? "archivebox.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(buttonLabel)
                        .font(Typo.body(11, .semibold))
                }
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 18)
                .frame(height: 32)
                .background(Pal.systemAccent, in: Capsule())
            }
            .buttonStyle(.plain)
            .noFocusOutline()
            .disabled(selectedIDs.isEmpty)
            .opacity(selectedIDs.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers
    private func loadFolder() async {
        loading = true
        errorMessage = nil
        do {
            let res = try await GoogleDriveService.shared.resolveFolder(url: folderURL)
            self.result = res
            self.selectedIDs = Set(res.files.map(\.id))
            self.loading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.loading = false
        }
    }

    private func iconForFilename(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "webm", "m4v": return "film"
        case "mp3", "flac", "wav", "aac", "m4a", "ogg": return "waveform"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "pkg", "iso": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "svg": return "photo"
        case "pdf": return "doc.richtext.fill"
        case "txt", "md", "json", "xml", "csv": return "doc.plaintext.fill"
        default: return "doc.fill"
        }
    }

    private func colorForFilename(_ name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "mkv", "avi", "webm": return Color(hex: 0x60A5FA)
        case "mp3", "flac", "wav", "aac": return Color(hex: 0x34D399)
        case "zip", "rar", "7z", "tar", "gz", "dmg": return Color(hex: 0xFBBF24)
        case "pdf": return Color(hex: 0xF87171)
        default: return Pal.secondary
        }
    }
}
