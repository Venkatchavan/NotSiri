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
            if voiceRouter.routerState == .processing || voiceRouter.routerState == .speaking {
                VoiceActivityPill(state: voiceRouter.routerState, transcript: AmbientListeningManager.shared.liveTranscript)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if !proactive.pendingAlerts.isEmpty {
                AlertBadge(count: proactive.pendingAlerts.count)
                    .padding(16)
            }
        }
        .task {
            // Inject model context into voice router
            VoiceCommandRouter.shared.modelContextWrapper = ModelContextWrapper(modelContext)
            // Start ambient listening
            await VoiceCommandRouter.shared.activate()
            // Schedule first proactive check
            ProactiveIntelligenceEngine.shared.scheduleNextBackgroundCheck()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Live routing indicator
            RoutingIndicatorView()

            Spacer()

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
