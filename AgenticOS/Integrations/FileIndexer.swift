// Integrations/FileIndexer.swift – AgentOS
// Scans ~/Desktop, ~/Documents, ~/Downloads (up to 3 levels deep) and
// creates AgentFile records in SwiftData.
// File CONTENT is never read here – only metadata (name, extension, dates, path).

import Foundation
import Observation
import SwiftData

@Observable
final class FileIndexer {

    static let shared = FileIndexer()

    private(set) var isIndexing  = false
    private(set) var indexedCount = 0
    private(set) var lastIndexed: Date?

    /// Document/media extensions worth surfacing to the agent
    private static let relevantExtensions: Set<String> = [
        // Documents
        "pdf", "doc", "docx", "txt", "rtf", "md", "pages", "odt",
        // Spreadsheets
        "xls", "xlsx", "csv", "numbers", "ods",
        // Presentations
        "ppt", "pptx", "key", "odp",
        // Code
        "swift", "py", "js", "ts", "jsx", "tsx",
        "json", "yaml", "yml", "toml", "xml", "html", "css",
        // Archives
        "zip", "gz", "tar", "rar", "7z",
        // Images
        "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff",
        // Video
        "mp4", "mov", "m4v", "avi", "mkv",
        // Audio
        "mp3", "m4a", "aac", "wav", "flac",
    ]

    private init() {}

    // MARK: - Public API

    /// Index all standard user directories. Safe to call on the @MainActor
    /// (SwiftUI .task inherits MainActor context).
    @MainActor
    func indexStandardDirectories(context: ModelContext) async {
        guard !isIndexing else { return }
        isIndexing = true
        defer { isIndexing = false }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let directories = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads"),
        ]

        // Build set of already-indexed paths to avoid duplicates
        let existing = (try? context.fetch(FetchDescriptor<AgentFile>())) ?? []
        var knownPaths = Set(existing.compactMap { $0.filePath.isEmpty ? nil : $0.filePath })

        var newCount = 0

        for directory in directories {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            await scanDirectory(
                directory,
                baseDepth: directory.pathComponents.count,
                knownPaths: &knownPaths,
                newCount: &newCount,
                context: context
            )
        }

        if newCount > 0 {
            try? context.save()
        }
        indexedCount = newCount
        lastIndexed  = .now
    }

    // MARK: - Private

    @MainActor
    private func scanDirectory(
        _ directory: URL,
        baseDepth: Int,
        knownPaths: inout Set<String>,
        newCount: inout Int,
        context: ModelContext
    ) async {
        let resourceKeys: [URLResourceKey] = [
            .nameKey, .creationDateKey, .contentModificationDateKey,
            .isRegularFileKey, .isDirectoryKey, .isHiddenKey, .fileSizeKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for case let fileURL as URL in enumerator {
            // Limit depth to 3 levels below the base directory
            let depth = fileURL.pathComponents.count - baseDepth
            if depth > 3 {
                enumerator.skipDescendants()
                continue
            }

            guard
                let rv = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                rv.isRegularFile == true,
                rv.isHidden != true
            else { continue }

            // Only relevant file types
            let ext = fileURL.pathExtension.lowercased()
            guard Self.relevantExtensions.contains(ext) else { continue }

            // Skip already indexed
            let path = fileURL.path
            guard !knownPaths.contains(path) else { continue }
            knownPaths.insert(path)

            // Build bookmark (best-effort; non-sandboxed apps may not need it)
            let bookmark = try? fileURL.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let rawName = fileURL.deletingPathExtension().lastPathComponent
            let file = AgentFile(
                name: rawName,
                extension: ext,
                bookmarkData: bookmark,
                tags: [directory.lastPathComponent.lowercased()]
            )
            file.filePath     = path
            file.lastModified = rv.contentModificationDate ?? .now
            file.createdAt    = rv.creationDate ?? .now

            context.insert(file)
            newCount += 1

            // Flush every 100 records to avoid memory pressure
            if newCount % 100 == 0 {
                try? context.save()
                // Yield to keep the UI responsive
                await Task.yield()
            }
        }
    }

    // MARK: - Re-index (called on periodic refresh)

    /// Lightweight incremental re-scan: only adds new files, does not remove deleted ones.
    @MainActor
    func incrementalRefresh(context: ModelContext) async {
        await indexStandardDirectories(context: context)
    }
}
