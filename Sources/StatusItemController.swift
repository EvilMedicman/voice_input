import Cocoa

enum AppMode {
    case idle
    case recording
    case transcribing
    case attention
}

struct StatusViewState {
    let mode: AppMode
    let statusText: String
    let lastTranscript: String
    let triggerKey: TriggerKey
    let localeIdentifier: String
    let whisperModel: WhisperModelOption
    let outputMode: TranscriptionOutputMode
    let preferOnDevice: Bool
    let permissions: PermissionSnapshot
}

final class StatusItemController: NSObject {
    var onChooseTrigger: ((TriggerKey) -> Void)?
    var onChooseModel: ((WhisperModelOption) -> Void)?
    var onChooseOutputMode: ((TranscriptionOutputMode) -> Void)?
    var onChooseLocale: (() -> Void)?
    var onToggleOnDevice: (() -> Void)?
    var onRequestPermissions: (() -> Void)?
    var onUpdateApp: (() -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var onOpenMicrophoneSettings: (() -> Void)?
    var onOpenSpeechSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private let statusMenuItem = NSMenuItem(title: "Статус: ...", action: nil, keyEquivalent: "")
    private let triggerHintMenuItem = NSMenuItem(title: "Удерживайте: ...", action: nil, keyEquivalent: "")
    private let transcriptMenuItem = NSMenuItem(title: "Последний текст: пока пусто", action: nil, keyEquivalent: "")
    private let permissionsMenuItem = NSMenuItem(title: "Разрешения: ...", action: nil, keyEquivalent: "")

    private let triggerParentItem = NSMenuItem(title: "Клавиша запуска", action: nil, keyEquivalent: "")
    private let triggerMenu = NSMenu()
    private let modelParentItem = NSMenuItem(title: "Модель Whisper", action: nil, keyEquivalent: "")
    private let modelMenu = NSMenu()
    private let outputParentItem = NSMenuItem(title: "Режим вывода", action: nil, keyEquivalent: "")
    private let outputMenu = NSMenu()

    private lazy var localeMenuItem = NSMenuItem(
        title: "Язык распознавания...",
        action: #selector(didChooseLocale),
        keyEquivalent: ""
    )

    private lazy var onDeviceMenuItem = NSMenuItem(
        title: "Предпочитать on-device",
        action: #selector(didToggleOnDevice),
        keyEquivalent: ""
    )

    private lazy var requestPermissionsMenuItem = NSMenuItem(
        title: "Запросить разрешения",
        action: #selector(didRequestPermissions),
        keyEquivalent: ""
    )

    private lazy var updateAppMenuItem = NSMenuItem(
        title: "Обновить приложение",
        action: #selector(didUpdateApp),
        keyEquivalent: ""
    )

    private lazy var accessibilityMenuItem = NSMenuItem(
        title: "Открыть Accessibility",
        action: #selector(didOpenAccessibilitySettings),
        keyEquivalent: ""
    )

    private lazy var microphoneMenuItem = NSMenuItem(
        title: "Открыть Microphone",
        action: #selector(didOpenMicrophoneSettings),
        keyEquivalent: ""
    )

    private lazy var speechMenuItem = NSMenuItem(
        title: "Открыть Speech Recognition",
        action: #selector(didOpenSpeechSettings),
        keyEquivalent: ""
    )

    private lazy var quitMenuItem = NSMenuItem(
        title: "Выйти",
        action: #selector(didQuit),
        keyEquivalent: "q"
    )

    override init() {
        super.init()
        configure()
    }

    func render(_ state: StatusViewState) {
        statusMenuItem.title = "Статус: \(state.statusText)"
        triggerHintMenuItem.title = "Удерживайте: \(state.triggerKey.title)"
        transcriptMenuItem.title = "Последний текст: \(shorten(state.lastTranscript.isEmpty ? "пока пусто" : state.lastTranscript))"
        permissionsMenuItem.title = "Разрешения: \(state.permissions.summary)"
        localeMenuItem.title = "Язык распознавания: \(state.localeIdentifier)"
        onDeviceMenuItem.state = state.preferOnDevice ? .on : .off
        modelParentItem.title = "Модель Whisper: \(state.whisperModel.title)"
        outputParentItem.title = "Режим вывода: \(state.outputMode.shortTitle)"

        for item in triggerMenu.items {
            guard let rawValue = item.representedObject as? String else {
                continue
            }

            item.state = rawValue == state.triggerKey.rawValue ? .on : .off
        }

        for item in modelMenu.items {
            guard let rawValue = item.representedObject as? String else {
                continue
            }

            item.state = rawValue == state.whisperModel.rawValue ? .on : .off
        }

        for item in outputMenu.items {
            guard let rawValue = item.representedObject as? String else {
                continue
            }

            item.state = rawValue == state.outputMode.rawValue ? .on : .off
        }

        updateButton(mode: state.mode, statusText: state.statusText)
    }

    private func configure() {
        statusMenuItem.isEnabled = false
        triggerHintMenuItem.isEnabled = false
        transcriptMenuItem.isEnabled = false
        permissionsMenuItem.isEnabled = false

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            updateButton(mode: .idle, statusText: "Готово")
        }

        localeMenuItem.target = self
        onDeviceMenuItem.target = self
        requestPermissionsMenuItem.target = self
        updateAppMenuItem.target = self
        accessibilityMenuItem.target = self
        microphoneMenuItem.target = self
        speechMenuItem.target = self
        quitMenuItem.target = self

        TriggerKey.allCases.forEach { trigger in
            let item = NSMenuItem(title: trigger.title, action: #selector(didChooseTrigger(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = trigger.rawValue
            triggerMenu.addItem(item)
        }

        WhisperModelOption.allCases.forEach { model in
            let item = NSMenuItem(title: model.menuTitle, action: #selector(didChooseModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model.rawValue
            modelMenu.addItem(item)
        }

        TranscriptionOutputMode.allCases.forEach { outputMode in
            let item = NSMenuItem(title: outputMode.menuTitle, action: #selector(didChooseOutputMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = outputMode.rawValue
            outputMenu.addItem(item)
        }

        menu.addItem(statusMenuItem)
        menu.addItem(triggerHintMenuItem)
        menu.addItem(transcriptMenuItem)
        menu.addItem(permissionsMenuItem)
        menu.addItem(.separator())

        menu.addItem(triggerParentItem)
        menu.setSubmenu(triggerMenu, for: triggerParentItem)
        menu.addItem(modelParentItem)
        menu.setSubmenu(modelMenu, for: modelParentItem)
        menu.addItem(outputParentItem)
        menu.setSubmenu(outputMenu, for: outputParentItem)
        menu.addItem(localeMenuItem)
        menu.addItem(onDeviceMenuItem)
        menu.addItem(.separator())

        menu.addItem(requestPermissionsMenuItem)
        menu.addItem(updateAppMenuItem)
        menu.addItem(accessibilityMenuItem)
        menu.addItem(microphoneMenuItem)
        menu.addItem(speechMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    private func updateButton(mode: AppMode, statusText: String) {
        guard let button = statusItem.button else {
            return
        }

        let symbolName: String

        switch mode {
        case .idle:
            symbolName = "mic"
        case .recording:
            symbolName = "record.circle.fill"
        case .transcribing:
            symbolName = "ellipsis.circle"
        case .attention:
            symbolName = "exclamationmark.circle"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Voice input") {
            image.isTemplate = mode != .recording
            button.image = image
        } else {
            button.image = nil
        }

        switch mode {
        case .idle:
            button.title = ""
        case .recording:
            button.title = " REC"
        case .transcribing:
            button.title = " ..."
        case .attention:
            button.title = " !"
        }

        button.toolTip = statusText
    }

    private func shorten(_ value: String) -> String {
        let compact = value.replacingOccurrences(of: "\n", with: " ")

        if compact.count <= 90 {
            return compact
        }

        return String(compact.prefix(87)) + "..."
    }

    @objc private func didChooseTrigger(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let trigger = TriggerKey(rawValue: rawValue) else {
            return
        }

        onChooseTrigger?(trigger)
    }

    @objc private func didChooseModel(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let model = WhisperModelOption(rawValue: rawValue) else {
            return
        }

        onChooseModel?(model)
    }

    @objc private func didChooseOutputMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let outputMode = TranscriptionOutputMode(rawValue: rawValue) else {
            return
        }

        onChooseOutputMode?(outputMode)
    }

    @objc private func didChooseLocale() {
        onChooseLocale?()
    }

    @objc private func didToggleOnDevice() {
        onToggleOnDevice?()
    }

    @objc private func didRequestPermissions() {
        onRequestPermissions?()
    }

    @objc private func didUpdateApp() {
        onUpdateApp?()
    }

    @objc private func didOpenAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    @objc private func didOpenMicrophoneSettings() {
        onOpenMicrophoneSettings?()
    }

    @objc private func didOpenSpeechSettings() {
        onOpenSpeechSettings?()
    }

    @objc private func didQuit() {
        onQuit?()
    }
}
