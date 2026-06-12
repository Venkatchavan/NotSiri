// Intents/AppShortcuts.swift – AgentOS
// App Shortcuts provider – registers all intents with Siri + Shortcuts

import AppIntents

struct AgentOSShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QueryIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Hey \(.applicationName)"
            ],
            shortTitle: "Ask AgentOS",
            systemImageName: "cpu.fill"
        )

        AppShortcut(
            intent: ProactiveDigestIntent(),
            phrases: [
                "Morning briefing from \(.applicationName)",
                "What's on today with \(.applicationName)"
            ],
            shortTitle: "Morning Briefing",
            systemImageName: "sun.and.horizon.fill"
        )

        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: ScheduleMeetingIntent(),
            phrases: [
                "Schedule meeting in \(.applicationName)"
            ],
            shortTitle: "Schedule Meeting",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: DraftEmailIntent(),
            phrases: [
                "Draft email in \(.applicationName)"
            ],
            shortTitle: "Draft Email",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: FindFilesIntent(),
            phrases: [
                "Find files in \(.applicationName)"
            ],
            shortTitle: "Find Files",
            systemImageName: "folder.fill.badge.magnifyingglass"
        )

        AppShortcut(
            intent: CrossDomainQueryIntent(),
            phrases: [
                "Cross-domain query in \(.applicationName)"
            ],
            shortTitle: "Cross-Domain Query",
            systemImageName: "arrow.triangle.branch"
        )
    }
}

// AgentOSModelContainer is defined in Models/AgentOSModelContainer.swift
