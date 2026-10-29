import SwiftUI
import AppKit

public struct NotchAIView: View {
    @ObservedObject private var ai = NotchAISuggestionManager.shared
    @State private var inputText: String = ""
    @FocusState private var isFieldFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Header with AI Status
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: 0x38BDF8))

                Text("NOTCH AI · FULL MAC CONTROL")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if ai.isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }
            }

            // Command Input Field
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))

                TextField("Type command or ask AI (e.g. 'vol 50', 'dark mode', 'screenshot')…", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .focused($isFieldFocused)
                    .onSubmit {
                        ai.executeInput(inputText)
                        inputText = ""
                    }

                Button {
                    ai.executeInput(inputText)
                    inputText = ""
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: 0x0A84FF))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.8))

            // Action Result Notice if present
            if let result = ai.lastActionResult {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color(hex: 0x34D399))
                    Text(result)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: 0x064E3B).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Quick AI Suggestion Pills
            HStack(spacing: 5) {
                ForEach(ai.suggestions) { item in
                    Button {
                        ai.executeSuggestion(item)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: item.icon)
                                .font(.system(size: 8))
                            Text(item.label)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.09), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear {
            ai.refreshSuggestions()
        }
    }
}
