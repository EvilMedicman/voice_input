import Foundation

final class SettingsStore {
    private enum Keys {
        static let triggerKey = "triggerKey"
        static let localeIdentifier = "localeIdentifier"
        static let preferOnDevice = "preferOnDevice"
        static let whisperModel = "whisperModel"
        static let outputMode = "outputMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.triggerKey: TriggerKey.rightOption.rawValue,
            Keys.localeIdentifier: "ru-RU",
            Keys.preferOnDevice: true,
            Keys.whisperModel: WhisperModelOption.base.rawValue,
            Keys.outputMode: TranscriptionOutputMode.editorWindow.rawValue
        ])
    }

    var triggerKey: TriggerKey {
        get {
            let rawValue = defaults.string(forKey: Keys.triggerKey) ?? TriggerKey.rightOption.rawValue
            return TriggerKey(rawValue: rawValue) ?? .rightOption
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.triggerKey)
        }
    }

    var localeIdentifier: String {
        get {
            defaults.string(forKey: Keys.localeIdentifier) ?? "ru-RU"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? "ru-RU" : trimmed, forKey: Keys.localeIdentifier)
        }
    }

    var preferOnDevice: Bool {
        get {
            defaults.bool(forKey: Keys.preferOnDevice)
        }
        set {
            defaults.set(newValue, forKey: Keys.preferOnDevice)
        }
    }

    var whisperModel: WhisperModelOption {
        get {
            let rawValue = defaults.string(forKey: Keys.whisperModel) ?? WhisperModelOption.base.rawValue
            return WhisperModelOption(rawValue: rawValue) ?? .base
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.whisperModel)
        }
    }

    var outputMode: TranscriptionOutputMode {
        get {
            let rawValue = defaults.string(forKey: Keys.outputMode) ?? TranscriptionOutputMode.editorWindow.rawValue
            return TranscriptionOutputMode(rawValue: rawValue) ?? .editorWindow
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.outputMode)
        }
    }
}
