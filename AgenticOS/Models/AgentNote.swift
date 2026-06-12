// Models/AgentNote.swift – AgentOS
// Hypergraph node: note from local, Obsidian, or Notion

import Foundation
import SwiftData

@Model
final class AgentNote {
    var id: UUID
    var title: String
    var content: String
    var tags: [String]
    var source: NoteSource
    /// External vault/database identifier (Obsidian path, Notion page ID)
    var externalID: String?
    var createdAt: Date
    var updatedAt: Date

    enum NoteSource: String, Codable, CaseIterable {
        case local    = "Local"
        case obsidian = "Obsidian"
        case notion   = "Notion"

        var systemImage: String {
            switch self {
            case .local:    return "note.text"
            case .obsidian: return "diamond.fill"
            case .notion:   return "square.grid.2x2"
            }
        }
    }

    init(
        title: String,
        content: String,
        source: NoteSource = .local,
        tags: [String] = [],
        externalID: String? = nil
    ) {
        self.id         = UUID()
        self.title      = title
        self.content    = content
        self.source     = source
        self.tags       = tags
        self.externalID = externalID
        self.createdAt  = Date()
        self.updatedAt  = Date()
    }
}
