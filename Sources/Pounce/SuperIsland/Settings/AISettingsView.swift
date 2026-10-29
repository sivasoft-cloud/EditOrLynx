import SwiftUI
import AppKit

public struct AISettingsView: View {
    @ObservedObject private var ai = AIService.shared
    @State private var apiKeyInput: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingSectionLabel(title: "AI Model Provider")
            SettingsGroup {
                SWMenuRow(
                    title: "Active Provider",
                    subtitle: "Engine used for Notch AI Assistant and smart link classification",
                    selection: Binding(
                        get: { ai.activeProviderKind },
                        set: { ai.activeProviderKind = $0 }
                    ),
                    options: ProviderKind.allCases.map { ($0, $0.label) }
                )
                SWDivider()
                SWInfoRow(
                    title: "Current Model",
                    value: ai.activeModel,
                    icon: "brain.head.profile"
                )
            }

            if ai.activeProviderKind.needsKey {
                SettingSectionLabel(title: "Authentication")
                SettingsGroup {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(ai.activeProviderKind.label) API Key")
                                .font(.system(size: 13))
                            Text(!ai.currentAPIKey.isEmpty ? "Key is securely stored in Keychain" : "Enter API key to activate AI features")
                                .font(.system(size: 11))
                                .foregroundColor(NotchyTheme.textSec)
                        }
                        Spacer(minLength: 12)
                        SecureField("Paste API key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                        Button("Save") {
                            if !apiKeyInput.isEmpty {
                                ai.saveAPIKey(apiKeyInput)
                                apiKeyInput = ""
                            }
                        }
                        .disabled(apiKeyInput.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if !ai.currentAPIKey.isEmpty {
                        SWDivider()
                        SWButtonRow(
                            title: "Remove Saved Key",
                            subtitle: "Clear this provider's key from macOS Keychain",
                            buttonTitle: "Clear Key",
                            buttonIcon: "trash",
                            isDestructive: true
                        ) {
                            ai.saveAPIKey("")
                        }
                    }
                }
            }

            SettingSectionLabel(title: "System Integration")
            SettingsGroup {
                SWInfoRow(
                    title: "Local Ollama / LMStudio",
                    value: "Offline & private models supported without API key",
                    icon: "lock.shield"
                )
                SWDivider()
                SWInfoRow(
                    title: "Notch Quick Chat",
                    value: "Accessible via expanded island AI tab",
                    icon: "message.fill"
                )
            }
        }
    }
}
