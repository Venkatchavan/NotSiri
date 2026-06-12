// Agents/CalendarAgent.swift – AgentOS
// Domain agent for EventKit calendar data

import Foundation
import EventKit
#if canImport(FoundationModels)
import FoundationModels
#endif

actor CalendarAgent: DomainAgent {

    let domain: AgentDomain = .calendar
    let router: LanguageModelRouter = .shared

    var systemInstructions: String {
        """
        You are the Calendar Agent for AgentOS, a personal AI chief of staff.
        CRITICAL RULE: ONLY reference events that are explicitly listed in the context below.
        NEVER invent, assume, or fabricate calendar events, meetings, or appointments.
        If no events are listed, say the calendar is clear for that period.
        Format times naturally (e.g. "3 PM tomorrow" not "15:00:00").
        Proactively notice conflicts only if multiple events overlap in the provided list.
        """
    }

    private let eventStore = EKEventStore()
    private var isAuthorized = false

    // MARK: - DomainAgent

    func process(query: String, context: AgentContext) async throws -> AgentResponse {
        await requestAccessIfNeeded()

        // ── Guard: no permission ──────────────────────────────────────────────
        guard isAuthorized else {
            return AgentResponse(
                domain: .calendar,
                content: "Calendar access has not been granted.\n\nTo fix: open **System Settings → Privacy & Security → Calendar** and enable AgentOS, then tap ↻ to re-sync.",
                confidence: 1.0,
                suggestedActions: [],
                provider: .onDevice
            )
        }

        // Fetch real events
        let todayEvents    = await todaysMeetings()
        let upcomingEvents = await upcomingMeetings(days: 3)
        let futureEvents   = upcomingEvents.filter { !Calendar.current.isDateInToday($0.startDate) }

        // ── Guard: calendar is genuinely clear ───────────────────────────────
        if todayEvents.isEmpty && futureEvents.isEmpty {
            let dateStr = context.currentDate.formatted(date: .complete, time: .omitted)
            return AgentResponse(
                domain: .calendar,
                content: "Your calendar is clear — no events found for today (\(dateStr)) or the next 2 days.",
                confidence: 1.0,
                suggestedActions: [
                    AgentAction(label: "Schedule Meeting", systemImage: "calendar.badge.plus", intent: "ScheduleMeetingIntent")
                ],
                provider: .onDevice
            )
        }

        // ── Real events exist → let LLM reason about them ────────────────────
        let calendarContext = buildCalendarString(today: todayEvents, upcoming: futureEvents)
        let enrichedPrompt = """
        Current date/time: \(context.currentDate.formatted())
        \(calendarContext)

        IMPORTANT: Only reference the events listed above. Do NOT invent events.
        User query: \(query)
        """
        let response = try await router.route(
            prompt: enrichedPrompt,
            domain: .calendar,
            complexity: .factual,
            instructions: systemInstructions
        )
        return AgentResponse(
            domain: .calendar,
            content: response.content,
            confidence: 0.92,
            suggestedActions: suggestedActions(for: query),
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
        let event       = EKEvent(eventStore: eventStore)
        event.title     = title
        event.startDate = start
        event.endDate   = start.addingTimeInterval(duration)
        event.calendar  = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Helpers

    private func buildCalendarString(today: [EKEvent], upcoming: [EKEvent]) -> String {
        var parts: [String] = []
        if today.isEmpty {
            parts.append("Today: No events scheduled.")
        } else {
            let s = today.map {
                "\($0.title ?? "Untitled") at \($0.startDate.formatted(date: .omitted, time: .shortened))"
                + ($0.location.map { " @ \($0)" } ?? "")
            }.joined(separator: "; ")
            parts.append("Today (\(today.count) event\(today.count == 1 ? "" : "s")): \(s)")
        }
        if !upcoming.isEmpty {
            let s = upcoming.prefix(5).map {
                "\($0.title ?? "Untitled") on \($0.startDate.formatted(date: .abbreviated, time: .shortened))"
            }.joined(separator: "; ")
            parts.append("Upcoming (next 2 days): \(s)")
        }
        return parts.joined(separator: "\n")
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
