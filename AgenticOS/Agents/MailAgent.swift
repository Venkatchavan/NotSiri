
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
        You are the Mail Agent for AgentOS.
        CRITICAL RULE: ONLY reference emails that are explicitly listed in the context below.
        NEVER invent, fabricate, or assume the existence of emails, senders, or subjects.
        If no emails are listed, say so clearly — do NOT make up placeholder examples.
        PRIVACY RULE: Email body content is never sent to cloud services. Only subjects and senders are used.
        Draft emails professionally but concisely.
        """
    }

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let emailContext = buildEmailContext(from: context.modelContext)

        // ── Guard: no email data → skip LLM, return factual answer ───────────
        if emailContext.hasPrefix("Inbox data: Not available") {
            return AgentResponse(
                domain: .mail,
                content: "No email data is available in AgentOS yet.\n\n" +
                         "AgentOS can **compose** emails via your default mail client. " +
                         "Use the **Mail** panel in the Active Focus column to compose.\n\n" +
                         "Note: macOS privacy restrictions prevent apps from reading Mail.app's inbox directly.",
                confidence: 1.0,
                suggestedActions: [
                    AgentAction(label: "Compose Email", systemImage: "square.and.pencil", intent: "DraftEmailIntent")
                ],
                provider: .onDevice
            )
        }

        // ── Real emails found → use on-device LLM ────────────────────────────
        let session = LanguageModelSession(instructions: systemInstructions)
        let enrichedPrompt = """
        Current date: \(context.currentDate.formatted())
        \(emailContext)

        IMPORTANT: Only reference the emails listed above. Do NOT invent emails.
        User query: \(query)
        """
        let response = try await session.respond(to: enrichedPrompt)
        return AgentResponse(
            domain: .mail,
            content: response.content,
            confidence: 0.88,
            suggestedActions: suggestedActions(for: query),
            provider: .onDevice
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
