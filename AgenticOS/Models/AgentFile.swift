// Models/AgentFile.swift – AgentOS
// Hypergraph node: file reference – content never transmitted to cloud

import Foundation
import SwiftData

@Model
final class AgentFile {
    var id: UUID
    var name: String
    var fileExtension: String
    /// Security-scoped bookmark so we can re-open without full disk access
    var bookmarkData: Data?
    var tags: [String]
    /// AI-generated summary (on-device only, max 500 chars)
    var aiSummary: String
    var lastModified: Date
    var createdAt: Date

    var displayName: String { "\(name).\(fileExtension)" }

    init(
        name: String,
        extension ext: String,
        bookmarkData: Data? = nil,
        tags: [String] = []
    ) {
        self.id           = UUID()
        self.name         = name
        self.fileExtension = ext
        self.bookmarkData = bookmarkData
        self.tags         = tags
        self.aiSummary    = ""
        self.lastModified = Date()
        self.createdAt    = Date()
    }

    /// Resolve the security-scoped URL from stored bookmark
    func resolveURL() -> URL? {
        guard let data = bookmarkData else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
