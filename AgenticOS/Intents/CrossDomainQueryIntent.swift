// Intents/CrossDomainQueryIntent.swift – AgentOS
// e.g. "What did I promise Sarah about the Berlin project?"

import AppIntents
import SwiftUI
import SwiftData

struct CrossDomainQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Cross-Domain Query"
    static var description = IntentDescription(
        "Ask questions that span calendar, tasks, email, and notes simultaneously.",
        categoryName: "AgentOS"
    )

    @Parameter(title: "Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let container = try AgentOSModelContainer.shared()
        let response  = try await CoordinatorAgent.shared.process(
            query: query,
            modelContext: container.mainContext
        )
        return .result(
            dialog: IntentDialog(stringLiteral: response.summary),
            view: CrossDomainSnippetView(response: response)
        )
    }
}

// MARK: - Snippet

struct CrossDomainSnippetView: View {
    let response: CoordinatorResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cross-Domain Intelligence", systemImage: "arrow.triangle.branch")
                    .font(.caption.bold())
                Spacer()
                ConfidenceBadge(confidence: response.confidence)
            }
            Text(response.summary).font(.callout)

            if !response.domainResponses.isEmpty {
                HStack(spacing: 6) {
                    ForEach(response.domainResponses) { dr in
                        Label(dr.domain.rawValue, systemImage: dr.domain.systemImage)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
        }
        .padding(12)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2.bold())
            .foregroundStyle(confidence > 0.8 ? .green : confidence > 0.6 ? .yellow : .red)
    }
}
