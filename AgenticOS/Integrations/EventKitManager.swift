// Integrations/EventKitManager.swift – AgentOS
// Sync bridge between EventKit and SwiftData Meeting/Deadline models

import Foundation
import Observation
import EventKit
import SwiftData

@Observable
final class EventKitManager {

    static let shared = EventKitManager()
    private let store = EKEventStore()
    private(set) var isAuthorized = false

    private init() {}

    // MARK: - Auth

    func requestAccess() async throws {
        isAuthorized = try await store.requestFullAccessToEvents()
    }

    // MARK: - Sync EventKit → SwiftData

    func syncCalendarToSwiftData(context: ModelContext) async throws {
        if !isAuthorized { try await requestAccess() }
        let start = Calendar.current.startOfDay(for: .now)
        let end   = Calendar.current.date(byAdding: .month, value: 3, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: pred)

        for event in events {
            // Capture as Optional<String> to match Meeting.eventKitIdentifier: String?
            let eventID: String? = event.eventIdentifier
            let descriptor = FetchDescriptor<Meeting>(
                predicate: #Predicate { $0.eventKitIdentifier == eventID }
            )
            guard (try context.fetch(descriptor)).isEmpty else { continue }

            let meeting = Meeting(
                title: event.title ?? "Untitled",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location
            )
            meeting.eventKitIdentifier = event.eventIdentifier
            if let notes = event.notes { meeting.notes = notes }
            context.insert(meeting)
        }
    }

    // MARK: - Sync Reminders → SwiftData

    func syncRemindersToSwiftData(context: ModelContext) async throws {
        let reminderStore = EKEventStore()
        let authorized = try await reminderStore.requestFullAccessToReminders()
        guard authorized else { return }

        let predicate = reminderStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders = try await withCheckedThrowingContinuation { cont in
            reminderStore.fetchReminders(matching: predicate) { reminders in
                cont.resume(returning: reminders ?? [])
            }
        }

        for reminder in reminders {
            let identifier = reminder.calendarItemIdentifier
            let descriptor = FetchDescriptor<AgentTask>(
                predicate: #Predicate { $0.remindersIdentifier == identifier }
            )
            guard (try context.fetch(descriptor)).isEmpty else { continue }

            let task = AgentTask(
                title: reminder.title ?? "Untitled",
                priority: .medium
            )
            task.remindersIdentifier = identifier
            if let dueDate = reminder.dueDateComponents?.date {
                let deadline = Deadline(dueDate: dueDate)
                task.deadline = deadline
                context.insert(deadline)
            }
            context.insert(task)
        }
    }
}
