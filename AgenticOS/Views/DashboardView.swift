// Views/DashboardView.swift – AgentOS
// Three-column macOS layout: Timeline | Active Focus | Agent Chat
// Liquid Glass aesthetic using macOS 26 materials

import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedDomain: AgentDomain? = nil
    @State private var voiceRouter = VoiceCommandRouter.shared
    @State private var proactive   = ProactiveIntelligenceEngine.shared
    @State private var showPrivacySheet  = false
    @State private var showSettingsSheet = false

    // Startup sync state
    @State private var isSyncing   = false
    @State private var syncMessage = ""

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {

            // MARK: Column 1 – Timeline
            TimelineView(selectedDomain: $selectedDomain)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)

        } content: {

            // MARK: Column 2 – Active Focus
            ActiveFocusView(domain: selectedDomain)
                .navigationSplitViewColumnWidth(min: 300, ideal: 420, max: 540)

        } detail: {

            // MARK: Column 3 – Agent Chat
            AgentChatView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 400)
        }
        .navigationTitle("")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showPrivacySheet)  { PrivacyConsentView() }
        .sheet(isPresented: $showSettingsSheet) { SettingsView() }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                // Sync status pill
                if isSyncing {
                    SyncStatusPill(message: syncMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // Voice activity pill
                if voiceRouter.routerState == .processing || voiceRouter.routerState == .speaking {
                    VoiceActivityPill(state: voiceRouter.routerState,
                                      transcript: AmbientListeningManager.shared.liveTranscript)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.3), value: isSyncing)
            .animation(.easeInOut(duration: 0.3), value: voiceRouter.routerState)
        }
        .overlay(alignment: .topTrailing) {
            if !proactive.pendingAlerts.isEmpty {
                AlertBadge(count: proactive.pendingAlerts.count)
                    .padding(16)
            }
        }
        .task { await startupSync() }
    }

    // MARK: - Startup Sync Pipeline

    /// Pulls ALL real device data into SwiftData on launch.
    /// Runs on @MainActor (SwiftUI .task inherits view's actor).
    @MainActor
    private func startupSync() async {
        // 1. Wire model context into voice router
        VoiceCommandRouter.shared.modelContextWrapper = ModelContextWrapper(modelContext)

        // 2. Reset cached auth flags so re-sync picks up any permission changes
        await CoordinatorAgent.shared.calendarAgent.resetAuthForResync()

        // 3. Sync Calendar events → Meeting records
        await performSync("Syncing Calendar…") {
            try await EventKitManager.shared.syncCalendarToSwiftData(context: modelContext)
        }

        // 4. Sync Reminders → AgentTask records
        await performSync("Syncing Reminders…") {
            try await EventKitManager.shared.syncRemindersToSwiftData(context: modelContext)
        }

        // 5. Sync Contacts → Person records
        await performSync("Syncing Contacts…") {
            try await ContactsManager.shared.syncContactsToSwiftData(context: modelContext)
        }

        // 6. Index files in Desktop / Documents / Downloads
        isSyncing   = true
        syncMessage = "Indexing Files…"
        await FileIndexer.shared.indexStandardDirectories(context: modelContext)

        // Done
        isSyncing   = false
        syncMessage = ""

        // 7. Start ambient listening
        await VoiceCommandRouter.shared.activate()

        // 8. Schedule proactive background checks
        ProactiveIntelligenceEngine.shared.scheduleNextBackgroundCheck()
    }

    private func performSync(_ message: String, _ work: @escaping () async throws -> Void) async {
        isSyncing   = true
        syncMessage = message
        do    { try await work() }
        catch { /* permission denied or not available – silent */ }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Live routing indicator
            RoutingIndicatorView()

            Spacer()

            // Sync button (manual re-sync)
            Button {
                Task { await startupSync() }
            } label: {
                Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: isSyncing)
            }
            .help("Re-sync device data")
            .disabled(isSyncing)

            // Ambient listening toggle
            Button {
                Task {
                    if voiceRouter.routerState == .idle {
                        await voiceRouter.activate()
                    } else {
                        voiceRouter.deactivate()
                    }
                }
            } label: {
                Image(systemName: voiceRouter.routerState == .idle ? "mic.slash" : "mic.fill")
                    .symbolEffect(.pulse, isActive: voiceRouter.routerState == .listening)
                    .foregroundStyle(voiceRouter.routerState == .listening ? .green : .primary)
            }
            .help("Toggle ambient listening (Hey AgentOS)")

            Button { showPrivacySheet  = true } label: { Image(systemName: "lock.shield") }
                .help("Privacy & Routing")

            Button { showSettingsSheet = true } label: { Image(systemName: "gearshape") }
                .help("Settings")
        }
    }
}

// MARK: - Sync Status Pill

private struct SyncStatusPill: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text(message).font(.caption).lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 4)
    }
}

// MARK: - Voice Activity Pill

private struct VoiceActivityPill: View {
    let state: VoiceCommandRouter.RouterState
    let transcript: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state == .speaking ? "waveform" : "mic.fill")
                .symbolEffect(.variableColor.iterative, isActive: true)
                .foregroundStyle(state == .speaking ? .blue : .green)
            Text(transcript.isEmpty ? (state == .speaking ? "Speaking…" : "Listening…") : transcript)
                .font(.callout)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 8)
    }
}

// MARK: - Routing Indicator

private struct RoutingIndicatorView: View {
    var router = LanguageModelRouter.shared
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(.green).frame(width: 6, height: 6)
            Text("On-Device").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Alert Badge

private struct AlertBadge: View {
    let count: Int
    var body: some View {
        Label("\(count)", systemImage: "bell.badge.fill")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.red.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}
