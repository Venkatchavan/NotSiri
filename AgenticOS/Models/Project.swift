// Models/Project.swift – AgentOS
// Hypergraph node: work or personal project container

import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String
    var status: ProjectStatus
    var colorHex: String          // for UI tinting
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AgentTask.project)
    var tasks: [AgentTask] = []

    enum ProjectStatus: String, Codable, CaseIterable {
        case active    = "Active"
        case paused    = "Paused"
        case completed = "Completed"
        case archived  = "Archived"
    }

    init(
        name: String,
        description: String = "",
        colorHex: String = "#5856D6"
    ) {
        self.id             = UUID()
        self.name           = name
        self.projectDescription = description
        self.status         = .active
        self.colorHex       = colorHex
        self.createdAt      = Date()
        self.updatedAt      = Date()
    }
}
