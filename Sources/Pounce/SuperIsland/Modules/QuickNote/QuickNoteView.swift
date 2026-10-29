import SwiftUI
import PounceCore

struct QuickNoteView: View {
    @ObservedObject private var manager = QuickNoteManager.shared
    @EnvironmentObject var appState: AppState
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Header bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Pal.accent)
                    Text("QUICK NOTE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Stats
                HStack(spacing: 6) {
                    Text("\(manager.wordCount) words")
                    Text("•")
                    Text("\(manager.characterCount) chars")
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))

                // Copy button
                Button {
                    manager.copyToClipboard()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Copy")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Copy note to clipboard")

                // Save button
                Button {
                    manager.saveToFile()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 9))
                        Text("Save")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Save note as text file")

                // Clear button
                Button {
                    manager.clearNote()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Clear note")
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // Text editor scratchpad
            ZStack(alignment: .topLeading) {
                if manager.content.isEmpty {
                    Text("Jot down quick ideas, paste links, or draft notes here...")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $manager.content)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(4)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .onAppear {
            isEditorFocused = true
        }
    }
}
