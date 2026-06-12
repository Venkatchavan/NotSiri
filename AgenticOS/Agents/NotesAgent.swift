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
        You are the Notes Agent for AgentOS.
        CRITICAL RULE: ONLY reference notes that are explicitly listed in the context below.
        NEVER invent, fabricate, or assume the existence of notes, their content, or their titles.
        If no notes are listed, say so clearly — do NOT generate example notes.
        Find connections between notes only when multiple notes are actually provided.
        Always attribute the source (Local / Obsidian / Notion) when referencing a note.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let (notesContext, hasData) = await buildNotesData(using: context.modelContext, query: query)

        // ── Guard: no notes → return factual answer, skip LLM ───────────────
        guard hasData else {
            return AgentResponse(
                domain: .notes,
                content: notesContext,
                confidence: 1.0,
                suggestedActions: [
                    AgentAction(label: "New Note", systemImage: "note.text.badge.plus", intent: "QueryIntent")
                ],
                provider: .onDevice
            )
        }

        // ── Real notes found → use LLM ────────────────────────────────────────
        let enrichedPrompt = "Current date: \(context.currentDate.formatted())\n\(notesContext)\n\nIMPORTANT: Only reference notes listed above. Do NOT invent notes.\nQuery: \(query)"
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
                AgentAction(label: "New Note",     systemImage: "note.text.badge.plus", intent: "QueryIntent"),
                AgentAction(label: "Search Notes", systemImage: "magnifyingglass",      intent: "QueryIntent")
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
        let all = try modelContext.fetch(FetchDescriptor<AgentNote>())
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func synthesiseNotes(_ notes: [AgentNote]) async throws -> String {
        guard !notes.isEmpty else { return "No notes to summarise." }
        let notesText = notes.prefix(10)
            .map { "[\($0.source.rawValue)] **\($0.title)**\n\($0.content)" }
            .joined(separator: "\n\n")
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: "Summarise key themes from these notes:\n\n\(notesText)")
        return response.content
    }

    // MARK: - Helpers

    /// Returns (context string, hasRealData). hasRealData = false → skip LLM entirely.
    private func buildNotesData(using modelContext: ModelContext?, query: String) async -> (String, Bool) {
        guard let ctx = modelContext else {
            return ("Notes are not available (no model context).", false)
        }
        guard let matches = try? await searchNotes(query: query, modelContext: ctx),
              !matches.isEmpty
        else {
            let total = (try? ctx.fetch(FetchDescriptor<AgentNote>()))?.count ?? 0
            if total == 0 {
                return (
                    "You have no notes in AgentOS yet.\n\n" +
                    "• Connect Obsidian or Notion via the Privacy & Routing panel (🔒 in toolbar).\n" +
                    "• Or create a note directly from the Notes panel.",
                    false
                )
            }
            return ("No notes matching \"\(query)\" found (\(total) total notes exist).", false)
        }
        let lines = matches.prefix(5).map { n in
            "[\(n.source.rawValue)] \(n.title): \(n.content.prefix(120))…"
        }.joined(separator: "\n\n")
        return ("Relevant notes (\(matches.count) found):\n\n\(lines)", true)
    }

    private func buildNotesContext(using context: ModelContext?, query: String) async -> String {
        guard let ctx = context,
              let matches = try? await searchNotes(query: query, modelContext: ctx),
              !matches.isEmpty
        else { return "No matching notes." }
        return matches.prefix(5).map { "[\($0.source.rawValue)] \($0.title): \($0.content.prefix(100))…" }
                      .joined(separator: "\n")
    }
}
