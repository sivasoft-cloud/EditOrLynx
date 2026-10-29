import SwiftUI
import AppKit

public struct AboutSettingsView: View {
    @State private var showingCredits = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header card
            SettingsGroup {
                HStack(spacing: 16) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Edit.or.lynx")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("PRO")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.2))
                                )
                                .foregroundColor(.accentColor)
                        }

                        Text("Version 2.0.0 (Build 300)")
                            .font(.system(size: 12))
                            .foregroundColor(NotchyTheme.textSec)

                        Text("Made by edit.or.siva · Instagram @edit.or.siva")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    Spacer()
                }
                .padding(16)
            }

            // Quick Actions
            SettingSectionLabel(title: "Connect & Community")
            SettingsGroup {
                SWButtonRow(
                    title: "Instagram",
                    subtitle: "@edit.or.siva",
                    buttonTitle: "Visit Profile",
                    buttonIcon: "camera.fill"
                ) {
                    if let url = URL(string: "https://instagram.com/edit.or.siva") {
                        NSWorkspace.shared.open(url)
                    }
                }
                SWDivider()
                SWButtonRow(
                    title: "Downloads Folder",
                    subtitle: "Open saved media and downloads",
                    buttonTitle: "Open in Finder",
                    buttonIcon: "folder.fill"
                ) {
                    if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                        NSWorkspace.shared.open(downloads)
                    }
                }
            }

            // Information & Licensing
            SettingSectionLabel(title: "Architecture & Acknowledgements")
            SettingsGroup {
                SWInfoRow(
                    title: "Notch Engine",
                    value: "Continuous G2 Curvature (Notchy Architecture)",
                    icon: "sparkles"
                )
                SWDivider()
                SWInfoRow(
                    title: "Downloader Engine",
                    value: "Lynx / Pounce High-Speed Multi-Connection",
                    icon: "bolt.fill"
                )
                SWDivider()
                SWInfoRow(
                    title: "Bundle Identifier",
                    value: "com.editor.lynx",
                    icon: "app.badge"
                )
                SWDivider()
                SWNoteRow("Built with love using native Swift, SwiftUI, and AppKit. All third-party libraries and assets are acknowledged under their respective open-source licenses.")
            }
        }
    }
}
