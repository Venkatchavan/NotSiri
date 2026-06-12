// Agents/NotesAgent.swift – AgentOS
// Domain agent for notes from local store, Obsidian, and Notion

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftData

actor NotesAgent: DomainAgent {

    let domain: AgentDomain = .notes
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Notes Agent for AgentOS. You help the user capture, retrieve, and connect notes.
        You have access to notes from local storage, Obsidian, and Notion vaults.
        Find connections between notes and surface related information when relevant.
        When creating notes, use clear structure with headers.
        Always attribute the source (Local / Obsidian / Notion) when referencing a note.
        Identify notes that relate to the user's current projects and deadlines.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let notesContext = await buildNotesContext(using: context.modelContext, query: query)
        let enrichedPrompt = """
        Current date: \(context.currentDate.formatted())
        Relevant notes: \(notesContext)
        Recent entities: \(context.recentEntities.joined(separator: ", "))
        Query: \(query)
        """
        let response = try await router.route(
            prompt: enrichedPrompt,
            domain: .notes,
            complexity: .synthesis,
            instructions: systemInstructions
        )
        return AgentResponse(
            domain: .notes,
            content: response.content,
            confidence: 0.87,
            suggestedActions: [
                AgentAction(label: "New Note", systemImage: "note.text.badge.plus", intent: "QueryIntent"),
                AgentAction(label: "Search Notes", systemImage: "magnifyingglass", intent: "QueryIntent")
            ],
            provider: response.provider
        )
    }

    // MARK: - Notes Operations

    func createNote(
        title: String,
        content: String,
        tags: [String] = [],
        source: AgentNote.NoteSource = .local,
        modelContext: ModelContext
    ) async -> AgentNote {
        let note = AgentNote(title: title, content: content, source: source, tags: tags)
        modelContext.insert(note)
        return note
    }

    func searchNotes(query: String, modelContext: ModelContext) async throws -> [AgentNote] {
        let descriptor = FetchDescriptor<AgentNote>()
        let all = try modelContext.fetch(descriptor)
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Synthesise a summary across multiple notes using Claude
    func synthesiseNotes(_ notes: [AgentNote]) async throws -> String {
        guard !notes.isEmpty else { return "No notes to summarise." }
        let notesText = notes.prefix(10).map { "[\($0.source.rawValue)] **\($0.title)**\n\($0.content)" }.joined(separator: "\n\n")
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: "Synthesise the key themes and actionable insights from these notes:\n\n\(notesText)")
        return response.content
    }

    // MARK: - Helpers

    private func buildNotesContext(using context: ModelContext?, query: String) async -> String {
        guard let ctx = context,
              let matches = try? await searchNotes(query: query, modelContext: ctx),
              !matches.isEmpty
        else { return "No matching notes." }
        return matches.prefix(5).map { "[\($0.source.rawValue)] \($0.title): \($0.content.prefix(100))…" }
                      .joined(separator: "\n")
    }
}
