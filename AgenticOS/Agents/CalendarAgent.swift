// Agents/CalendarAgent.swift – AgentOS
// Domain agent for EventKit calendar data

import Foundation
import EventKit
import FoundationModels

actor CalendarAgent: DomainAgent {

    let domain: AgentDomain = .calendar
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Calendar Agent for AgentOS, a personal AI chief of staff.
        Your role is to manage, query, and schedule calendar events.
        You have access to the user's EventKit calendar data.
        Always speak in first-person on behalf of the user.
        Format times naturally (e.g. "3 PM tomorrow" not "15:00:00").
        Proactively notice conflicts and suggest resolutions.
        """
    }

    private let eventStore = EKEventStore()
    private var isAuthorized = false

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        await requestAccessIfNeeded()
        let calendarContext = await buildCalendarContext(for: context.currentDate)
        let enrichedPrompt = """
        Current date/time: \(context.currentDate.formatted())
        Today's calendar: \(calendarContext)
        Recent context entities: \(context.recentEntities.joined(separator: ", "))

        User query: \(query)
        """
        let response = try await router.route(
            prompt: enrichedPrompt,
            domain: .calendar,
            complexity: .factual,
            instructions: systemInstructions
        )
        let actions = suggestedActions(for: query)
        return AgentResponse(
            domain: .calendar,
            content: response.content,
            confidence: 0.92,
            suggestedActions: actions,
            provider: response.provider
        )
    }

    // MARK: - Calendar Data Access

    private func requestAccessIfNeeded() async {
        guard !isAuthorized else { return }
        do {
            isAuthorized = try await eventStore.requestFullAccessToEvents()
        } catch {
            isAuthorized = false
        }
    }

    func todaysMeetings() async -> [EKEvent] {
        await requestAccessIfNeeded()
        guard isAuthorized else { return [] }
        let start = Calendar.current.startOfDay(for: .now)
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let pred  = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    func upcomingMeetings(days: Int = 7) async -> [EKEvent] {
        await requestAccessIfNeeded()
        guard isAuthorized else { return [] }
        let end  = Calendar.current.date(byAdding: .day, value: days, to: .now)!
        let pred = eventStore.predicateForEvents(withStart: .now, end: end, calendars: nil)
        return eventStore.events(matching: pred).sorted { $0.startDate < $1.startDate }
    }

    func scheduleEvent(title: String, start: Date, duration: TimeInterval, participants: [String] = []) async throws {
        await requestAccessIfNeeded()
        guard isAuthorized else { throw CalendarError.notAuthorized }
        let event           = EKEvent(eventStore: eventStore)
        event.title         = title
        event.startDate     = start
        event.endDate       = start.addingTimeInterval(duration)
        event.calendar      = eventStore.defaultCalendarForNewEvents
        for email in participants {
            let attendee = eventStore.value(forKey: "_createAttendeeWithEmailAddress:\(email)") as? EKParticipant
            _ = attendee // EKEvent attendees are read-only; invites go via MailAgent
        }
        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Helpers

    private func buildCalendarContext(for date: Date) async -> String {
        let events = await todaysMeetings()
        if events.isEmpty { return "No events today." }
        return events.map { "\($0.title ?? "Untitled") at \($0.startDate.formatted(date: .omitted, time: .shortened))" }
                     .joined(separator: "; ")
    }

    private func suggestedActions(for query: String) -> [AgentAction] {
        var actions: [AgentAction] = []
        if query.localizedCaseInsensitiveContains("schedule") || query.localizedCaseInsensitiveContains("meeting") {
            actions.append(AgentAction(label: "Schedule", systemImage: "calendar.badge.plus", intent: "ScheduleMeetingIntent"))
        }
        actions.append(AgentAction(label: "Today's Calendar", systemImage: "calendar", intent: "QueryIntent"))
        return actions
    }

    enum CalendarError: Error { case notAuthorized }
}
