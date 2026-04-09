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

struct WhisperConfiguration: Sendable {
    let modelPath: String
    let language: String
}

struct TranscriptionResult: Sendable {
    let transcriptURL: URL
    let transcriptText: String
    let liveChunkText: String?
    let warnings: [String]
}

private struct WhisperSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

private struct LiveTranscriptSegment {
    let startSample: Int
    let endSample: Int
    let text: String
}

private struct RepetitionIssue: Sendable {
    let repeatedText: String
    let consecutiveCount: Int
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
    private static let sampleRate = 16_000
    private static let liveOverlapSampleCount = sampleRate * 2

    private let context: EmbeddedWhisperContext
    private let store: TranscriptStore
    private let language: String
    private var liveCommittedSegments: [LiveTranscriptSegment] = []

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
            return TranscriptionResult(transcriptURL: transcriptURL, transcriptText: "", liveChunkText: nil, warnings: [])
        }

        let decodedSegments = try context.transcribeSegments(samples: samples, language: language)
        let warning = repetitionWarningMessage(for: decodedSegments.map(\.text))
        let transcriptText = joinWhisperSegmentsRemovingConsecutiveDuplicates(decodedSegments)
        let transcriptURL = store.transcriptURL(for: audioURL)
        try transcriptText.write(to: transcriptURL, atomically: true, encoding: String.Encoding.utf8)

        return TranscriptionResult(
            transcriptURL: transcriptURL,
            transcriptText: transcriptText,
            liveChunkText: nil,
            warnings: warning.map { [$0] } ?? []
        )
    }

    func transcribeLive(audioURL: URL, finalPass: Bool) throws -> TranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw WhisperTranscriptionError.invalidAudioPath(audioURL.path)
        }

        let samples = try decodeWaveFile(audioURL)
        let transcriptURL = store.transcriptURL(for: audioURL)

        guard !samples.isEmpty else {
            liveCommittedSegments = []
            try "".write(to: transcriptURL, atomically: true, encoding: .utf8)
            return TranscriptionResult(transcriptURL: transcriptURL, transcriptText: "", liveChunkText: nil, warnings: [])
        }

        let lastCommittedSample = liveCommittedSegments.last?.endSample ?? 0
        let chunkStartSample = max(0, lastCommittedSample - Self.liveOverlapSampleCount)
        let chunkSamples = Array(samples[chunkStartSample..<samples.count])
        let decodedSegments = try context.transcribeSegments(samples: chunkSamples, language: language)
        let warning = repetitionWarningMessage(for: decodedSegments.map(\.text))
        let liveChunkText = decodedSegments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let absoluteSegments = makeAbsoluteSegments(decodedSegments, chunkStartSample: chunkStartSample, totalSampleCount: samples.count)

        let stableCutoffSample = finalPass
            ? samples.count
            : max(chunkStartSample, samples.count - Self.liveOverlapSampleCount)

        let preservedPrefix = liveCommittedSegments.filter { $0.endSample <= chunkStartSample }
        let stableSegments = absoluteSegments.filter { $0.endSample <= stableCutoffSample }
        let previewSegments = finalPass ? [] : absoluteSegments.filter { $0.endSample > stableCutoffSample }

        liveCommittedSegments = mergeSegments(preservedPrefix + stableSegments)
        let visibleSegments = finalPass
            ? liveCommittedSegments
            : mergeSegments(liveCommittedSegments + previewSegments)
        let transcriptText = joinSegments(removingConsecutiveDuplicates(from: visibleSegments))

        try transcriptText.write(to: transcriptURL, atomically: true, encoding: .utf8)
        return TranscriptionResult(
            transcriptURL: transcriptURL,
            transcriptText: transcriptText,
            liveChunkText: liveChunkText.isEmpty ? nil : liveChunkText,
            warnings: warning.map { [$0] } ?? []
        )
    }

    private func makeAbsoluteSegments(
        _ decodedSegments: [WhisperSegment],
        chunkStartSample: Int,
        totalSampleCount: Int
    ) -> [LiveTranscriptSegment] {
        decodedSegments.compactMap { segment in
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }

            let startSample = min(totalSampleCount, max(chunkStartSample, chunkStartSample + secondsToSamples(segment.startTime)))
            let endSample = min(totalSampleCount, max(startSample, chunkStartSample + secondsToSamples(segment.endTime)))
            guard endSample > startSample else {
                return nil
            }

            return LiveTranscriptSegment(
                startSample: startSample,
                endSample: endSample,
                text: text
            )
        }
    }

    private func mergeSegments(_ segments: [LiveTranscriptSegment]) -> [LiveTranscriptSegment] {
        let sortedSegments = segments.sorted {
            if $0.startSample == $1.startSample {
                return $0.endSample < $1.endSample
            }
            return $0.startSample < $1.startSample
        }

        var merged: [LiveTranscriptSegment] = []
        merged.reserveCapacity(sortedSegments.count)

        for segment in sortedSegments {
            while let last = merged.last, segment.startSample < last.endSample {
                merged.removeLast()
            }

            merged.append(segment)
        }

        return merged
    }

    private func joinSegments(_ segments: [LiveTranscriptSegment]) -> String {
        segments
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func joinWhisperSegmentsRemovingConsecutiveDuplicates(_ segments: [WhisperSegment]) -> String {
        removingConsecutiveDuplicateTexts(segments.map(\.text))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removingConsecutiveDuplicates(from segments: [LiveTranscriptSegment]) -> [LiveTranscriptSegment] {
        var deduplicated: [LiveTranscriptSegment] = []
        deduplicated.reserveCapacity(segments.count)

        var previousKey: String?
        for segment in segments {
            let key = canonicalTextKey(for: segment.text)
            guard !key.isEmpty else {
                continue
            }

            if key == previousKey {
                continue
            }

            deduplicated.append(segment)
            previousKey = key
        }

        return deduplicated
    }

    private func removingConsecutiveDuplicateTexts(_ texts: [String]) -> [String] {
        var deduplicated: [String] = []
        deduplicated.reserveCapacity(texts.count)

        var previousKey: String?
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = canonicalTextKey(for: trimmed)
            guard !key.isEmpty else {
                continue
            }

            if key == previousKey {
                continue
            }

            deduplicated.append(trimmed)
            previousKey = key
        }

        return deduplicated
    }

    private func repetitionWarningMessage(for texts: [String]) -> String? {
        guard let issue = detectPathologicalRepetition(in: texts) else {
            return nil
        }
        return "Detected repeated Whisper segment (\(issue.consecutiveCount)x): \"\(issue.repeatedText)\". Duplicates were collapsed in transcript output."
    }

    private func detectPathologicalRepetition(in texts: [String]) -> RepetitionIssue? {
        let minimumCharactersToFlag = 12
        let repetitionThreshold = 6

        var previousKey: String?
        var previousText: String?
        var consecutiveCount = 0

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = canonicalTextKey(for: trimmed)
            guard !key.isEmpty else {
                continue
            }

            if key.count < minimumCharactersToFlag {
                previousKey = key
                previousText = trimmed
                consecutiveCount = 1
                continue
            }

            if key == previousKey {
                consecutiveCount += 1
            } else {
                previousKey = key
                previousText = trimmed
                consecutiveCount = 1
            }

            if consecutiveCount >= repetitionThreshold {
                return RepetitionIssue(
                    repeatedText: previousText ?? trimmed,
                    consecutiveCount: consecutiveCount
                )
            }
        }

        return nil
    }

    private func canonicalTextKey(for text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func secondsToSamples(_ seconds: TimeInterval) -> Int {
        Int((seconds * Double(Self.sampleRate)).rounded())
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
        try transcribeSegments(samples: samples, language: language)
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate func transcribeSegments(samples: [Float], language: String) throws -> [WhisperSegment] {
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
        var segments: [WhisperSegment] = []
        segments.reserveCapacity(Int(segmentCount))

        for index in 0..<segmentCount {
            segments.append(
                WhisperSegment(
                    startTime: TimeInterval(whisper_full_get_segment_t0(context, index)) * 0.01,
                    endTime: TimeInterval(whisper_full_get_segment_t1(context, index)) * 0.01,
                    text: String(cString: whisper_full_get_segment_text(context, index))
                )
            )
        }

        return segments
    }
}
