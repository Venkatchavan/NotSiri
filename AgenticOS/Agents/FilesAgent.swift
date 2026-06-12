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
        You are the Files Agent for AgentOS. You help the user find and understand files.
        CRITICAL PRIVACY RULE: File content is NEVER sent anywhere – only filenames, tags, and AI-generated on-device summaries.
        Help the user locate files by semantic description, date range, or tag.
        When summarising a file, do so in under 3 sentences from its local content.
        Suggest organising related files into projects.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let fileContext = await buildFileContext(using: context.modelContext, query: query)
        let enrichedPrompt = """
        Query: \(query)
        Relevant files found: \(fileContext)
        """
        // Files always on-device (privacy boundary)
        let session = LanguageModelSession(instructions: systemInstructions)
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

    private func buildFileContext(using context: ModelContext?, query: String) async -> String {
        guard let ctx = context,
              let matches = try? await searchFiles(query: query, modelContext: ctx),
              !matches.isEmpty
        else { return "No matching files found." }
        return matches.prefix(5).map { "\($0.displayName) – \($0.aiSummary.isEmpty ? "No summary" : $0.aiSummary)" }
                      .joined(separator: "\n")
    }
}
