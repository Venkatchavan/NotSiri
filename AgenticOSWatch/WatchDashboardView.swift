// AgenticOSWatch/WatchDashboardView.swift
// Three quick-action tiles + voice query via Siri / App Intent

import SwiftUI

struct WatchDashboardView: View {

    @State private var lastAnswer  = ""
    @State private var isLoading   = false
    @State private var showAnswer  = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // App header
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.blue)
                        Text("AgentOS")
                            .font(.headline)
                    }

                    // Quick action buttons
                    QuickActionTile(
                        icon: "checkmark.circle.fill",
                        title: "Next Task",
                        color: .green
                    ) { await quickAsk("What is my single most important task right now?") }

                    QuickActionTile(
                        icon: "calendar.fill",
                        title: "Today's Meetings",
                        color: .red
                    ) { await quickAsk("What meetings do I have today?") }

                    QuickActionTile(
                        icon: "sun.and.horizon.fill",
                        title: "Morning Digest",
                        color: .orange
                    ) { await quickAsk("Give me a short morning briefing") }

                    QuickActionTile(
                        icon: "envelope.fill",
                        title: "Urgent Emails",
                        color: .blue
                    ) { await quickAsk("Do I have any urgent emails needing reply?") }

                    QuickActionTile(
                        icon: "exclamationmark.triangle.fill",
                        title: "Overdue Tasks",
                        color: .yellow
                    ) { await quickAsk("What tasks are overdue or due today?") }

                    if isLoading {
                        ProgressView().padding()
                    }

                    if showAnswer {
                        Text(lastAnswer)
                            .font(.footnote)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { showAnswer = false }
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("AgentOS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Query Proxy

    private func quickAsk(_ query: String) async {
        isLoading = true
        showAnswer = false
        // On watchOS 27: attempt on-device Foundation Models first
        // For complex queries, proxy to Mac via Multipeer Connectivity
        do {
            let response = try await WatchQueryProxy.shared.ask(query)
            lastAnswer = response
            isLoading  = false
            showAnswer = true
        } catch {
            lastAnswer = "Error: \(error.localizedDescription)"
            isLoading  = false
            showAnswer = true
        }
    }
}

// MARK: - Quick Action Tile

private struct QuickActionTile: View {
    let icon: String
    let title: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.callout.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .tint(color.opacity(0.15))
    }
}
