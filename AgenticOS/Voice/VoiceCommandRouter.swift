// Voice/VoiceCommandRouter.swift – AgentOS
// Bridges ambient listening → CoordinatorAgent → TTS response

import Foundation
import Observation
import AVFoundation
import SwiftData

@Observable
final class VoiceCommandRouter {

    static let shared = VoiceCommandRouter()

    // Dependencies
    private let listening   = AmbientListeningManager.shared
    private let coordinator = CoordinatorAgent.shared

    // TTS
    private let synthesiser = AVSpeechSynthesizer()
    private var ttsDelegate: TTSDelegate?

    // MARK: - State

    enum RouterState: Equatable {
        case idle, listening, processing, speaking
    }
    private(set) var routerState: RouterState = .idle
    private(set) var lastResponse: CoordinatorResponse?
    private(set) var isSpeaking = false

    // Use concrete wrapper type so @Observable can generate proper tracking
    var modelContextWrapper: ModelContextWrapper?

    private init() {
        ttsDelegate = TTSDelegate(router: self)
        synthesiser.delegate = ttsDelegate
        listening.onCommandCaptured = { [weak self] command in
            Task { await self?.routeCommand(command) }
        }
    }

    // MARK: - Lifecycle

    func activate() async {
        routerState = .listening
        await listening.startAmbientListening()
    }

    func deactivate() {
        listening.stopAmbientListening()
        synthesiser.stopSpeaking(at: .immediate)
        routerState = .idle
    }

    // MARK: - Command Routing

    @MainActor
    func routeCommand(_ text: String) async {
        routerState = .processing
        do {
            let response = try await coordinator.process(
                query: text,
                modelContext: modelContextWrapper?.context
            )
            lastResponse = response
            await speak(response.summary)
        } catch {
            await speak("I encountered an error: \(error.localizedDescription)")
            routerState = .listening
        }
    }

    // MARK: - TTS

    func speak(_ text: String) async {
        isSpeaking  = true
        routerState = .speaking
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate  = 0.52
        utterance.pitchMultiplier = 1.05
        synthesiser.speak(utterance)
    }

    func stopSpeaking() {
        synthesiser.stopSpeaking(at: .word)
        isSpeaking  = false
        routerState = .listening
    }

    /// Called by TTSDelegate when speech finishes (avoids private(set) access from outside)
    fileprivate func ttsDidFinish() {
        isSpeaking  = false
        routerState = .listening
    }
}

// MARK: - TTS Delegate

private final class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var router: VoiceCommandRouter?
    init(router: VoiceCommandRouter) { self.router = router }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.router?.ttsDidFinish() }
    }
}

// MARK: - Model Context Wrapper

final class ModelContextWrapper: @unchecked Sendable {
    let context: ModelContext
    init(_ context: ModelContext) { self.context = context }
}
