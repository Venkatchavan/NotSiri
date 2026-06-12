// Intelligence/ProactiveIntelligenceEngine.swift – AgentOS
// Background checks every 30 min via NSBackgroundActivityScheduler (macOS)
// NEVER makes cloud calls proactively; on-device Foundation Models only

import Foundation
import Observation
import UserNotifications
import SwiftData
// BackgroundTasks framework is iOS/tvOS only; macOS uses NSBackgroundActivityScheduler

@Observable
final class ProactiveIntelligenceEngine {

    static let shared = ProactiveIntelligenceEngine()

    private let coordinator = CoordinatorAgent.shared
    private(set) var lastRunDate: Date?
    private(set) var pendingAlerts: [ProactiveAlert] = []

    // macOS background scheduler
    private var activityScheduler: NSBackgroundActivityScheduler?

    private init() {}

    // MARK: - Scheduling (macOS NSBackgroundActivityScheduler)

    func scheduleNextBackgroundCheck() {
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.agentos.proactive.check")
        scheduler.repeats   = true
        scheduler.interval  = 30 * 60          // 30 minutes
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            Task {
                await self?.runCheck()
                completion(.finished)
            }
        }
        activityScheduler = scheduler
    }

    // MARK: - Main Check

    @MainActor
    func runCheck() async {
        guard let container = try? AgentOSModelContainer.shared() else { return }
        let ctx = container.mainContext

        async let overdueAlerts   = checkOverdueTasks(ctx: ctx)
        async let emailAlerts     = checkUnansweredEmails(ctx: ctx)
        async let deadlineAlerts  = checkDeadlines(ctx: ctx)

        let (overdue, emails, deadlines) = await (overdueAlerts, emailAlerts, deadlineAlerts)
        let allAlerts = (overdue + emails + deadlines)
            .sorted { $0.urgency.rawValue > $1.urgency.rawValue }

        for alert in allAlerts.prefix(5) {
            await deliverNotification(alert)
        }

        pendingAlerts = allAlerts
        lastRunDate   = Date()
    }

    // MARK: - Overdue Tasks

    private func checkOverdueTasks(ctx: ModelContext) async -> [ProactiveAlert] {
        guard let tasks = try? ctx.fetch(FetchDescriptor<AgentTask>(
            predicate: #Predicate<AgentTask> { !$0.isCompleted }
        )) else { return [] }

        return tasks.compactMap { task -> ProactiveAlert? in
            guard let dl = task.deadline else { return nil }
            switch dl.urgencyLevel {
            case .overdue:
                return ProactiveAlert(
                    type: .overdueTask,
                    title: "Overdue: \(task.title)",
                    body: "This task was due \(abs(dl.daysRemaining)) day(s) ago.",
                    urgency: .critical,
                    entityID: task.id,
                    quickActions: [.complete, .snooze]
                )
            case .critical:
                return ProactiveAlert(
                    type: .deadlineProximity,
                    title: "Due Today: \(task.title)",
                    body: "Complete this task before end of day.",
                    urgency: .high,
                    entityID: task.id,
                    quickActions: [.complete, .snooze]
                )
            case .high:
                return ProactiveAlert(
                    type: .deadlineProximity,
                    title: "Due in \(dl.daysRemaining) days: \(task.title)",
                    body: "Plan time to complete this soon.",
                    urgency: .medium,
                    entityID: task.id,
                    quickActions: [.snooze]
                )
            default: return nil
            }
        }
    }

    // MARK: - Unanswered Emails

    private func checkUnansweredEmails(ctx: ModelContext) async -> [ProactiveAlert] {
        guard let emails = try? ctx.fetch(FetchDescriptor<AgentEmail>(
            predicate: #Predicate<AgentEmail> { !$0.isReplied }
        )) else { return [] }
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        return emails
            .filter { $0.receivedAt < cutoff }
            .prefix(3)
            .map { email in
                ProactiveAlert(
                    type: .unansweredEmail,
                    title: "Pending reply: \(email.subject)",
                    body: "Received from \(email.sender?.name ?? "unknown") \(formatAge(email.receivedAt)) ago.",
                    urgency: .medium,
                    entityID: email.id,
                    quickActions: [.reply, .snooze]
                )
            }
    }

    // MARK: - Deadline Proximity (7/3/1 day alerts)

    private func checkDeadlines(ctx: ModelContext) async -> [ProactiveAlert] {
        guard let deadlines = try? ctx.fetch(FetchDescriptor<Deadline>(
            predicate: #Predicate<Deadline> { !$0.isCompleted }
        )) else { return [] }
        let thresholds = Set([7, 3, 1])
        return deadlines.compactMap { dl -> ProactiveAlert? in
            let days = dl.daysRemaining
            guard thresholds.contains(days) else { return nil }
            let taskName = dl.task?.title ?? "Deadline"
            return ProactiveAlert(
                type: .deadlineProximity,
                title: "\(days)-day warning: \(taskName)",
                body: "Due \(dl.dueDate.formatted(date: .abbreviated, time: .omitted)).",
                urgency: days == 1 ? .high : .medium,
                entityID: dl.id,
                quickActions: [.snooze]
            )
        }
    }

    // MARK: - Notification Delivery

    private func deliverNotification(_ alert: ProactiveAlert) async {
        let content = UNMutableNotificationContent()
        content.title    = alert.title
        content.body     = alert.body
        content.sound    = .default
        content.categoryIdentifier = alert.type.categoryID

        // Quick action buttons
        for action in alert.quickActions {
            let notifAction = UNNotificationAction(
                identifier: action.rawValue,
                title: action.title,
                options: action == .reply ? [.foreground] : []
            )
            let category = UNNotificationCategory(
                identifier: alert.type.categoryID,
                actions: [notifAction],
                intentIdentifiers: [],
                options: []
            )
            UNUserNotificationCenter.current().setNotificationCategories([category])
        }

        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil   // immediate delivery
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private func formatAge(_ date: Date) -> String {
        let hours = Int(-date.timeIntervalSinceNow / 3600)
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Alert Model

struct ProactiveAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let title: String
    let body: String
    let urgency: Urgency
    let entityID: UUID
    let quickActions: [QuickAction]

    enum AlertType: String {
        case overdueTask      = "overdue_task"
        case unansweredEmail  = "unanswered_email"
        case deadlineProximity = "deadline_proximity"
        var categoryID: String { "agentos.\(rawValue)" }
    }

    enum Urgency: Int, Comparable {
        case low = 0, medium = 1, high = 2, critical = 3
        static func < (l: Urgency, r: Urgency) -> Bool { l.rawValue < r.rawValue }
    }

    enum QuickAction: String {
        case complete = "complete_action"
        case snooze   = "snooze_action"
        case reply    = "reply_action"
        var title: String {
            switch self {
            case .complete: return "Complete"
            case .snooze:   return "Snooze 1h"
            case .reply:    return "Reply"
            }
        }
    }
}
