import AVFoundation
import ApplicationServices
import Speech

struct PermissionSnapshot {
    let microphoneGranted: Bool
    let speechGranted: Bool
    let accessibilityGranted: Bool

    var canRecordAndTranscribe: Bool {
        microphoneGranted
    }

    var canAutoType: Bool {
        accessibilityGranted
    }

    var summary: String {
        var missing: [String] = []

        if !microphoneGranted {
            missing.append("Microphone")
        }

        if !accessibilityGranted {
            missing.append("Accessibility")
        }

        if missing.isEmpty {
            return "всё готово"
        }

        return "нужно включить: \(missing.joined(separator: ", "))"
    }
}

final class PermissionsManager {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphoneGranted: hasMicrophoneAccess(),
            speechGranted: hasSpeechAccess(),
            accessibilityGranted: AXIsProcessTrusted()
        )
    }

    func requestOperationalPermissions(promptForAccessibility: Bool) async -> PermissionSnapshot {
        _ = await requestMicrophoneAccessIfNeeded()

        if promptForAccessibility && !AXIsProcessTrusted() {
            promptForAccessibilityIfNeeded()
        }

        return snapshot()
    }

    func promptForAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func hasMicrophoneAccess() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func hasSpeechAccess() -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophoneAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestSpeechAccessIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
