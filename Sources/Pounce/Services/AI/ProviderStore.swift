import Foundation
import Security
import Combine

// MARK: - Keychain

public enum AIKeychain {
    private static let service = "com.editor.lynx.ai.keys"

    public static func get(_ account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    public static func set(_ value: String, for account: String) -> Bool {
        delete(account)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    public static func delete(_ account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - Provider Kind

public enum ProviderKind: String, CaseIterable, Identifiable, Sendable {
    case openrouter
    case openai
    case anthropic
    case gemini
    case groq
    case ollama
    case lmstudio

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .openrouter: return "OpenRouter (Recommended)"
        case .openai: return "OpenAI (GPT-4o / o1)"
        case .anthropic: return "Anthropic (Claude 3.5)"
        case .gemini: return "Google Gemini"
        case .groq: return "Groq (Fast Llama 3)"
        case .ollama: return "Ollama (Local on Mac)"
        case .lmstudio: return "LM Studio (Local on Mac)"
        }
    }

    public var needsKey: Bool {
        ![.ollama, .lmstudio].contains(self)
    }

    public var isLocal: Bool {
        [.ollama, .lmstudio].contains(self)
    }

    public var baseURL: URL? {
        switch self {
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1")
        case .openai: return URL(string: "https://api.openai.com/v1")
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")
        case .groq: return URL(string: "https://api.groq.com/openai/v1")
        case .ollama: return URL(string: "http://127.0.0.1:11434/v1")
        case .lmstudio: return URL(string: "http://127.0.0.1:1234/v1")
        case .anthropic: return nil
        }
    }

    public var keyPage: URL? {
        switch self {
        case .openrouter: return URL(string: "https://openrouter.ai/keys")
        case .openai: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")
        case .groq: return URL(string: "https://console.groq.com/keys")
        case .ollama: return URL(string: "https://ollama.com")
        case .lmstudio: return URL(string: "https://lmstudio.ai")
        }
    }

    public var defaultModel: String {
        switch self {
        case .openrouter: return "openrouter/auto"
        case .openai: return "gpt-4o"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .gemini: return "gemini-1.5-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .ollama: return "llama3"
        case .lmstudio: return "default"
        }
    }

    public var preferredModels: [String] {
        switch self {
        case .openrouter: return ["openrouter/auto", "anthropic/claude-3.5-sonnet", "openai/gpt-4o"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"]
        case .anthropic: return ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"]
        case .gemini: return ["gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash-exp"]
        case .groq: return ["llama-3.3-70b-versatile", "mixtral-8x7b-32768", "llama-3.1-8b-instant"]
        case .ollama: return ["llama3", "mistral", "qwen2.5-coder", "deepseek-r1"]
        case .lmstudio: return ["local-model", "qwen2.5-coder-7b", "llama-3.2-3b"]
        }
    }
}

// MARK: - Reactive AI Service Manager

@MainActor
public final class AIService: ObservableObject {
    public static let shared = AIService()

    @Published public var activeProviderKind: ProviderKind {
        didSet {
            UserDefaults.standard.set(activeProviderKind.rawValue, forKey: "ai.provider.kind")
            reloadActiveKey()
        }
    }

    @Published public var activeModel: String {
        didSet {
            UserDefaults.standard.set(activeModel, forKey: "ai.provider.model")
        }
    }

    @Published public var currentAPIKey: String = ""
    @Published public var isTestingConnection: Bool = false
    @Published public var testStatusMessage: String? = nil
    @Published public var testSucceeded: Bool = false

    public init() {
        let savedKindStr = UserDefaults.standard.string(forKey: "ai.provider.kind") ?? ProviderKind.openrouter.rawValue
        let kind = ProviderKind(rawValue: savedKindStr) ?? .openrouter
        self.activeProviderKind = kind

        let savedModel = UserDefaults.standard.string(forKey: "ai.provider.model") ?? kind.defaultModel
        self.activeModel = savedModel

        reloadActiveKey()
    }

    public func reloadActiveKey() {
        if activeProviderKind.needsKey {
            currentAPIKey = AIKeychain.get(activeProviderKind.rawValue) ?? ""
        } else {
            currentAPIKey = ""
        }
        testStatusMessage = nil
    }

    public func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        currentAPIKey = trimmed
        if trimmed.isEmpty {
            AIKeychain.delete(activeProviderKind.rawValue)
        } else {
            AIKeychain.set(trimmed, for: activeProviderKind.rawValue)
        }
    }

    public func buildProvider() -> ChatProvider {
        let key = activeProviderKind.needsKey ? AIKeychain.get(activeProviderKind.rawValue) : nil

        switch activeProviderKind {
        case .anthropic:
            guard let key, !key.isEmpty else { return NotConnectedProvider() }
            return AnthropicProvider(model: activeModel, apiKey: key)

        case .openai, .openrouter, .gemini, .groq, .ollama, .lmstudio:
            guard let baseURL = activeProviderKind.baseURL else { return NotConnectedProvider() }
            if activeProviderKind.needsKey && (key == nil || key?.isEmpty == true) {
                return NotConnectedProvider()
            }
            return OpenAICompatibleProvider(
                name: activeProviderKind.label,
                model: activeModel,
                baseURL: baseURL,
                apiKey: key
            )
        }
    }

    public func testConnection() async {
        isTestingConnection = true
        testStatusMessage = "Testing connection to \(activeProviderKind.label)…"
        testSucceeded = false

        let provider = buildProvider()
        if !provider.isConnected {
            isTestingConnection = false
            testStatusMessage = "⚠️ No API key found for \(activeProviderKind.label)."
            testSucceeded = false
            return
        }

        do {
            let stream = provider.turn(
                system: "You are an AI assistant. Reply with one word: 'Ready'.",
                messages: [ChatMessage(role: .user, text: "Ping")],
                tools: []
            )

            var reply = ""
            for try await event in stream {
                if case .text(let t) = event {
                    reply += t
                }
            }

            isTestingConnection = false
            testSucceeded = true
            testStatusMessage = "✅ Successfully connected to \(activeProviderKind.label) (\(activeModel))!"
        } catch {
            isTestingConnection = false
            testSucceeded = false
            testStatusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
}
