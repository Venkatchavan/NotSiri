// AI/LanguageModelRouter.swift – AgentOS
// Per-domain routing: on-device → Claude → Gemini based on complexity + consent

import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Routing Policy

/// Which provider handles a given query tier
enum ProviderTier: String, Codable, CaseIterable {
    case onDevice    = "Apple On-Device"
    case claude      = "Claude (Anthropic)"
    case gemini      = "Gemini (Google)"
}

/// User-configurable routing rule per domain
struct DomainRoutingPolicy: Codable {
    var domain: AgentDomain
    /// Whether ANY cloud routing is permitted for this domain
    var cloudEnabled: Bool
    /// Override provider for synthesis queries (nil = auto)
    var synthesisProvider: ProviderTier?
    /// Override provider for real-time queries (nil = auto)
    var realtimeProvider: ProviderTier?
}

// MARK: - Response envelope

struct LMResponse {
    let content: String
    let provider: ProviderTier
    let latency: TimeInterval
    let domain: AgentDomain
}

// MARK: - Router

@Observable
final class LanguageModelRouter {

    static let shared = LanguageModelRouter()

    // Routing policies keyed by domain – loaded from UserDefaults/Keychain
    private(set) var policies: [AgentDomain: DomainRoutingPolicy] = [:]

    // External provider API keys (stored in Keychain, loaded at init)
    private var claudeAPIKey: String?
    private var geminiAPIKey: String?

    private init() {
        loadPolicies()
        loadAPIKeys()
    }

    // MARK: Public API

    /// Route a prompt to the appropriate provider based on domain policy and query complexity
    func route(
        prompt: String,
        domain: AgentDomain,
        complexity: QueryComplexity,
        instructions: String
    ) async throws -> LMResponse {
        let start = Date()
        let policy = policies[domain] ?? defaultPolicy(for: domain)
        let tier   = resolveTier(complexity: complexity, policy: policy)

        let content: String
        switch tier {
        case .onDevice:
            content = try await routeOnDevice(prompt: prompt, instructions: instructions)
        case .claude:
            content = try await routeClaude(prompt: prompt, instructions: instructions)
        case .gemini:
            content = try await routeGemini(prompt: prompt, instructions: instructions)
        }
        return LMResponse(content: content, provider: tier, latency: -start.timeIntervalSinceNow, domain: domain)
    }

    // MARK: - On-Device (Foundation Models)

    func routeOnDevice(prompt: String, instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    /// On-device structured output generation
    func routeOnDeviceStructured<T: Generable>(
        prompt: String,
        instructions: String,
        generating type: T.Type
    ) async throws -> T {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, generating: type)
        return response.content
    }

    // MARK: - Claude (Anthropic)

    private func routeClaude(prompt: String, instructions: String) async throws -> String {
        guard let key = claudeAPIKey else { throw RouterError.missingAPIKey(.claude) }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": instructions,
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Gemini

    private func routeGemini(prompt: String, instructions: String) async throws -> String {
        guard let key = geminiAPIKey else { throw RouterError.missingAPIKey(.gemini) }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullPrompt = "\(instructions)\n\n\(prompt)"
        let body: [String: Any] = ["contents": [["parts": [["text": fullPrompt]]]]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decoded.candidates.first?.content.parts.first?.text ?? ""
    }

    // MARK: - Policy Resolution

    private func resolveTier(complexity: QueryComplexity, policy: DomainRoutingPolicy) -> ProviderTier {
        guard policy.cloudEnabled else { return .onDevice }
        switch complexity {
        case .factual:    return .onDevice
        case .synthesis:  return policy.synthesisProvider ?? .claude
        case .realtime:   return policy.realtimeProvider  ?? .gemini
        }
    }

    private func defaultPolicy(for domain: AgentDomain) -> DomainRoutingPolicy {
        // Mail and Files are always local – privacy boundary
        let cloudOK = domain != .mail && domain != .files
        return DomainRoutingPolicy(domain: domain, cloudEnabled: cloudOK)
    }

    // MARK: - Persistence

    func updatePolicy(_ policy: DomainRoutingPolicy) {
        policies[policy.domain] = policy
        savePolicies()
    }

    private func loadPolicies() {
        guard let data = UserDefaults.standard.data(forKey: "domainRoutingPolicies"),
              let saved = try? JSONDecoder().decode([AgentDomain: DomainRoutingPolicy].self, from: data)
        else {
            // Set privacy-safe defaults
            policies = Dictionary(uniqueKeysWithValues: AgentDomain.allCases.map {
                ($0, defaultPolicy(for: $0))
            })
            return
        }
        policies = saved
    }

    private func savePolicies() {
        let data = try? JSONEncoder().encode(policies)
        UserDefaults.standard.set(data, forKey: "domainRoutingPolicies")
    }

    private func loadAPIKeys() {
        claudeAPIKey = KeychainHelper.read(key: "agentos.claude.apikey")
        geminiAPIKey = KeychainHelper.read(key: "agentos.gemini.apikey")
    }

    func storeAPIKey(_ key: String, for provider: ProviderTier) {
        switch provider {
        case .claude: KeychainHelper.write(key: "agentos.claude.apikey", value: key); claudeAPIKey = key
        case .gemini: KeychainHelper.write(key: "agentos.gemini.apikey", value: key); geminiAPIKey = key
        case .onDevice: break
        }
    }
}

// MARK: - Supporting Types

enum QueryComplexity {
    case factual    // → on-device
    case synthesis  // → Claude
    case realtime   // → Gemini
}

enum RouterError: Error, LocalizedError {
    case missingAPIKey(ProviderTier)
    case providerUnavailable(ProviderTier)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "No API key configured for \(p.rawValue)"
        case .providerUnavailable(let p): return "\(p.rawValue) is currently unavailable"
        }
    }
}

// MARK: - Decodable Shapes for External APIs

private struct ClaudeResponse: Decodable {
    struct ContentBlock: Decodable { let text: String }
    let content: [ContentBlock]
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Keychain Helper (minimal)

enum KeychainHelper {
    static func write(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
