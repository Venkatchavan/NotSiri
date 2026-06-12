// Agents/ResearchAgent.swift – AgentOS
// Domain agent for web research – routes to Gemini for real-time context

import Foundation
import FoundationModels

actor ResearchAgent: DomainAgent {

    let domain: AgentDomain = .research
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Research Agent for AgentOS. You perform research on behalf of the user.
        For real-time questions (current events, prices, recent papers), use web-aware capabilities.
        Always cite your sources and indicate confidence levels.
        Structure research responses with: Summary → Key Findings → Caveats → Next Steps.
        Distinguish clearly between established facts and your reasoning.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let complexity: QueryComplexity = requiresRealtimeData(query: query) ? .realtime : .synthesis
        let enrichedPrompt = """
        Research request: \(query)
        Context entities: \(context.recentEntities.joined(separator: ", "))
        Date: \(context.currentDate.formatted())
        """
        let response = try await router.route(
            prompt: enrichedPrompt,
            domain: .research,
            complexity: complexity,
            instructions: systemInstructions
        )
        return AgentResponse(
            domain: .research,
            content: response.content,
            confidence: 0.80,
            suggestedActions: [
                AgentAction(label: "Save to Notes", systemImage: "note.text.badge.plus", intent: "QueryIntent"),
                AgentAction(label: "Deep Research", systemImage: "globe.americas", intent: "CrossDomainQueryIntent")
            ],
            provider: response.provider
        )
    }

    // MARK: - GitHub Research via MCP

    func fetchGitHubContext(repo: String, mcpBridge: MCPBridgeManager) async throws -> String {
        let issues = try await mcpBridge.call(tool: "github_list_issues", arguments: ["repo": repo, "state": "open"])
        let prs    = try await mcpBridge.call(tool: "github_list_prs",    arguments: ["repo": repo, "state": "open"])
        return """
        Open Issues (\(repo)): \(issues)
        Open PRs: \(prs)
        """
    }

    // MARK: - Helpers

    private func requiresRealtimeData(query: String) -> Bool {
        let realtimeKeywords = ["today", "current", "latest", "now", "recent", "price", "news", "weather", "live"]
        return realtimeKeywords.contains { query.localizedCaseInsensitiveContains($0) }
    }
}
