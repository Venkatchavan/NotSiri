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
        CRITICAL RULE: ONLY reference tasks that are explicitly listed in the context below.
        NEVER invent, assume, or suggest tasks that are not in the provided list.
        If no tasks are listed, say so clearly and offer to help add new ones.
        Prioritise tasks by deadline then by priority level.
        Format task lists as bullet points with priority indicators (🔴 Critical, 🟠 High, 🟡 Medium, 🟢 Low).
        """
    }

    private let eventStore = EKEventStore()

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        let (summary, hasData) = await buildTaskData(using: context.modelContext)

        // ── Guard: no real tasks → return factual answer, skip LLM ──────────
        // This is the only reliable way to prevent hallucination of fake tasks.
        guard hasData else {
            return AgentResponse(
                domain: .tasks,
                content: summary,
                confidence: 1.0,
                suggestedActions: [
                    AgentAction(label: "Add Task", systemImage: "plus.circle.fill", intent: "AddTaskIntent"),
                    AgentAction(label: "Open Reminders", systemImage: "checklist", intent: "QueryIntent")
                ],
                provider: .onDevice
            )
        }

        // ── Real tasks found → let the LLM reason about them ─────────────────
        let enrichedPrompt = """
        Current date: \(context.currentDate.formatted())
        \(summary)

        IMPORTANT: Only reference the tasks listed above. Do NOT invent tasks.
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

    /// Returns (summary string, hasRealData flag).
    /// hasRealData = false → caller must NOT route to LLM.
    private func buildTaskData(using context: ModelContext?) async -> (String, Bool) {
        // 1. SwiftData (synced from Reminders on launch)
        if let ctx = context,
           let tasks = try? ctx.fetch(FetchDescriptor<AgentTask>(
               predicate: #Predicate { !$0.isCompleted }
           )),
           !tasks.isEmpty {
            let top10 = tasks.sorted { $0.priority > $1.priority }.prefix(10)
            let lines = top10.map { t -> String in
                let dl = t.deadline.map { " — due \($0.dueDate.formatted(date: .abbreviated, time: .omitted))" } ?? ""
                return "• [\(t.priority.label)] \(t.title)\(dl)"
            }.joined(separator: "\n")
            return ("Your open tasks (\(tasks.count) total):\n\(lines)", true)
        }

        // 2. Live Reminders fallback (for first launch before sync)
        let liveReminders = await fetchLiveReminders()
        if !liveReminders.isEmpty {
            let lines = liveReminders.map { "• \($0)" }.joined(separator: "\n")
            return ("Your reminders (from Reminders app):\n\(lines)", true)
        }

        // 3. Truly empty — return factual no-data message
        return (
            "You have no open tasks or reminders in AgentOS right now.\n\n" +
            "• If you have tasks in Reminders, tap ↻ in the toolbar to re-sync.\n" +
            "• Tap **Add Task** below to create your first task.",
            false
        )
    }

    /// Direct EventKit read – used when SwiftData hasn't synced yet
    private func fetchLiveReminders() async -> [String] {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) == true else { return [] }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        return await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { reminders in
                let titles = (reminders ?? [])
                    .compactMap { $0.title }
                    .filter { !$0.isEmpty }
                cont.resume(returning: Array(titles.prefix(10)))
            }
        }
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
