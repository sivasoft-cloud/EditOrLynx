import SwiftUI
import AppKit

struct DownloaderSettingsView: View {
    @ObservedObject private var model: AppModel
    @State private var autoDelete: Bool = false

    init(model: AppModel? = nil) {
        self._model = ObservedObject(wrappedValue: model ?? AppModel.shared ?? AppModel())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Transfer Engine
            SettingsGroup(title: "Transfer Engine") {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connections per download")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchyTheme.textPrimary)
                            Text(model.plan == .pro ? "Split each file across parallel HTTP connections." : "Free allows up to \(model.entitlements.maxConnections) — Pro unlocks 32.")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchyTheme.textSecondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(model.engine.settings.connections)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NotchyTheme.accent)
                                .frame(width: 24, alignment: .trailing)
                            Stepper("", value: Binding(
                                get: { model.engine.settings.connections },
                                set: { model.setConnections($0) }
                            ), in: 1...model.entitlements.maxConnections)
                            .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    SWDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simultaneous downloads")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchyTheme.textPrimary)
                            Text(model.plan == .pro ? "How many transfers can run concurrently." : "Free runs up to \(model.entitlements.maxConcurrent) at once — Pro unlocks 10.")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchyTheme.textSecondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(model.engine.settings.maxConcurrent)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NotchyTheme.accent)
                                .frame(width: 24, alignment: .trailing)
                            Stepper("", value: Binding(
                                get: { model.engine.settings.maxConcurrent },
                                set: { model.setMaxConcurrent($0) }
                            ), in: 1...model.entitlements.maxConcurrent)
                            .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    SWDivider()

                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Save downloads to")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchyTheme.textPrimary)
                            Text(model.engine.settings.destinationFolder.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(NotchyTheme.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button("Choose…") {
                                model.chooseDestination()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Open Folder") {
                                model.openDestinationInFinder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    SWDivider()

                    SWToggleRow(
                        title: "Auto-delete finished tasks",
                        subtitle: "Automatically clears completed downloads from the list after 7 days.",
                        isOn: Binding(
                            get: { model.engine.settings.autoDelete },
                            set: { model.setAutoDelete($0) }
                        )
                    )
                }
            }

            // Audio & Media Pipeline
            SettingsGroup(title: "Lossless Audio & Metadata Pipeline") {
                VStack(spacing: 0) {
                    SWToggleRow(
                        title: "Embed ID3 / Lossless Metadata & HD Artwork",
                        subtitle: "Injects high-resolution cover art, artist, and track metadata into media files.",
                        isOn: .constant(true)
                    )
                    SWDivider()
                    SWToggleRow(
                        title: "Prioritize Studio Master 320k / Lossless",
                        subtitle: "Queries Apple Music, Spotify, and Indian music services for the highest-bitrate source.",
                        isOn: .constant(true)
                    )
                }
            }

            // Cloud & Torrent Services
            SettingsGroup(title: "Cloud & Torrent Integration") {
                VStack(spacing: 0) {
                    SWToggleRow(
                        title: "Auto-Zip Google Drive batch folders",
                        subtitle: "Streams large Google Drive directories (up to 100 files) directly into a consolidated ZIP archive.",
                        isOn: .constant(true)
                    )
                    SWDivider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Torrent / BitTorrent Engine")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NotchyTheme.textPrimary)
                            Text("aria2c daemon with DHT, peer exchange, and encryption enabled.")
                                .font(.system(size: 11))
                                .foregroundStyle(NotchyTheme.textSecondary)
                        }
                        Spacer()
                        Button("Open Torrent…") {
                            model.openTorrentPicker()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
