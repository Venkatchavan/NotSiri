// Models/AgentTask.swift – AgentOS
// Hypergraph node: a single actionable task, linked to Project + Deadline

import Foundation
import SwiftData

@Model
final class AgentTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var isCompleted: Bool
    var priority: TaskPriority
    /// EventKit / Reminders external identifier
    var remindersIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Deadline.task)
    var deadline: Deadline?

    // MARK: - Priority
    enum TaskPriority: Int, Codable, Comparable, CaseIterable {
        case low      = 0
        case medium   = 1
        case high     = 2
        case critical = 3

        var label: String {
            switch self {
            case .low:      return "Low"
            case .medium:   return "Medium"
            case .high:     return "High"
            case .critical: return "Critical"
            }
        }

        var systemImage: String {
            switch self {
            case .low:      return "arrow.down.circle"
            case .medium:   return "minus.circle"
            case .high:     return "arrow.up.circle"
            case .critical: return "exclamationmark.circle.fill"
            }
        }

        static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    init(
        title: String,
        description: String = "",
        priority: TaskPriority = .medium,
        project: Project? = nil
    ) {
        self.id              = UUID()
        self.title           = title
        self.taskDescription = description
        self.isCompleted     = false
        self.priority        = priority
        self.project         = project
        self.createdAt       = Date()
        self.updatedAt       = Date()
    }
}
