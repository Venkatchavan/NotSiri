// Intents/FindFilesIntent.swift – AgentOS

import AppIntents
import SwiftUI
import SwiftData

struct FindFilesIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Files"
    static var description = IntentDescription("Search your files using natural language.")

    @Parameter(title: "Search Query")
    var query: String

    @Parameter(title: "Start Date", default: nil)
    var startDate: Date?

    @Parameter(title: "End Date", default: nil)
    var endDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let container = try AgentOSModelContainer.shared()
        let ctx = container.mainContext
        let dateRange: DateInterval? = (startDate != nil && endDate != nil)
            ? DateInterval(start: startDate!, end: endDate!)
            : nil

        let files = try await CoordinatorAgent.shared.filesAgent.searchFiles(
            query: query,
            dateRange: dateRange,
            modelContext: ctx
        )

        let dialog = files.isEmpty
            ? "No files found matching '\(query)'."
            : "Found \(files.count) file\(files.count == 1 ? "" : "s") matching '\(query)'."

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: FileResultsSnippetView(files: Array(files.prefix(5)), query: query)
        )
    }
}

// MARK: - Snippet View

struct FileResultsSnippetView: View {
    let files: [AgentFile]
    let query: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Files matching \"\(query)\"", systemImage: "folder.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(files) { file in
                HStack {
                    Image(systemName: iconName(for: file.fileExtension))
                    VStack(alignment: .leading) {
                        Text(file.displayName).font(.callout.bold())
                        if !file.aiSummary.isEmpty {
                            Text(file.aiSummary).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(file.lastModified.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
                }
            }
        }
        .padding(12)
    }

    private func iconName(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf":            return "doc.richtext"
        case "png","jpg","heic": return "photo"
        case "swift":          return "swift"
        case "md","txt":       return "doc.text"
        default:               return "doc"
        }
    }
}
