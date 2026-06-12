// Views/AgentChatView.swift – AgentOS
// Column 3: Persistent AI chat with domain badges, streaming, and action chips

import SwiftUI
import SwiftData

struct AgentChatView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var inputText    = ""
    @State private var messages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var coordinator  = CoordinatorAgent.shared
    @State private var voiceRouter  = VoiceCommandRouter.shared
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent Chat").font(.headline)
                    Text(isProcessing ? "Thinking…" : "Ready")
                        .font(.caption2).foregroundStyle(isProcessing ? .blue : .green)
                }
                Spacer()
                Button { messages.removeAll() } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .help("Clear conversation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            WelcomePromptView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        if isProcessing {
                            ThinkingIndicator()
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        if isProcessing {
                            proxy.scrollTo("thinking")
                        } else {
                            proxy.scrollTo(messages.last?.id)
                        }
                    }
                }
            }

            Divider()

            // Suggested prompts
            if messages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedPrompts, id: \.self) { prompt in
                            Button { sendMessage(prompt) } label: {
                                Text(prompt)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            // Input bar
            HStack(spacing: 8) {
                // Voice button
                Button {
                    if AmbientListeningManager.shared.state == .capturingCommand {
                        AmbientListeningManager.shared.submitCommand(
                            AmbientListeningManager.shared.liveTranscript
                        )
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(AmbientListeningManager.shared.state == .capturingCommand ? Color.red : Color.secondary)
                        .symbolEffect(.pulse, isActive: AmbientListeningManager.shared.state == .capturingCommand)
                }
                .buttonStyle(.plain)

                TextField("Ask anything… (⌘↩ to send)", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onSubmit { if !inputText.isEmpty { sendMessage(inputText) } }
                    .onKeyPress(.return) {
                        guard !inputText.isEmpty else { return .ignored }
                        let hasModifier = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
                        if hasModifier { sendMessage(inputText); return .handled }
                        return .ignored
                    }

                Button {
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(inputText.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .onAppear {
            // Populate from voice router response
            if let response = voiceRouter.lastResponse {
                appendResponse(response)
            }
        }
        .onChange(of: voiceRouter.lastResponse?.id) { _, _ in
            if let r = voiceRouter.lastResponse { appendResponse(r) }
        }
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isProcessing = true

        Task {
            do {
                let response = try await coordinator.process(
                    query: text,
                    modelContext: modelContext
                )
                await MainActor.run {
                    appendResponse(response)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", domain: nil))
                    isProcessing = false
                }
            }
        }
    }

    private func appendResponse(_ response: CoordinatorResponse) {
        let msg = ChatMessage(
            role: .assistant,
            content: response.summary,
            domain: response.domainResponses.first?.domain,
            suggestedActions: response.allSuggestedActions,
            provider: response.primaryProvider,
            confidence: response.confidence
        )
        messages.append(msg)
    }

    private let suggestedPrompts = [
        "What's on my schedule today?",
        "What are my top 3 tasks?",
        "Any urgent emails I missed?",
        "Morning briefing",
        "What did I promise to do this week?"
    ]
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    enum Role { case user, assistant }
    let role: Role
    let content: String
    var domain: AgentDomain?   = nil
    var suggestedActions: [AgentAction] = []
    var provider: ProviderTier = .onDevice
    var confidence: Double     = 1.0
    let timestamp = Date()
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                Circle()
                    .fill(domainColor)
                    .frame(width: 28, height: 28)
                    .overlay(Image(systemName: message.domain?.systemImage ?? "cpu").font(.caption2).foregroundStyle(.white))
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.role == .user ? Color.accentColor : Color(.windowBackgroundColor).opacity(0.9),
                        in: BubbleShape(role: message.role)
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)

                if message.role == .assistant {
                    HStack(spacing: 6) {
                        ProviderBadge(provider: message.provider)
                        if message.confidence < 0.8 {
                            Text("\(Int(message.confidence * 100))% conf.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                if !message.suggestedActions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(message.suggestedActions) { action in
                                ActionChip(action: action)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user { Spacer() }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var domainColor: Color {
        Color(hex: message.domain?.accentColorHex ?? "#007AFF") ?? .accentColor
    }
}

private struct BubbleShape: Shape {
    let role: ChatMessage.Role
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: .init(width: r, height: r))
        return path
    }
}

private struct ProviderBadge: View {
    let provider: ProviderTier
    var body: some View {
        Text(provider.rawValue)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(.secondary.opacity(0.3)))
    }
}

private struct ActionChip: View {
    let action: AgentAction
    var body: some View {
        Label(action.label, systemImage: action.systemImage)
            .font(.caption2.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

// MARK: - Thinking Indicator

private struct ThinkingIndicator: View {
    @State private var phase = 0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .padding(12)
        .onAppear { phase = 1 }
    }
}

// MARK: - Welcome View

private struct WelcomePromptView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 44))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("AgentOS").font(.title.bold())
            Text("Your personal AI chief of staff.\nSay \"Hey AgentOS\" or type below.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Settings View stub (referenced from DashboardView)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var claudeKey = ""
    @State private var geminiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings").font(.title2.bold())
            Group {
                SecureField("Claude API Key", text: $claudeKey)
                SecureField("Gemini API Key", text: $geminiKey)
            }
            .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Save") {
                    if !claudeKey.isEmpty { LanguageModelRouter.shared.storeAPIKey(claudeKey, for: .claude) }
                    if !geminiKey.isEmpty { LanguageModelRouter.shared.storeAPIKey(geminiKey, for: .gemini) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
