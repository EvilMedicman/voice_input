import AVFoundation
import AudioToolbox
import Foundation

enum AudioRecorderError: LocalizedError {
    case startFailed
    case notRecording
    case stopFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "Не удалось начать запись."
        case .notRecording:
            return "Запись уже остановлена."
        case .stopFailed:
            return "Не удалось корректно завершить запись."
        }
    }
}

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var stopContinuation: CheckedContinuation<URL, Error>?
    private var pendingStopURL: URL?

    var isRecording: Bool {
        recorder != nil
    }

    func start() throws {
        guard recorder == nil else {
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecorderError.startFailed
        }

        self.recorder = recorder
        self.currentURL = url
    }

    func stop() async throws -> URL {
        guard let recorder, let url = currentURL else {
            throw AudioRecorderError.notRecording
        }

        return try await withCheckedThrowingContinuation { continuation in
            stopContinuation = continuation
            pendingStopURL = url
            recorder.stop()
            self.recorder = nil
            currentURL = nil
        }
    }

    func cancel() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        currentURL = nil
        finishStop(with: .failure(AudioRecorderError.stopFailed))
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag, let url = pendingStopURL {
            finishStop(with: .success(url))
        } else {
            finishStop(with: .failure(AudioRecorderError.stopFailed))
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        finishStop(with: .failure(error ?? AudioRecorderError.stopFailed))
    }

    private func finishStop(with result: Result<URL, Error>) {
        pendingStopURL = nil

        guard let continuation = stopContinuation else {
            return
        }

        stopContinuation = nil

        switch result {
        case let .success(url):
            continuation.resume(returning: url)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
