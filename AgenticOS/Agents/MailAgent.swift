
// Agents/MailAgent.swift – AgentOS
// Domain agent for email – ALWAYS on-device, body content never leaves device

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

actor MailAgent: DomainAgent {

    let domain: AgentDomain = .mail
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Mail Agent for AgentOS. You help the user manage their email.
        CRITICAL PRIVACY RULE: Email body content is NEVER sent to any cloud service.
        You only receive subject lines and sender names for analysis.
        Draft emails professionally but concisely.
        Identify threads needing reply that are older than 48 hours.
        Summarise email intent from subject lines alone when body is not available.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        // Mail always routes on-device (privacy boundary enforced)
        let emailContext = buildEmailContext(from: context.modelContext)
        let session = LanguageModelSession(instructions: systemInstructions)
        let enrichedPrompt = """
        Current date: \(context.currentDate.formatted())
        \(emailContext)
        User query: \(query)
        IMPORTANT: Only reference emails listed above. Do NOT invent email subjects, senders, or counts.
        If no email data is shown, tell the user that inbox access requires importing emails first.
        """
        let response = try await session.respond(to: enrichedPrompt)
        return AgentResponse(
            domain: .mail,
            content: response.content,
            confidence: 0.88,
            suggestedActions: suggestedActions(for: query),
            provider: .onDevice   // enforced
        )
    }

    // MARK: - Email Context Builder

    /// Reads AgentEmail records from SwiftData (populated if user imports).
    /// Returns explicit "no data" statement when store is empty so the LLM can't hallucinate.
    private func buildEmailContext(from modelContext: ModelContext?) -> String {
        guard let ctx = modelContext,
              let emails = try? ctx.fetch(FetchDescriptor<AgentEmail>()),
              !emails.isEmpty
        else {
            return "Inbox data: Not available. No emails have been imported into AgentOS yet."
        }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600) // last 7 days
        let recent = emails
            .filter { $0.receivedAt >= cutoff }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(20)
        let lines = recent.map { email in
            "[\(email.receivedAt.formatted(date: .abbreviated, time: .omitted))] "
            + "From: \(email.sender?.name ?? email.sender?.email ?? "Unknown") | "
            + "Subject: \(email.subject)"
            + (email.isReplied ? " ✓" : " [needs reply]")
        }.joined(separator: "\n")
        return "Recent emails (last 7 days):\n\(lines)"
    }

    // MARK: - Draft Generation (on-device only)

    func draftEmail(to recipient: String, subject: String, context: String) async throws -> EmailDraft {
        let session = LanguageModelSession(instructions: systemInstructions)
        let prompt = """
        Draft a professional email:
        To: \(recipient)
        Subject: \(subject)
        Context / key points to include: \(context)

        Return only the email body, no greeting needed (the mail client adds that).
        """
        let response = try await session.respond(to: prompt)
        return EmailDraft(to: recipient, subject: subject, body: response.content)
    }

    // MARK: - Overdue Detection

    /// Returns subjects of emails unreplied for > 48h
    func overdueEmailSubjects(from emails: [AgentEmail]) -> [String] {
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        return emails
            .filter { !$0.isReplied && $0.receivedAt < cutoff }
            .map(\.subject)
    }

    // MARK: - Helpers

    private func suggestedActions(for query: String) -> [AgentAction] {
        var actions: [AgentAction] = []
        if query.localizedCaseInsensitiveContains("draft") || query.localizedCaseInsensitiveContains("write") {
            actions.append(AgentAction(label: "Draft Email", systemImage: "square.and.pencil", intent: "DraftEmailIntent"))
        }
        actions.append(AgentAction(label: "Inbox Summary", systemImage: "tray.full", intent: "QueryIntent"))
        return actions
    }
}

// MARK: - Supporting Types

struct EmailDraft {
    let to: String
    let subject: String
    let body: String
}
