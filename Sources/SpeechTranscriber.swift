import AVFoundation
import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
    case recognizerUnavailable(String)
    case emptyResult
    case alreadyRunning
    case notRunning

    var errorDescription: String? {
        switch self {
        case let .recognizerUnavailable(localeIdentifier):
            return "Для языка \(localeIdentifier) распознавание речи сейчас недоступно."
        case .emptyResult:
            return "Речь распознана пусто. Попробуйте говорить чуть дольше или громче."
        case .alreadyRunning:
            return "Распознавание уже запущено."
        case .notRunning:
            return "Распознавание не запущено."
        }
    }
}

final class SpeechTranscriber {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var partialResultHandler: ((String) -> Void)?
    private var stopContinuation: CheckedContinuation<String, Error>?
    private var latestTranscript = ""
    private var isStopping = false

    var isRunning: Bool {
        audioEngine != nil
    }

    func start(
        localeIdentifier: String,
        preferOnDevice: Bool,
        onPartialResult: @escaping (String) -> Void
    ) throws {
        guard !isRunning else {
            throw SpeechTranscriberError.alreadyRunning
        }

        let locale = Locale(identifier: localeIdentifier)

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechTranscriberError.recognizerUnavailable(localeIdentifier)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        if preferOnDevice && recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        latestTranscript = ""
        isStopping = false
        partialResultHandler = onPartialResult
        recognitionRequest = request
        audioEngine = engine

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            cleanup()
            throw error
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionEvent(result: result, error: error)
        }
    }

    func stop() async throws -> String {
        guard isRunning else {
            throw SpeechTranscriberError.notRunning
        }

        isStopping = true
        stopAudioCapture()
        recognitionRequest?.endAudio()

        return try await withCheckedThrowingContinuation { continuation in
            stopContinuation = continuation

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.finishIfNeededAfterTimeout()
            }
        }
    }

    func cancel() {
        recognitionTask?.cancel()
        stopAudioCapture()
        finish(with: .failure(SpeechTranscriberError.notRunning))
    }

    private func handleRecognitionEvent(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)

            latestTranscript = transcript
            partialResultHandler?(transcript)

            if result.isFinal {
                if transcript.isEmpty {
                    finish(with: .failure(SpeechTranscriberError.emptyResult))
                } else {
                    finish(with: .success(transcript))
                }
            }
        }

        if let error {
            if isStopping, !latestTranscript.isEmpty {
                finish(with: .success(latestTranscript))
            } else {
                finish(with: .failure(error))
            }
        }
    }

    private func finishIfNeededAfterTimeout() {
        guard stopContinuation != nil else {
            return
        }

        if latestTranscript.isEmpty {
            finish(with: .failure(SpeechTranscriberError.emptyResult))
        } else {
            finish(with: .success(latestTranscript))
        }
    }

    private func stopAudioCapture() {
        guard let audioEngine else {
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    private func finish(with result: Result<String, Error>) {
        guard let continuation = stopContinuation else {
            if case .failure = result {
                cleanup()
            }
            return
        }

        cleanup()

        switch result {
        case let .success(transcript):
            continuation.resume(returning: transcript)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    private func cleanup() {
        stopContinuation = nil
        partialResultHandler = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        isStopping = false
    }
}
