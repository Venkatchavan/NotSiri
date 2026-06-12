// Intents/ProactiveDigestIntent.swift – AgentOS
// Morning briefing: meetings + tasks + emails + insight

import AppIntents
import SwiftUI
import SwiftData

struct ProactiveDigestIntent: AppIntent {
    static var title: LocalizedStringResource = "Morning Briefing"
    static var description = IntentDescription("Get your personalised AgentOS morning briefing.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let container = try AgentOSModelContainer.shared()
        let response  = try await CoordinatorAgent.shared.morningDigest(
            modelContext: container.mainContext
        )
        return .result(
            dialog: IntentDialog(stringLiteral: response.summary),
            view: DigestSnippetView(response: response)
        )
    }
}

// MARK: - Snippet

struct DigestSnippetView: View {
    let response: CoordinatorResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Morning Briefing", systemImage: "sun.and.horizon.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(response.summary)
                .font(.callout)
                .lineLimit(8)
            Divider()
            HStack {
                ForEach(AgentDomain.allCases.prefix(4)) { domain in
                    if response.domainResponses.contains(where: { $0.domain == domain }) {
                        Image(systemName: domain.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Text("via AgentOS").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }
}

// MARK: - Siri Tip shortcut phrase
extension ProactiveDigestIntent {
    static var suggestedInvocationPhrases: [String] {
        ["Morning briefing", "What's on today", "AgentOS digest"]
    }
}
