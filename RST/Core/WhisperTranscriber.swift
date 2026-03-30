import Foundation
import whisper

enum WhisperTranscriptionError: LocalizedError {
    case invalidModelPath(String)
    case invalidAudioPath(String)
    case failedToInitializeContext(String)
    case failedToTranscribe

    var errorDescription: String? {
        switch self {
        case .invalidModelPath(let path):
            return "Whisper model file was not found at \(path)."
        case .invalidAudioPath(let path):
            return "Audio file was not found at \(path)."
        case .failedToInitializeContext(let path):
            return "Failed to initialize embedded Whisper with model \(path)."
        case .failedToTranscribe:
            return "Embedded Whisper failed to transcribe the recording."
        }
    }
}

struct WhisperConfiguration {
    let modelPath: String
    let language: String
}

struct TranscriptionResult {
    let transcriptURL: URL
    let transcriptText: String
}

struct WhisperTranscriber {
    let fileManager: FileManager
    let store: TranscriptStore

    init(fileManager: FileManager = .default, store: TranscriptStore = TranscriptStore()) {
        self.fileManager = fileManager
        self.store = store
    }

    func makeSession(configuration: WhisperConfiguration) throws -> WhisperTranscriptionSession {
        guard fileManager.fileExists(atPath: configuration.modelPath) else {
            throw WhisperTranscriptionError.invalidModelPath(configuration.modelPath)
        }

        let context = try EmbeddedWhisperContext.create(modelPath: configuration.modelPath)
        return WhisperTranscriptionSession(
            context: context,
            store: store,
            language: normalizedLanguage(configuration.language)
        )
    }

    func transcribe(audioURL: URL, configuration: WhisperConfiguration) throws -> TranscriptionResult {
        let session = try makeSession(configuration: configuration)
        return try session.transcribe(audioURL: audioURL)
    }

    private func normalizedLanguage(_ language: String) -> String {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "auto" : trimmed
    }
}

final class WhisperTranscriptionSession: @unchecked Sendable {
    private let context: EmbeddedWhisperContext
    private let store: TranscriptStore
    private let language: String

    init(
        context: EmbeddedWhisperContext,
        store: TranscriptStore,
        language: String
    ) {
        self.context = context
        self.store = store
        self.language = language
    }

    func transcribe(audioURL: URL) throws -> TranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperTranscriptionError.invalidAudioPath(audioURL.path)
        }

        let samples = try decodeWaveFile(audioURL)
        guard !samples.isEmpty else {
            let transcriptURL = store.transcriptURL(for: audioURL)
            try "".write(to: transcriptURL, atomically: true, encoding: .utf8)
            return TranscriptionResult(transcriptURL: transcriptURL, transcriptText: "")
        }

        let transcriptText = try context.transcribe(samples: samples, language: language)
        let transcriptURL = store.transcriptURL(for: audioURL)
        try transcriptText.write(to: transcriptURL, atomically: true, encoding: .utf8)

        return TranscriptionResult(
            transcriptURL: transcriptURL,
            transcriptText: transcriptText
        )
    }
}

final class EmbeddedWhisperContext: @unchecked Sendable {
    private let context: OpaquePointer

    private init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    static func create(modelPath: String) throws -> EmbeddedWhisperContext {
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true

        guard let context = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperTranscriptionError.failedToInitializeContext(modelPath)
        }

        return EmbeddedWhisperContext(context: context)
    }

    func transcribe(samples: [Float], language: String) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false

        let status = language.withCString { languageCString in
            params.language = languageCString
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard status == 0 else {
            throw WhisperTranscriptionError.failedToTranscribe
        }

        let segmentCount = whisper_full_n_segments(context)
        var text = ""
        for index in 0..<segmentCount {
            text += String(cString: whisper_full_get_segment_text(context, index))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
