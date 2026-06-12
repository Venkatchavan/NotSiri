// Agents/CoordinatorAgent.swift – AgentOS
// Routes queries to relevant domain agents in parallel and merges responses

import Foundation
import Observation
import FoundationModels
import SwiftData

@Observable
final class CoordinatorAgent {

    static let shared = CoordinatorAgent()

    // Domain agents (actors for thread safety)
    let calendarAgent  = CalendarAgent()
    let mailAgent      = MailAgent()
    let tasksAgent     = TasksAgent()
    let filesAgent     = FilesAgent()
    let notesAgent     = NotesAgent()
    let researchAgent  = ResearchAgent()
    let router         = LanguageModelRouter.shared

    private let classifierInstructions = """
    You are an intent classifier for AgentOS, a personal AI chief of staff.
    Analyse the user's natural language query and classify:
    - domains: which of [calendar, mail, tasks, files, notes, research] are relevant (can be multiple)
    - intent: a snake_case action label, e.g. "schedule_meeting", "find_file", "cross_domain_query"
    - entities: key people, projects, or topics mentioned
    - complexity: "factual" (simple lookup), "synthesis" (cross-domain reasoning), or "realtime" (needs live web data)
    - confidence: your confidence in this classification (0.0 to 1.0)
    """

    // MARK: - Public API

    var conversationHistory: [ConversationTurn] = []

    /// Primary entry point: classify → dispatch in parallel → merge
    func process(query: String, modelContext: ModelContext? = nil) async throws -> CoordinatorResponse {
        // 1. Classify intent
        let classification = try await classifyIntent(query: query)

        // 2. Build context
        let context = AgentContext(
            modelContext: modelContext,
            recentEntities: classification.entities,
            history: conversationHistory
        )

        // 3. Dispatch to relevant agents in parallel
        let domainResponses = try await dispatchParallel(
            query: query,
            domains: parseDomains(classification.domains),
            context: context
        )

        // 4. Merge with confidence weighting
        let merged = try await mergeResponses(
            domainResponses,
            originalQuery: query,
            classification: classification
        )

        // 5. Update conversation history
        conversationHistory.append(ConversationTurn(role: .user, content: query, timestamp: .now))
        conversationHistory.append(ConversationTurn(role: .assistant, content: merged.summary, timestamp: .now))
        // Keep last 20 turns
        if conversationHistory.count > 20 { conversationHistory.removeFirst(2) }

        return merged
    }

    // MARK: - Intent Classification

    private func classifyIntent(query: String) async throws -> IntentClassification {
        try await router.routeOnDeviceStructured(
            prompt: query,
            instructions: classifierInstructions,
            generating: IntentClassification.self
        )
    }

    // MARK: - Parallel Dispatch

    private func dispatchParallel(
        query: String,
        domains: [AgentDomain],
        context: AgentContext
    ) async throws -> [AgentResponse] {
        try await withThrowingTaskGroup(of: AgentResponse?.self) { group in
            for domain in domains {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    return try await self.dispatch(query: query, domain: domain, context: context)
                }
            }
            var results: [AgentResponse] = []
            for try await response in group {
                if let r = response { results.append(r) }
            }
            return results.sorted { $0.confidence > $1.confidence }
        }
    }

    private func dispatch(query: String, domain: AgentDomain, context: AgentContext) async throws -> AgentResponse {
        switch domain {
        case .calendar: return try await calendarAgent.process(query: query, context: context)
        case .mail:     return try await mailAgent.process(query: query, context: context)
        case .tasks:    return try await tasksAgent.process(query: query, context: context)
        case .files:    return try await filesAgent.process(query: query, context: context)
        case .notes:    return try await notesAgent.process(query: query, context: context)
        case .research: return try await researchAgent.process(query: query, context: context)
        }
    }

    // MARK: - Response Merging

    private func mergeResponses(
        _ responses: [AgentResponse],
        originalQuery: String,
        classification: IntentClassification
    ) async throws -> CoordinatorResponse {
        if responses.isEmpty {
            return CoordinatorResponse(
                summary: "I couldn't find relevant information for that query.",
                domainResponses: [],
                intent: classification.intent,
                confidence: 0.1
            )
        }
        if responses.count == 1 {
            return CoordinatorResponse(
                summary: responses[0].content,
                domainResponses: responses,
                intent: classification.intent,
                confidence: responses[0].confidence
            )
        }
        // Multi-domain merge via synthesis
        let responsesText = responses.map { "[\($0.domain.rawValue)] \($0.content)" }.joined(separator: "\n\n")
        let mergeInstructions = """
        You are the coordinator for AgentOS. Multiple domain agents have responded to a query.
        Merge their responses into a single, coherent, non-redundant answer.
        Lead with the most important information. Credit each domain inline when relevant.
        """
        let mergePrompt = """
        Original query: \(originalQuery)

        Domain agent responses:
        \(responsesText)

        Produce a unified response:
        """
        let merged = try await router.routeOnDevice(prompt: mergePrompt, instructions: mergeInstructions)
        let avgConfidence = responses.map(\.confidence).reduce(0, +) / Double(responses.count)
        return CoordinatorResponse(
            summary: merged,
            domainResponses: responses,
            intent: classification.intent,
            confidence: avgConfidence
        )
    }

    // MARK: - Morning Digest

    func morningDigest(modelContext: ModelContext?) async throws -> CoordinatorResponse {
        try await process(
            query: "Give me a morning briefing: today's meetings, top 3 tasks, any urgent emails, and one research insight.",
            modelContext: modelContext
        )
    }

    // MARK: - Helpers

    private func parseDomains(_ strings: [String]) -> [AgentDomain] {
        strings.compactMap { str in
            AgentDomain.allCases.first { $0.rawValue.localizedCaseInsensitiveCompare(str) == .orderedSame }
        }
    }
}

// MARK: - Coordinator Response

struct CoordinatorResponse: Identifiable {
    let id = UUID()
    let summary: String
    let domainResponses: [AgentResponse]
    let intent: String
    let confidence: Double

    var allSuggestedActions: [AgentAction] {
        Array(domainResponses.flatMap(\.suggestedActions).prefix(4))
    }

    var primaryProvider: ProviderTier {
        domainResponses.first?.provider ?? .onDevice
    }
}
