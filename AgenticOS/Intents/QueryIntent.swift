// Intents/QueryIntent.swift – AgentOS
// Catch-all natural language intent

import AppIntents
import SwiftData

struct QueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask AgentOS"
    static var description = IntentDescription("Ask AgentOS anything about your calendar, tasks, email, files, or notes.")
    static var openAppWhenRun = false

    @Parameter(title: "Query", description: "Your natural language question")
    var naturalLanguage: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let response = try await CoordinatorAgent.shared.process(query: naturalLanguage)
        return .result(
            dialog: IntentDialog(stringLiteral: response.summary),
            view: QuerySnippetView(response: response)
        )
    }
}

// MARK: - Snippet View

import SwiftUI

struct QuerySnippetView: View {
    let response: CoordinatorResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AgentOS", systemImage: "cpu.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(response.summary)
                .font(.callout)
                .lineLimit(4)
            if !response.allSuggestedActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(response.allSuggestedActions) { action in
                            Label(action.label, systemImage: action.systemImage)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}
