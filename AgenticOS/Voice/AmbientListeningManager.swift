// Voice/AmbientListeningManager.swift – AgentOS
// Continuous ambient listening with "Hey AgentOS" wake phrase detection

import Foundation
import Observation
import Speech
import AVFoundation
#if os(macOS)
import AppKit
#endif

@Observable
final class AmbientListeningManager: NSObject {

    static let shared = AmbientListeningManager()

    // MARK: - State

    enum ListeningState: Equatable {
        case idle
        case listeningForWakePhrase
        case wakeDetected
        case capturingCommand
        case processing
        case error(String)
    }

    private(set) var state: ListeningState = .idle
    private(set) var liveTranscript: String = ""
    var onCommandCaptured: ((String) -> Void)?

    // MARK: - Private

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioEngine       = AVAudioEngine()
    private var recognitionTask:    SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private let wakePhrase           = "hey agentOS"
    private let commandTimeoutSecs: TimeInterval = 8.0
    private var commandCaptureStart:  Date?

    private override init() { super.init() }

    // MARK: - Public API

    func startAmbientListening() async {
        guard await requestPermissions() else {
            state = .error("Microphone or speech recognition permission denied.")
            return
        }
        state = .listeningForWakePhrase
        startRecognitionSession()
    }

    func stopAmbientListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
    }

    // MARK: - Recognition Session

    private func startRecognitionSession() {
        let inputNode = audioEngine.inputNode
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.requiresOnDeviceRecognition = true   // privacy first
        request.shouldReportPartialResults  = true
        request.taskHint = .search

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                DispatchQueue.main.async { self.liveTranscript = transcript }
                self.handleTranscript(transcript)
            }
            if error != nil || result?.isFinal == true {
                self.restartSessionAfterDelay()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            state = .error("Audio engine failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Wake Phrase + Command Capture

    private func handleTranscript(_ transcript: String) {
        switch state {
        case .listeningForWakePhrase:
            if transcript.contains(wakePhrase) {
                DispatchQueue.main.async { self.state = .wakeDetected }
                triggerWakeResponse()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.state = .capturingCommand
                    self.commandCaptureStart = Date()
                }
            }
        case .capturingCommand:
            // Strip the wake phrase prefix from transcript
            let command = transcript
                .replacingOccurrences(of: wakePhrase, with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            DispatchQueue.main.async { self.liveTranscript = command }

            // Timeout-based submission
            if let start = commandCaptureStart,
               Date().timeIntervalSince(start) > commandTimeoutSecs && !command.isEmpty {
                submitCommand(command)
            }
        default:
            break
        }
    }

    func submitCommand(_ command: String) {
        guard !command.isEmpty else { return }
        DispatchQueue.main.async {
            self.state = .processing
            self.onCommandCaptured?(command)
            // Return to ambient listening after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.state = .listeningForWakePhrase
            }
        }
    }

    private func triggerWakeResponse() {
        HapticFeedback.trigger(.wakeDetected)
    }

    private func restartSessionAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.state != .idle else { return }
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.recognitionTask  = nil
            self.recognitionRequest = nil
            self.startRecognitionSession()
        }
    }

    // MARK: - Permissions

    private func requestPermissions() async -> Bool {
        let micStatus = await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        guard micStatus else { return false }
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        return speechStatus
    }
}

// MARK: - Haptic Feedback Stub

private enum HapticFeedback {
    enum Pattern { case wakeDetected }
    static func trigger(_ pattern: Pattern) {
        // macOS: NSHapticFeedbackManager
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
}
