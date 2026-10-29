import SwiftUI
import UniformTypeIdentifiers

public struct NotchShelfModule: View {
    @State private var isTargeted: Bool = false
    @State private var droppedItems: [URL] = []

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))

                if droppedItems.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("Drag files, images, or links here to hold or download")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(droppedItems, id: \.self) { item in
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(Color.accentColor)
                                        .font(.system(size: 11))
                                    Text(item.lastPathComponent)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .frame(height: 70)
            .onDrop(of: [.fileURL, .url], isTargeted: $isTargeted) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                droppedItems.append(url)
                            }
                        }
                    }
                }
                return true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
