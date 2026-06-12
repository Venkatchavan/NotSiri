// AI/DomainAgent.swift – AgentOS
// Base protocol + shared types for all six domain agents

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Domain Enumeration

enum AgentDomain: String, Codable, CaseIterable, Identifiable {
    case calendar  = "Calendar"
    case mail      = "Mail"
    case tasks     = "Tasks"
    case files     = "Files"
    case notes     = "Notes"
    case research  = "Research"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .mail:     return "envelope"
        case .tasks:    return "checkmark.circle"
        case .files:    return "folder"
        case .notes:    return "note.text"
        case .research: return "magnifyingglass"
        }
    }

    var accentColorHex: String {
        switch self {
        case .calendar: return "#FF3B30"
        case .mail:     return "#007AFF"
        case .tasks:    return "#34C759"
        case .files:    return "#FF9500"
        case .notes:    return "#FFD60A"
        case .research: return "#BF5AF2"
        }
    }
}

// MARK: - Agent Response

struct AgentResponse: Identifiable, Sendable {
    let id: UUID
    let domain: AgentDomain
    let content: String
    let confidence: Double          // 0.0 – 1.0
    let suggestedActions: [AgentAction]
    let provider: ProviderTier
    let timestamp: Date

    init(
        domain: AgentDomain,
        content: String,
        confidence: Double = 1.0,
        suggestedActions: [AgentAction] = [],
        provider: ProviderTier = .onDevice
    ) {
        self.id               = UUID()
        self.domain           = domain
        self.content          = content
        self.confidence       = confidence
        self.suggestedActions = suggestedActions
        self.provider         = provider
        self.timestamp        = Date()
    }
}

// MARK: - Agent Action (quick-action chips shown below response)

struct AgentAction: Identifiable, Sendable {
    let id: UUID
    let label: String
    let systemImage: String
    let intent: String          // App Intent name to fire

    init(label: String, systemImage: String, intent: String) {
        self.id          = UUID()
        self.label       = label
        self.systemImage = systemImage
        self.intent      = intent
    }
}

// MARK: - Intent Classification (structured output)

#if canImport(FoundationModels)
/// On macOS 26+ the @Generable macro wires this into the LLM's JSON schema system.
@Generable
struct IntentClassification {
    var domains:    [String]
    var intent:     String
    var entities:   [String]
    var complexity: String
    var confidence: Double
}
#else
/// Stub used on pre-macOS 26 SDKs (CI). Conforms to the local Generable protocol.
struct IntentClassification: Generable {
    var domains:    [String] = []
    var intent:     String   = ""
    var entities:   [String] = []
    var complexity: String   = "factual"
    var confidence: Double   = 0.5
    init() {}
    init(domains: [String], intent: String, entities: [String],
         complexity: String, confidence: Double) {
        self.domains    = domains
        self.intent     = intent
        self.entities   = entities
        self.complexity = complexity
        self.confidence = confidence
    }
}
#endif

// MARK: - Domain Agent Protocol

protocol DomainAgent: Actor {
    var domain: AgentDomain { get }
    var router: LanguageModelRouter { get }

    /// System-level instructions that shape this agent's personality
    var systemInstructions: String { get }

    /// Process a natural-language query and return a structured response
    func process(query: String, context: AgentContext) async throws -> AgentResponse
}

// MARK: - Agent Context

/// Passed to every agent so it can inject relevant live data.
/// Marked @unchecked Sendable because ModelContext is @MainActor-bound;
/// callers must ensure they only read modelContext from the main actor.
struct AgentContext: @unchecked Sendable {
    var modelContext: ModelContext?
    var currentDate: Date
    var recentEntities: [String]    // e.g. ["Sarah Johnson", "Berlin project"]
    var conversationHistory: [ConversationTurn]

    init(
        modelContext: ModelContext? = nil,
        currentDate: Date = .now,
        recentEntities: [String] = [],
        history: [ConversationTurn] = []
    ) {
        self.modelContext         = modelContext
        self.currentDate          = currentDate
        self.recentEntities       = recentEntities
        self.conversationHistory  = history
    }
}

struct ConversationTurn: Sendable {
    let role: Role
    let content: String
    let timestamp: Date
    enum Role: String, Sendable { case user, assistant }
}

// MARK: - Default implementations

extension DomainAgent {
    func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: systemInstructions)
    }
}
