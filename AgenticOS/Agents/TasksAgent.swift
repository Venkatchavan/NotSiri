// Agents/TasksAgent.swift – AgentOS
// Domain agent for task management via Reminders API + SwiftData

import Foundation
import EventKit
#if canImport(FoundationModels)
import FoundationModels
#endif
import SwiftData

actor TasksAgent: DomainAgent {

    let domain: AgentDomain = .tasks
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Tasks Agent for AgentOS. You manage the user's task list.
        Prioritise tasks intelligently based on deadlines, dependencies, and importance.
        When a task has a deadline approaching, flag it clearly.
        Suggest logical grouping by project.
        When the user asks what to work on next, return the single most impactful task.
        Format task lists as bullet points with priority indicators.
        """
    }

    private let eventStore = EKEventStore()

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let taskSummary = await buildTaskSummary(using: context.modelContext)
        let enrichedPrompt = """
        Current date: \(context.currentDate.formatted())
        Open tasks: \(taskSummary)
        User query: \(query)
        """
        let response = try await router.route(
            prompt: enrichedPrompt,
            domain: .tasks,
            complexity: .factual,
            instructions: systemInstructions
        )
        return AgentResponse(
            domain: .tasks,
            content: response.content,
            confidence: 0.94,
            suggestedActions: suggestedActions(for: query),
            provider: response.provider
        )
    }

    // MARK: - Task Operations

    @discardableResult
    func addTask(
        title: String,
        description: String = "",
        priority: AgentTask.TaskPriority = .medium,
        dueDate: Date? = nil,
        projectName: String? = nil,
        modelContext: ModelContext
    ) async throws -> AgentTask {
        let task = AgentTask(title: title, description: description, priority: priority)
        // Attach deadline
        if let due = dueDate {
            let deadline = Deadline(dueDate: due)
            task.deadline = deadline
            modelContext.insert(deadline)
        }
        // Link to project if found
        if let pName = projectName {
            let descriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.name.localizedStandardContains(pName) }
            )
            task.project = try modelContext.fetch(descriptor).first
        }
        modelContext.insert(task)
        return task
    }

    func completeTask(id: UUID, modelContext: ModelContext) async throws {
        let descriptor = FetchDescriptor<AgentTask>(predicate: #Predicate { $0.id == id })
        guard let task = try modelContext.fetch(descriptor).first else { return }
        task.isCompleted = true
        task.updatedAt = Date()
    }

    func overdueAndUrgentTasks(from modelContext: ModelContext) async throws -> [AgentTask] {
        let descriptor = FetchDescriptor<AgentTask>(
            predicate: #Predicate<AgentTask> { !$0.isCompleted }
        )
        let allOpen = try modelContext.fetch(descriptor)
        return allOpen.filter { task in
            if let dl = task.deadline { return dl.isOverdue || dl.daysRemaining <= 3 }
            return task.priority == .critical
        }
        .sorted { ($0.deadline?.daysRemaining ?? 999) < ($1.deadline?.daysRemaining ?? 999) }
    }

    // MARK: - Helpers

    private func buildTaskSummary(using context: ModelContext?) async -> String {
        guard let ctx = context else { return "No task data available." }
        guard let tasks = try? ctx.fetch(FetchDescriptor<AgentTask>(
            predicate: #Predicate { !$0.isCompleted }
        )) else { return "Unable to fetch tasks." }
        if tasks.isEmpty { return "No open tasks." }
        let top5 = tasks
            .sorted { $0.priority > $1.priority }
            .prefix(5)
        return top5.map {
            let deadline = $0.deadline.map { " (due \($0.dueDate.formatted(date: .abbreviated, time: .omitted)))" } ?? ""
            return "[\($0.priority.label)] \($0.title)\(deadline)"
        }.joined(separator: "\n")
    }

    private func suggestedActions(for query: String) -> [AgentAction] {
        var actions: [AgentAction] = []
        if query.localizedCaseInsensitiveContains("add") || query.localizedCaseInsensitiveContains("create") {
            actions.append(AgentAction(label: "Add Task", systemImage: "plus.circle", intent: "AddTaskIntent"))
        }
        actions.append(AgentAction(label: "My Tasks", systemImage: "list.bullet", intent: "QueryIntent"))
        return actions
    }
}
