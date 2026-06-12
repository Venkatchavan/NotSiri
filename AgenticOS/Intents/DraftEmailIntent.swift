// Intents/DraftEmailIntent.swift – AgentOS

import AppIntents

struct DraftEmailIntent: AppIntent {
    static var title: LocalizedStringResource = "Draft Email"
    static var description = IntentDescription("Draft an email using AI – composing happens fully on-device.")
    static var openAppWhenRun = true

    @Parameter(title: "To")
    var to: String

    @Parameter(title: "Subject")
    var subject: String

    @Parameter(title: "Context or Key Points")
    var context: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let draft = try await CoordinatorAgent.shared.mailAgent.draftEmail(
            to: to,
            subject: subject,
            context: context
        )
        return .result(
            dialog: "Draft ready for '\(subject)' to \(to).",
            view: EmailDraftSnippetView(draft: draft)
        )
    }
}

// MARK: - Snippet View

import SwiftUI

struct EmailDraftSnippetView: View {
    let draft: EmailDraft
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Draft Email (On-Device)", systemImage: "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
            Divider()
            Group {
                HStack { Text("To:").bold(); Text(draft.to) }
                HStack { Text("Subject:").bold(); Text(draft.subject) }
            }.font(.caption)
            Text(draft.body)
                .font(.callout)
                .lineLimit(6)
        }
        .padding(12)
    }
}
