// Intents/AddTaskIntent.swift – AgentOS

import AppIntents
import SwiftData

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to AgentOS.")

    @Parameter(title: "Task")
    var task: String

    @Parameter(title: "Project", default: nil)
    var project: String?

    @Parameter(title: "Deadline", default: nil)
    var deadline: Date?

    @Parameter(title: "Priority", default: .medium)
    var priority: TaskPriorityEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try AgentOSModelContainer.shared()
        let ctx = container.mainContext
        let agent = CoordinatorAgent.shared.tasksAgent

        let taskPriority: AgentTask.TaskPriority = {
            switch priority {
            case .low:      return .low
            case .medium:   return .medium
            case .high:     return .high
            case .critical: return .critical
            }
        }()

        let newTask = try await agent.addTask(
            title: task,
            priority: taskPriority,
            dueDate: deadline,
            projectName: project,
            modelContext: ctx
        )
        let deadlineText = deadline.map { " due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
        return .result(dialog: "Added '\(newTask.title)'\(deadlineText).")
    }
}

// MARK: - Priority Entity

enum TaskPriorityEntity: String, AppEnum {
    case low, medium, high, critical
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Priority"
    static var caseDisplayRepresentations: [TaskPriorityEntity: DisplayRepresentation] = [
        .low:      "Low",
        .medium:   "Medium",
        .high:     "High",
        .critical: "Critical"
    ]
}
