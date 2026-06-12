// Intents/ScheduleMeetingIntent.swift – AgentOS

import AppIntents
import EventKit

struct ScheduleMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Schedule Meeting"
    static var description = IntentDescription("Schedule a new meeting via AgentOS.")

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Start Time")
    var startTime: Date

    @Parameter(title: "Duration (minutes)", default: 60)
    var durationMinutes: Int

    @Parameter(title: "Participants", description: "Comma-separated emails or names")
    var participants: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let duration  = TimeInterval(durationMinutes) * 60
        let participantList = (participants ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        try await CoordinatorAgent.shared.calendarAgent.scheduleEvent(
            title: title,
            start: startTime,
            duration: duration,
            participants: participantList
        )
        let timeStr = startTime.formatted(date: .abbreviated, time: .shortened)
        return .result(dialog: "Scheduled '\(title)' for \(timeStr) (\(durationMinutes) min).")
    }
}
