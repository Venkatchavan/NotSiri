// Integrations/MCPBridgeManager.swift – AgentOS
// Model Context Protocol bridge: GitHub, Obsidian, Notion
// OAuth 2.0 PKCE with tokens stored in Keychain

import Foundation
import Observation
import CryptoKit

@Observable
final class MCPBridgeManager {

    static let shared = MCPBridgeManager()

    // MCP endpoints (configurable per user)
    private var endpoints: [MCPService: URL] = [
        .github:   URL(string: "https://api.github.com")!,
        .obsidian: URL(string: "http://localhost:27124")!,  // Obsidian Local REST API
        .notion:   URL(string: "https://api.notion.com/v1")!
    ]

    private init() {}

    // MARK: - Generic MCP Tool Call

    func call(tool: String, arguments: [String: String]) async throws -> String {
        let service = resolveService(for: tool)
        let token   = KeychainHelper.read(key: "agentos.mcp.\(service.rawValue).token") ?? ""
        switch service {
        case .github:   return try await callGitHub(tool: tool, args: arguments, token: token)
        case .obsidian: return try await callObsidian(tool: tool, args: arguments, token: token)
        case .notion:   return try await callNotion(tool: tool, args: arguments, token: token)
        }
    }

    // MARK: - GitHub

    private func callGitHub(tool: String, args: [String: String], token: String) async throws -> String {
        var urlString = ""
        switch tool {
        case "github_list_issues":
            let repo = args["repo"] ?? ""
            let state = args["state"] ?? "open"
            urlString = "https://api.github.com/repos/\(repo)/issues?state=\(state)&per_page=10"
        case "github_list_prs":
            let repo = args["repo"] ?? ""
            let state = args["state"] ?? "open"
            urlString = "https://api.github.com/repos/\(repo)/pulls?state=\(state)&per_page=10"
        default:
            return "Unsupported GitHub tool: \(tool)"
        }
        var req = URLRequest(url: URL(string: urlString)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return "No items." }
        return items.prefix(5)
            .compactMap { $0["title"] as? String }
            .joined(separator: "; ")
    }

    // MARK: - Obsidian (Local REST API plugin)

    private func callObsidian(tool: String, args: [String: String], token: String) async throws -> String {
        switch tool {
        case "obsidian_search":
            let query = args["query"] ?? ""
            var req = URLRequest(url: URL(string: "http://localhost:27124/search/simple/?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return "No results." }
            return results.prefix(5).compactMap { $0["filename"] as? String }.joined(separator: ", ")
        case "obsidian_read_note":
            let path = args["path"] ?? ""
            var req = URLRequest(url: URL(string: "http://localhost:27124/vault/\(path)")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            return String(data: data.prefix(2000), encoding: .utf8) ?? "Could not read note."
        default:
            return "Unsupported Obsidian tool: \(tool)"
        }
    }

    // MARK: - Notion

    private func callNotion(tool: String, args: [String: String], token: String) async throws -> String {
        switch tool {
        case "notion_query_database":
            let dbID = args["database_id"] ?? ""
            var req = URLRequest(url: URL(string: "https://api.notion.com/v1/databases/\(dbID)/query")!)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [:])
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pages  = result["results"] as? [[String: Any]] else { return "No results." }
            return "Found \(pages.count) pages in Notion database."
        default:
            return "Unsupported Notion tool: \(tool)"
        }
    }

    // MARK: - OAuth 2.0 PKCE

    func startOAuth(service: MCPService) -> URL? {
        let verifier  = PKCEHelper.generateVerifier()
        let challenge = PKCEHelper.generateChallenge(from: verifier)
        KeychainHelper.write(key: "agentos.pkce.\(service.rawValue)", value: verifier)
        switch service {
        case .github:
            let clientID = "your_github_client_id"
            return URL(string: "https://github.com/login/oauth/authorize?client_id=\(clientID)&scope=repo,user&code_challenge=\(challenge)&code_challenge_method=S256")
        case .notion:
            return URL(string: "https://api.notion.com/v1/oauth/authorize?client_id=your_notion_client_id&response_type=code&owner=user&code_challenge=\(challenge)")
        case .obsidian:
            return nil  // Obsidian uses local API key, not OAuth
        }
    }

    func handleOAuthCallback(url: URL, service: MCPService) async throws {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else { return }
        let verifier = KeychainHelper.read(key: "agentos.pkce.\(service.rawValue)") ?? ""
        // Exchange code for token (service-specific)
        let token = try await exchangeCodeForToken(code: code, verifier: verifier, service: service)
        KeychainHelper.write(key: "agentos.mcp.\(service.rawValue).token", value: token)
    }

    private func exchangeCodeForToken(code: String, verifier: String, service: MCPService) async throws -> String {
        // Simplified - real implementation would POST to token endpoint
        return "placeholder_token_\(code.prefix(8))"
    }

    // MARK: - Helpers

    private func resolveService(for tool: String) -> MCPService {
        if tool.hasPrefix("github")   { return .github }
        if tool.hasPrefix("obsidian") { return .obsidian }
        if tool.hasPrefix("notion")   { return .notion }
        return .github
    }
}

// MARK: - Supporting Types

enum MCPService: String, CaseIterable, Identifiable {
    case github   = "github"
    case obsidian = "obsidian"
    case notion   = "notion"
    var id: String { rawValue }
    var displayName: String {
        switch self { case .github: "GitHub"; case .obsidian: "Obsidian"; case .notion: "Notion" }
    }
    var systemImage: String {
        switch self { case .github: "chevron.left.forwardslash.chevron.right"; case .obsidian: "diamond.fill"; case .notion: "square.grid.2x2" }
    }
}

// MARK: - PKCE Helper

private enum PKCEHelper {
    static func generateVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func generateChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
