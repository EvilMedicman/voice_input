import Cocoa

enum AppUpdaterError: LocalizedError {
    case projectInstallScriptMissing(String)
    case shellLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .projectInstallScriptMissing(path):
            return "Не найден скрипт обновления по пути \(path)."
        case let .shellLaunchFailed(message):
            return "Не удалось запустить обновление: \(message)"
        }
    }
}

final class AppUpdater {
    private let installScriptURL: URL
    private let appPath: String
    private let logURL: URL

    init(
        installScriptURL: URL = URL(fileURLWithPath: "/Users/ivan/Desktop/Рабочие файлы/Голосовой ввод/install.sh"),
        appPath: String = "/Applications/VoiceInput.app",
        logURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("voiceinput-update.log")
    ) {
        self.installScriptURL = installScriptURL
        self.appPath = appPath
        self.logURL = logURL
    }

    func canUpdateFromProject() -> Bool {
        FileManager.default.isExecutableFile(atPath: installScriptURL.path)
    }

    func startUpdateAndRelaunch() throws {
        guard canUpdateFromProject() else {
            throw AppUpdaterError.projectInstallScriptMissing(installScriptURL.path)
        }

        let escapedScriptPath = shellEscape(installScriptURL.path)
        let escapedAppPath = shellEscape(appPath)
        let escapedLogPath = shellEscape(logURL.path)
        let command = "nohup /bin/zsh -lc \"sleep 1; \(escapedScriptPath); while pgrep -x VoiceInput >/dev/null; do sleep 1; done; open -a \(escapedAppPath)\" > \(escapedLogPath) 2>&1 &"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        do {
            try process.run()
        } catch {
            throw AppUpdaterError.shellLaunchFailed(error.localizedDescription)
        }
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
