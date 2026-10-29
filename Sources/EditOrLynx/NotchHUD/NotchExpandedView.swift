import SwiftUI

public struct NotchExpandedView: View {
    @EnvironmentObject var controller: NotchWindowController
    @EnvironmentObject var engine: DownloadEngine

    public var body: some View {
        VStack(spacing: 0) {
            // Header with tab selector and dismiss button
            HStack(spacing: 6) {
                ForEach(NotchHUDTab.allCases) { tab in
                    let isSel = controller.selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            controller.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(.system(size: 10, weight: isSel ? .semibold : .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSel ? Color.white.opacity(0.14) : Color.clear, in: Capsule())
                        .foregroundStyle(isSel ? .white : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    controller.collapse()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.08))

            // Body
            switch controller.selectedTab {
            case .downloads:
                NotchDownloadsModule()
            case .media:
                NotchMediaModule()
            case .shelf:
                NotchShelfModule()
            case .battery:
                NotchBatteryModule()
            }
        }
        .frame(width: 460, height: 160)
    }
}
