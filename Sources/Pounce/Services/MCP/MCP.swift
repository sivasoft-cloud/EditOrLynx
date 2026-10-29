import Foundation
import Combine
import AppKit

// MARK: - Tool Outcomes

public struct ToolOutcome: Sendable {
    public let ok: Bool
    public let text: String
    public let images: [String]

    public init(ok: Bool, text: String, images: [String] = []) {
        self.ok = ok
        self.text = text
        self.images = images
    }

    public static func fail(_ message: String) -> ToolOutcome {
        ToolOutcome(ok: false, text: message)
    }

    public static func success(_ message: String) -> ToolOutcome {
        ToolOutcome(ok: true, text: message)
    }
}

// MARK: - MCP Server

public final class MCPServer: @unchecked Sendable {
    public let name: String
    public let endpoint: Result<MCPEndpoint, ProviderError>
    public let autoApprove: Set<String>
    private var transport: MCPTransport?

    public init(name: String, config: [String: Any]) {
        self.name = name
        self.endpoint = MCPEndpoint.parse(config)
        self.autoApprove = Set(config["autoApprove"] as? [String] ?? [])
    }

    public struct ToolInfo: Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let description: String
        public let schema: String
    }

    public func start() async throws -> [ToolInfo] {
        let t: MCPTransport
        switch endpoint {
        case .failure(let e): throw e
        case .success(.stdio(let command, let args, let env)):
            t = StdioTransport(name: name, command: command, args: args, env: env)
        case .success(.http(let url, let headers)):
            t = HTTPTransport(name: name, url: url, headers: headers)
        }
        transport = t
        try await t.open()

        var tools: [ToolInfo] = []
        let r = try await t.request("tools/list", [:], timeout: 30)
        for tool in r["tools"] as? [[String: Any]] ?? [] {
            guard let n = tool["name"] as? String else { continue }
            let schema = tool["inputSchema"].flatMap { String(data: HTTP.json($0), encoding: .utf8) } ?? "{}"
            tools.append(ToolInfo(name: n, description: tool["description"] as? String ?? "", schema: schema))
        }
        return tools
    }

    public func call(_ tool: String, argumentsJSON: String) async -> ToolOutcome {
        guard let transport else { return .fail("\(name): Not connected") }
        do {
            let r = try await transport.request("tools/call", ["name": tool, "arguments": HTTP.parse(argumentsJSON) ?? [:]], timeout: 120)
            var text: [String] = []
            for c in r["content"] as? [[String: Any]] ?? [] {
                if let t = c["text"] as? String {
                    text.append(t)
                }
            }
            return ToolOutcome(ok: r["isError"] as? Bool != true, text: text.joined(separator: "\n"))
        } catch {
            return .fail("\(name): \(error.localizedDescription)")
        }
    }

    public func stop() {
        transport?.close()
        transport = nil
    }
}

// MARK: - MCP Registry & Config Manager

@MainActor
public final class MCPRegistry: ObservableObject {
    public static let shared = MCPRegistry()

    @Published public var serverConfigs: [String: [String: Any]] = [:]
    @Published public var availableTools: [MCPServer.ToolInfo] = []
    @Published public var activeServers: [String: MCPServer] = [:]
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "MCP Ready"

    public static var configDir: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let dir = home.appendingPathComponent("Library/Application Support/Edit.or.lynx")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var configFileURL: URL {
        configDir.appendingPathComponent("mcp.json")
    }

    public init() {
        ensureTemplateConfig()
        reload()
    }

    public func ensureTemplateConfig() {
        let file = Self.configFileURL
        guard !FileManager.default.fileExists(atPath: file.path) else { return }

        let template: [String: Any] = [
            "mcpServers": [
                "fetch": [
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-everything"],
                    "autoApprove": ["echo"]
                ]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: template, options: [.prettyPrinted]) {
            try? data.write(to: file)
        }
    }

    public func openConfigFile() {
        ensureTemplateConfig()
        NSWorkspace.shared.open(Self.configFileURL)
    }

    public func openConfigFolder() {
        ensureTemplateConfig()
        NSWorkspace.shared.selectFile(Self.configFileURL.path, inFileViewerRootedAtPath: Self.configDir.path)
    }

    public func reload() {
        isLoading = true
        statusMessage = "Loading mcp.json…"

        // Stop old servers
        for server in activeServers.values {
            server.stop()
        }
        activeServers.removeAll()
        availableTools.removeAll()

        let file = Self.configFileURL
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: [String: Any]] else {
            isLoading = false
            statusMessage = "No servers configured in mcp.json"
            return
        }

        self.serverConfigs = servers

        Task {
            var loadedTools: [MCPServer.ToolInfo] = []
            for (name, config) in servers {
                let s = MCPServer(name: name, config: config)
                self.activeServers[name] = s
                do {
                    let tools = try await s.start()
                    loadedTools.append(contentsOf: tools)
                } catch {
                    print("[MCP] Could not connect to \(name): \(error)")
                }
            }

            self.availableTools = loadedTools
            self.isLoading = false
            self.statusMessage = "Connected \(self.activeServers.count) servers, \(loadedTools.count) tools"
        }
    }
}
