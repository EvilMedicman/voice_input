import Foundation

enum WhisperCLITranscriberError: LocalizedError {
    case cliMissing(String)
    case modelMissing(String)
    case outputMissing
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case let .cliMissing(path):
            return "Не найден whisper-cli по пути \(path)."
        case let .modelMissing(path):
            return "Не найдена модель Whisper по пути \(path)."
        case .outputMissing:
            return "whisper.cpp отработал без текста на выходе."
        case let .processFailed(message):
            return "whisper.cpp завершился с ошибкой: \(message)"
        }
    }
}

final class WhisperCLITranscriber {
    private let cliURL: URL
    private let modelsDirectoryURL: URL

    init(cliURL: URL? = nil, modelsDirectoryURL: URL? = nil) {
        self.cliURL = cliURL ?? Self.defaultCLIURL()
        self.modelsDirectoryURL = modelsDirectoryURL ?? Self.defaultModelsDirectoryURL()
    }

    func transcribe(audioURL: URL, localeIdentifier: String, model: WhisperModelOption) async throws -> String {
        let modelURL = modelsDirectoryURL.appendingPathComponent(model.fileName)

        guard FileManager.default.isExecutableFile(atPath: cliURL.path) else {
            throw WhisperCLITranscriberError.cliMissing(cliURL.path)
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw WhisperCLITranscriberError.modelMissing(modelURL.path)
        }

        let outputBaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let outputTextURL = outputBaseURL.appendingPathExtension("txt")
        let languageCode = localeIdentifier.split(separator: "-").first.map(String.init) ?? "ru"

        do {
            _ = try await runProcess(
                executableURL: cliURL,
                arguments: [
                    "--model", modelURL.path,
                    "--file", audioURL.path,
                    "--language", languageCode,
                    "--no-timestamps",
                    "--no-prints",
                    "--output-txt",
                    "--output-file", outputBaseURL.path,
                    "--threads", "4",
                    "--processors", "1",
                    "--no-gpu"
                ]
            )
        } catch let error as WhisperCLITranscriberError {
            throw error
        } catch {
            throw WhisperCLITranscriberError.processFailed(error.localizedDescription)
        }

        guard let data = try? Data(contentsOf: outputTextURL),
              let text = String(data: data, encoding: .utf8)?
              .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw WhisperCLITranscriberError.outputMissing
        }

        try? FileManager.default.removeItem(at: outputTextURL)

        return text
    }

    private func runProcess(executableURL: URL, arguments: [String]) async throws -> (String, String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = processEnvironment(for: executableURL)

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdoutData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
                let stderrData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: (stdout, stderr))
                } else {
                    let message = [stderr, stdout]
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: WhisperCLITranscriberError.processFailed(message.isEmpty ? "unknown error" : message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func processEnvironment(for executableURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let libraryDirectory = executableURL.deletingLastPathComponent().path
        let existingPath = environment["DYLD_LIBRARY_PATH"] ?? ""
        environment["DYLD_LIBRARY_PATH"] = existingPath.isEmpty ? libraryDirectory : "\(libraryDirectory):\(existingPath)"
        return environment
    }

    private static func defaultCLIURL() -> URL {
        if let bundledURL = Bundle.main.resourceURL?.appendingPathComponent("WhisperCLI/whisper-cli"),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL
        }

        return URL(fileURLWithPath: "/Users/ivan/Desktop/Рабочие файлы/Голосовой ввод/Vendor/whisper.cpp/build/bin/whisper-cli")
    }

    private static func defaultModelsDirectoryURL() -> URL {
        if let bundledURL = Bundle.main.resourceURL?.appendingPathComponent("Models"),
           FileManager.default.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }

        return URL(fileURLWithPath: "/Users/ivan/Desktop/Рабочие файлы/Голосовой ввод/Models")
    }
}
