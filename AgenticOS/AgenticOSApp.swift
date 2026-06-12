//
//  AgenticOSApp.swift
//  AgenticOS
//
//  Created by Venkat Chavan on 11/06/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct AgenticOSApp: App {

    // MARK: - SwiftData Hypergraph Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AgentTask.self,
            Project.self,
            Person.self,
            AgentEmail.self,
            AgentFile.self,
            AgentNote.self,
            Deadline.self,
            Meeting.self,
        ])
        // Use local-only config (no CloudKit) to avoid iCloud container setup
        // requirement during development/testing
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Register globally so background engines (ProactiveIntelligenceEngine, FileIndexer)
            // can access the same container without needing a SwiftUI environment.
            AgentOSModelContainer._container = container
            return container
        } catch {
            fatalError("Could not create AgentOS ModelContainer: \(error)")
        }
    }()

    // MARK: - Scenes

    var body: some Scene {

        // Main three-column dashboard
        Window("AgentOS Dashboard", id: "dashboard") {
            DashboardView()
                .modelContainer(sharedModelContainer)
                .onAppear { requestNotificationPermission() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 780)
        .commands {
            AgentOSCommands()
        }

        // Always-visible menu bar extra
        MenuBarExtra("AgentOS", systemImage: "cpu.fill") {
            MenuBarAgentView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            ProactiveIntelligenceEngine.shared.scheduleNextBackgroundCheck()
        }
    }
}

// MARK: - Menu Commands

struct AgentOSCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Morning Briefing") {
                Task {
                    _ = try? await CoordinatorAgent.shared.morningDigest(modelContext: nil)
                }
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Start Listening") {
                Task { await VoiceCommandRouter.shared.activate() }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }
    }
}
