//
//  AgenticOSApp.swift
//  AgenticOS
//
//  Created by Venkat Chavan on 11/06/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import AuthenticationServices

@main
struct AgenticOSApp: App {

    @State private var authState = AuthState.shared

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

        // Main window — shows Sign In or Dashboard depending on auth state
        Window("AgentOS", id: "dashboard") {
            Group {
                if authState.isSignedIn {
                    DashboardView()
                        .modelContainer(sharedModelContainer)
                        .onAppear { requestNotificationPermission() }
                } else {
                    SignInView()
                }
            }
            .animation(.easeInOut(duration: 0.4), value: authState.isSignedIn)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: authState.isSignedIn ? 1200 : 520,
                     height: authState.isSignedIn ? 780 : 620)
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
