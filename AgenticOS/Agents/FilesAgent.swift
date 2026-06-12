// Agents/FilesAgent.swift – AgentOS
// Domain agent for file discovery – content never leaves device

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftData

actor FilesAgent: DomainAgent {

    let domain: AgentDomain = .files
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Files Agent for AgentOS.
        CRITICAL RULE: ONLY reference files that are explicitly listed in the context below.
        NEVER invent, fabricate, or assume the existence of files, filenames, or paths.
        If no files are listed, say so — do NOT suggest example files.
        PRIVACY RULE: File content is never transmitted — only filenames, tags, and local summaries.
        Help the user locate files by semantic description, date range, or tag.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let (fileContext, hasData) = await buildFileData(using: context.modelContext, query: query)

        // ── Guard: no file index → skip LLM ──────────────────────────────────
        guard hasData else {
            return AgentResponse(
                domain: .files,
                content: fileContext,
                confidence: 1.0,
                suggestedActions: [
                    AgentAction(label: "Find Files", systemImage: "magnifyingglass", intent: "FindFilesIntent")
                ],
                provider: .onDevice
            )
        }

        // ── Real files found → use on-device LLM ─────────────────────────────
        let session = LanguageModelSession(instructions: systemInstructions)
        let enrichedPrompt = """
        Query: \(query)
        \(fileContext)

        IMPORTANT: Only reference files listed above. Do NOT invent files.
        """
        let response = try await session.respond(to: enrichedPrompt)
        return AgentResponse(
            domain: .files,
            content: response.content,
            confidence: 0.85,
            suggestedActions: [
                AgentAction(label: "Find Files", systemImage: "magnifyingglass", intent: "FindFilesIntent")
            ],
            provider: .onDevice
        )
    }

    // MARK: - File Search

    func searchFiles(
        query: String,
        dateRange: DateInterval? = nil,
        modelContext: ModelContext
    ) async throws -> [AgentFile] {
        var descriptor = FetchDescriptor<AgentFile>()
        let allFiles = try modelContext.fetch(descriptor)
        var filtered = allFiles.filter { file in
            let nameMatch = file.name.localizedCaseInsensitiveContains(query) ||
                            file.fileExtension.localizedCaseInsensitiveContains(query) ||
                            file.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||
                            file.aiSummary.localizedCaseInsensitiveContains(query)
            return nameMatch
        }
        if let range = dateRange {
            filtered = filtered.filter { range.contains($0.lastModified) }
        }
        return filtered.sorted { $0.lastModified > $1.lastModified }
    }

    /// Generate an on-device AI summary for a file
    func generateSummary(for file: AgentFile) async throws -> String {
        guard let url = file.resolveURL() else { return "File not accessible." }
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        // Only read first 4KB for summary (never send to cloud)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data.prefix(4096), encoding: .utf8) else {
            return "Could not read file content."
        }
        let session = LanguageModelSession(instructions: systemInstructions)
        let response = try await session.respond(to: "Summarise this file content in 2-3 sentences: \(text)")
        return response.content
    }

    // MARK: - Helpers

    /// Returns (context string, hasRealData).
    private func buildFileData(using context: ModelContext?, query: String) async -> (String, Bool) {
        guard let ctx = context else {
            return ("File index is not available (no model context).", false)
        }
        let total = (try? ctx.fetch(FetchDescriptor<AgentFile>()))?.count ?? 0
        if total == 0 {
            return (
                "No files have been indexed yet.\n\n" +
                "Files from your Desktop, Documents and Downloads folders are indexed automatically on launch. " +
                "Tap ↻ in the toolbar to trigger indexing.",
                false
            )
        }
        guard let matches = try? await searchFiles(query: query, modelContext: ctx) else {
            return ("Could not search the file index (\(total) files total).", false)
        }
        if matches.isEmpty {
            return (
                "No files matching \"\(query)\" found in \(total) indexed files.\n" +
                "Try a broader search term or check the Files panel.",
                false
            )
        }
        let lines = matches.prefix(8).map { f in
            "• \(f.displayName) (modified \(f.lastModified.formatted(date: .abbreviated, time: .omitted)))"
            + (f.aiSummary.isEmpty ? "" : "\n  \(f.aiSummary.prefix(100))")
        }.joined(separator: "\n")
        return ("Matching files (\(matches.count) found out of \(total) total):\n\(lines)", true)
    }
}
