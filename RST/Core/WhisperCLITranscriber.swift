import Foundation

enum WhisperCLIError: LocalizedError {
    case invalidCLIPath(String)
    case invalidModelPath(String)
    case invalidAudioPath(String)
    case processFailure(String)
    case missingTranscript(URL)

    var errorDescription: String? {
        switch self {
        case .invalidCLIPath(let path):
            return "whisper-cli executable was not found at \(path)."
        case .invalidModelPath(let path):
            return "Whisper model file was not found at \(path)."
        case .invalidAudioPath(let path):
            return "Audio file was not found at \(path)."
        case .processFailure(let message):
            return "Local Whisper transcription failed.\n\(message)"
        case .missingTranscript(let url):
            return "whisper-cli finished but did not create the transcript file at \(url.path)."
        }
    }
}

struct WhisperConfiguration {
    let executablePath: String
    let modelPath: String
    let language: String
}

struct TranscriptionResult {
    let transcriptURL: URL
    let transcriptText: String
    let standardOutput: String
    let standardError: String
}

struct WhisperCLITranscriber {
    let fileManager: FileManager
    let store: TranscriptStore

    init(fileManager: FileManager = .default, store: TranscriptStore = TranscriptStore()) {
        self.fileManager = fileManager
        self.store = store
    }

    func transcribe(audioURL: URL, configuration: WhisperConfiguration) async throws -> TranscriptionResult {
        guard fileManager.isExecutableFile(atPath: configuration.executablePath) else {
            throw WhisperCLIError.invalidCLIPath(configuration.executablePath)
        }

        guard fileManager.fileExists(atPath: configuration.modelPath) else {
            throw WhisperCLIError.invalidModelPath(configuration.modelPath)
        }

        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw WhisperCLIError.invalidAudioPath(audioURL.path)
        }

        let outputBase = audioURL
            .deletingLastPathComponent()
            .appendingPathComponent(audioURL.deletingPathExtension().lastPathComponent + "-transcript")

        let result = try await runProcess(
            executableURL: URL(fileURLWithPath: configuration.executablePath),
            arguments: [
                "-m", configuration.modelPath,
                "-f", audioURL.path,
                "-l", configuration.language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "auto" : configuration.language,
                "-otxt",
                "-oj",
                "-of", outputBase.path,
                "-np",
            ]
        )

        let transcriptURL = store.transcriptURL(for: audioURL)
        guard fileManager.fileExists(atPath: transcriptURL.path) else {
            throw WhisperCLIError.missingTranscript(transcriptURL)
        }

        let transcriptText = try String(contentsOf: transcriptURL, encoding: .utf8)
        return TranscriptionResult(
            transcriptURL: transcriptURL,
            transcriptText: transcriptText,
            standardOutput: result.output,
            standardError: result.error
        )
    }

    private func runProcess(executableURL: URL, arguments: [String]) async throws -> (output: String, error: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData, as: UTF8.self)
                let error = String(decoding: errorData, as: UTF8.self)

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: WhisperCLIError.processFailure(error.isEmpty ? output : error))
                    return
                }

                continuation.resume(returning: (output, error))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: WhisperCLIError.processFailure(error.localizedDescription))
            }
        }
    }
}
