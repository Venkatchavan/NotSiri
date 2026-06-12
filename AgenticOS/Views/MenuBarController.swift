// Views/MenuBarController.swift – AgentOS
// macOS menu bar extra: always-accessible quick commands

import SwiftUI
import SwiftData

struct MenuBarAgentView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = CoordinatorAgent.shared
    @State private var voice       = VoiceCommandRouter.shared
    @State private var input       = ""
    @State private var lastAnswer  = ""
    @State private var isThinking  = false
    @State private var openWindow  = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status bar
            HStack {
                Circle()
                    .fill(voice.routerState == .listening ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(statusText).font(.caption.bold())
                Spacer()
                Button("Open Dashboard") { openWindow = true }
                    .font(.caption)
            }

            Divider()

            // Quick ask
            HStack {
                TextField("Ask AgentOS…", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { askQuestion() }
                Button(action: askQuestion) {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .disabled(input.isEmpty || isThinking)
                .buttonStyle(.plain)
            }

            if !lastAnswer.isEmpty {
                ScrollView { Text(lastAnswer).font(.callout) }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if isThinking {
                ProgressView().scaleEffect(0.7)
            }

            Divider()

            // Quick actions
            VStack(spacing: 4) {
                MenuBarActionButton(icon: "sun.and.horizon", label: "Morning Briefing") {
                    Task { await runMorningDigest() }
                }
                MenuBarActionButton(icon: "checkmark.circle", label: "What's next?") {
                    Task { await quickAsk("What is my single most important task right now?") }
                }
                MenuBarActionButton(icon: "calendar", label: "Next meeting") {
                    Task { await quickAsk("When is my next meeting and who is it with?") }
                }
                MenuBarActionButton(icon: "mic.fill", label: voice.routerState == .idle ? "Start Listening" : "Stop Listening") {
                    Task {
                        if voice.routerState == .idle { await voice.activate() }
                        else { voice.deactivate() }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var statusText: String {
        switch voice.routerState {
        case .idle:            return "Idle"
        case .listening:       return "Listening for \"Hey AgentOS\""
        case .processing:      return "Processing…"
        case .speaking:        return "Speaking…"
        }
    }

    private func askQuestion() {
        guard !input.isEmpty else { return }
        let q = input; input = ""
        Task { await quickAsk(q) }
    }

    private func quickAsk(_ q: String) async {
        isThinking = true
        do {
            let response = try await coordinator.process(query: q, modelContext: modelContext)
            await MainActor.run {
                lastAnswer = response.summary
                isThinking = false
            }
        } catch {
            await MainActor.run { lastAnswer = error.localizedDescription; isThinking = false }
        }
    }

    private func runMorningDigest() async {
        isThinking = true
        do {
            let digest = try await coordinator.morningDigest(modelContext: modelContext)
            await MainActor.run { lastAnswer = digest.summary; isThinking = false }
        } catch {
            await MainActor.run { lastAnswer = error.localizedDescription; isThinking = false }
        }
    }
}

private struct MenuBarActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.callout)
        }
        .buttonStyle(.plain)
    }
}
