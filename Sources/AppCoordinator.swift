import Cocoa

final class AppCoordinator {
    private let settings = SettingsStore()
    private let permissionsManager = PermissionsManager()
    private let audioRecorder = AudioRecorder()
    private let transcriber = WhisperCLITranscriber()
    private let textInjector = TextInjector()
    private let appUpdater = AppUpdater()
    private let statusItemController = StatusItemController()
    private let overlayWindowController = OverlayWindowController()
    private let transcriptEditorWindowController = TranscriptEditorWindowController()

    private lazy var keyMonitor = KeyMonitor(triggerKey: settings.triggerKey)

    private var permissions = PermissionSnapshot(
        microphoneGranted: false,
        speechGranted: false,
        accessibilityGranted: false
    )

    private var mode: AppMode = .idle
    private var statusText = "Запустите приложение и удерживайте горячую клавишу"
    private var lastTranscript = ""

    func start() {
        wireCallbacks()
        permissions = permissionsManager.snapshot()
        refreshIdleStatus()
        keyMonitor.start()
        render()
    }

    func stop() {
        keyMonitor.stop()
        audioRecorder.cancel()
        overlayWindowController.hide()
        transcriptEditorWindowController.close()
    }

    private func wireCallbacks() {
        keyMonitor.onPressed = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleTriggerPressed()
            }
        }

        keyMonitor.onReleased = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleTriggerReleased()
            }
        }

        statusItemController.onChooseTrigger = { [weak self] triggerKey in
            self?.setTriggerKey(triggerKey)
        }

        statusItemController.onChooseModel = { [weak self] model in
            self?.setWhisperModel(model)
        }

        statusItemController.onChooseOutputMode = { [weak self] outputMode in
            self?.setOutputMode(outputMode)
        }

        statusItemController.onChooseLocale = { [weak self] in
            self?.showLocalePrompt()
        }

        statusItemController.onToggleOnDevice = { [weak self] in
            self?.toggleOnDevice()
        }

        statusItemController.onRequestPermissions = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.requestPermissions()
            }
        }

        statusItemController.onUpdateApp = { [weak self] in
            self?.updateApp()
        }

        statusItemController.onOpenAccessibilitySettings = { [weak self] in
            self?.permissionsManager.promptForAccessibilityIfNeeded()
            self?.openSystemSettings(anchor: "Privacy_Accessibility")
        }

        statusItemController.onOpenMicrophoneSettings = { [weak self] in
            self?.openSystemSettings(anchor: "Privacy_Microphone")
        }

        statusItemController.onOpenSpeechSettings = { [weak self] in
            self?.openSystemSettings(anchor: "Privacy_SpeechRecognition")
        }

        statusItemController.onQuit = {
            NSApp.terminate(nil)
        }

        transcriptEditorWindowController.onInsert = { [weak self] text in
            guard let self else {
                return .unavailable
            }

            let result = self.textInjector.insert(text)
            self.permissions = self.permissionsManager.snapshot()

            switch result {
            case .typed:
                self.mode = .idle
                self.statusText = "Текст вставлен из окна редактора"
            case .copiedToClipboard:
                self.mode = .attention
                self.statusText = "Нет доступа к вставке. Текст скопирован в буфер"
            case .empty:
                self.mode = .attention
                self.statusText = "В окне редактора пока пусто"
            case .unavailable:
                self.mode = .attention
                self.statusText = "Нет доступа к Accessibility для автопечати"
            }

            self.render()
            if self.mode == .idle {
                self.refreshIdleStatus()
                self.render()
            }

            return result
        }
    }

    private func render() {
        let state = StatusViewState(
            mode: mode,
            statusText: statusText,
            lastTranscript: lastTranscript,
            triggerKey: settings.triggerKey,
            localeIdentifier: settings.localeIdentifier,
            whisperModel: settings.whisperModel,
            outputMode: settings.outputMode,
            preferOnDevice: settings.preferOnDevice,
            permissions: permissions
        )

        DispatchQueue.main.async { [weak self] in
            guard self != nil else {
                return
            }

            self?.statusItemController.render(state)
        }
    }

    private func refreshIdleStatus() {
        permissions = permissionsManager.snapshot()

        if !permissions.canRecordAndTranscribe {
            mode = .attention
            statusText = "Нужны разрешения: \(permissions.summary)"
            return
        }

        if settings.outputMode == .instantInsert && !permissions.canAutoType {
            mode = .attention
            statusText = "Можно диктовать, но для автопечати нужен Accessibility"
            return
        }

        mode = .idle
        statusText = settings.outputMode == .editorWindow
            ? "Готово. Текст будет открываться в окне редактора"
            : "Готово. Удерживайте \(settings.triggerKey.title)"
    }

    private func setTriggerKey(_ triggerKey: TriggerKey) {
        settings.triggerKey = triggerKey
        keyMonitor.triggerKey = triggerKey
        refreshIdleStatus()
        render()
    }

    private func setWhisperModel(_ model: WhisperModelOption) {
        settings.whisperModel = model
        mode = .idle
        statusText = "Выбрана модель \(model.title)"
        render()
    }

    private func setOutputMode(_ outputMode: TranscriptionOutputMode) {
        settings.outputMode = outputMode
        refreshIdleStatus()
        statusText = outputMode == .editorWindow
            ? "Режим: через окно редактора"
            : "Режим: моментальная вставка"
        render()
    }

    private func toggleOnDevice() {
        settings.preferOnDevice.toggle()
        refreshIdleStatus()
        render()
    }

    private func showLocalePrompt() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Язык распознавания"
        alert.informativeText = "Введите locale identifier, например ru-RU, en-US, de-DE."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Сохранить")
        alert.addButton(withTitle: "Отмена")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = settings.localeIdentifier
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            settings.localeIdentifier = input.stringValue
            refreshIdleStatus()
            render()
        }
    }

    private func requestPermissions() async {
        permissions = await permissionsManager.requestOperationalPermissions(promptForAccessibility: true)
        refreshIdleStatus()
        render()
    }

    private func updateApp() {
        do {
            try appUpdater.startUpdateAndRelaunch()
            NSApp.terminate(nil)
        } catch {
            mode = .attention
            statusText = describe(error)
            overlayWindowController.showError(statusText)
            render()
        }
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func handleTriggerPressed() async {
        guard !audioRecorder.isRecording, mode != .transcribing else {
            return
        }

        permissions = await permissionsManager.requestOperationalPermissions(promptForAccessibility: false)

        guard permissions.canRecordAndTranscribe else {
            mode = .attention
            statusText = "Нет доступа к микрофону или Speech Recognition"
            render()
            return
        }

        do {
            lastTranscript = ""
            try audioRecorder.start()
            mode = .recording
            statusText = "Слушаю. Отпустите \(settings.triggerKey.title)"
            overlayWindowController.showRecording(triggerKeyTitle: settings.triggerKey.title, transcript: "")
            render()
        } catch {
            mode = .attention
            statusText = describe(error)
            overlayWindowController.showError(statusText)
            render()
        }
    }

    private func handleTriggerReleased() async {
        guard audioRecorder.isRecording else {
            return
        }

        mode = .transcribing
        statusText = "Финализирую текст..."
        overlayWindowController.showTranscribing()
        render()

        do {
            let audioURL = try await audioRecorder.stop()
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let transcript = try await transcriber.transcribe(
                audioURL: audioURL,
                localeIdentifier: settings.localeIdentifier,
                model: settings.whisperModel
            )
            lastTranscript = transcript
            permissions = permissionsManager.snapshot()

            if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mode = .attention
                statusText = "Распознавание вернуло пустой текст"
            } else if settings.outputMode == .editorWindow {
                transcriptEditorWindowController.present(transcript: transcript)
                mode = .idle
                statusText = "Текст открыт в окне редактора"
            } else {
                let injectionResult = textInjector.insert(transcript)

                switch injectionResult {
                case .typed:
                    mode = .idle
                    statusText = "Текст вставлен"
                case .copiedToClipboard:
                    mode = .attention
                    statusText = "Текст скопирован в буфер. Для автопечати включите Accessibility"
                case .empty:
                    mode = .attention
                    statusText = "Распознавание вернуло пустой текст"
                case .unavailable:
                    mode = .attention
                    statusText = "Нет доступа к Accessibility для автопечати"
                }
            }
        } catch {
            mode = .attention
            statusText = describe(error)
        }

        if mode == .attention {
            overlayWindowController.showError(statusText)
        } else {
            overlayWindowController.hide()
        }

        render()

        if mode == .idle {
            refreshIdleStatus()
            render()
        }
    }

    private func describe(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}
