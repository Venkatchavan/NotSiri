// Models/AgentFile.swift – AgentOS
// Hypergraph node: file reference – content never transmitted to cloud

import Foundation
import SwiftData

@Model
final class AgentFile {
    var id: UUID
    var name: String
    var fileExtension: String
    /// Absolute path on disk – primary way to open the file (non-sandboxed)
    var filePath: String
    /// Security-scoped bookmark for re-opening in sandboxed builds
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
        filePath: String = "",
        bookmarkData: Data? = nil,
        tags: [String] = []
    ) {
        self.id            = UUID()
        self.name          = name
        self.fileExtension = ext
        self.filePath      = filePath
        self.bookmarkData  = bookmarkData
        self.tags          = tags
        self.aiSummary     = ""
        self.lastModified  = Date()
        self.createdAt     = Date()
    }

    /// Resolve the URL: prefer filePath (direct), fall back to security-scoped bookmark
    func resolveURL() -> URL? {
        if !filePath.isEmpty { return URL(fileURLWithPath: filePath) }
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
