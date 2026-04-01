import Foundation
import llama

enum LlamaSummaryError: LocalizedError {
    case invalidModelPath(String)
    case failedToLoadModel(String)
    case failedToCreateContext(String)
    case missingVocabulary
    case promptTooLong(Int, Int)
    case failedToDecode(String)
    case failedToApplyTemplate
    case failedToReadEmbedding
    case failedToSampleToken
    case failedToConvertToken
    case emptySummary

    var errorDescription: String? {
        switch self {
        case .invalidModelPath(let path):
            return "llama.cpp model file was not found at \(path)."
        case .failedToLoadModel(let path):
            return "Failed to load llama.cpp model at \(path)."
        case .failedToCreateContext(let path):
            return "Failed to create llama.cpp context for model \(path)."
        case .missingVocabulary:
            return "The llama.cpp model did not expose a vocabulary."
        case .promptTooLong(let tokenCount, let limit):
            return "The prompt requires \(tokenCount) tokens, which exceeds the context limit of \(limit)."
        case .failedToDecode(let details):
            return "llama.cpp failed during inference. \(details)"
        case .failedToApplyTemplate:
            return "llama.cpp could not apply the model chat template."
        case .failedToReadEmbedding:
            return "llama.cpp did not return an embedding vector."
        case .failedToSampleToken:
            return "llama.cpp failed to sample the next token."
        case .failedToConvertToken:
            return "llama.cpp failed to convert a generated token into text."
        case .emptySummary:
            return "llama.cpp returned an empty summary."
        }
    }
}

struct LlamaSummaryConfiguration: Sendable {
    let embeddingModelPath: String
    let summaryModelPath: String

    var isConfigured: Bool {
        !embeddingModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !summaryModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SummaryResult: Sendable {
    let summaryURL: URL
    let summaryText: String
}

struct LlamaSummaryService {
    private let fileManager: FileManager
    private let store: TranscriptStore

    init(
        fileManager: FileManager = .default,
        store: TranscriptStore = TranscriptStore()
    ) {
        self.fileManager = fileManager
        self.store = store
    }

    func summarize(
        transcriptText: String,
        audioURL: URL,
        configuration: LlamaSummaryConfiguration
    ) throws -> SummaryResult {
        EmbeddedLlamaRuntime.bootstrap()

        let normalizedTranscript = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryURL = store.summaryURL(for: audioURL)
        guard !normalizedTranscript.isEmpty else {
            try "".write(to: summaryURL, atomically: true, encoding: .utf8)
            return SummaryResult(summaryURL: summaryURL, summaryText: "")
        }

        let normalizedConfiguration = try validate(configuration)
        let chunks = makeChunks(from: normalizedTranscript)

        let selectedContext: String
        if chunks.count <= 1 {
            selectedContext = normalizedTranscript
        } else {
            let embedder = try EmbeddedLlamaEmbedder(modelPath: normalizedConfiguration.embeddingModelPath)
            let selectedIndexes = try selectRepresentativeChunks(from: chunks, using: embedder)
            selectedContext = selectedIndexes
                .sorted()
                .map { chunks[$0] }
                .joined(separator: "\n\n")
        }

        let summarizer = try EmbeddedLlamaGenerator(modelPath: normalizedConfiguration.summaryModelPath)
        let summaryText = try summarizer.generateSummary(for: selectedContext)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summaryText.isEmpty else {
            throw LlamaSummaryError.emptySummary
        }

        try summaryText.write(to: summaryURL, atomically: true, encoding: .utf8)
        return SummaryResult(summaryURL: summaryURL, summaryText: summaryText)
    }

    private func validate(_ configuration: LlamaSummaryConfiguration) throws -> LlamaSummaryConfiguration {
        let embeddingModelPath = configuration.embeddingModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryModelPath = configuration.summaryModelPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !embeddingModelPath.isEmpty, fileManager.fileExists(atPath: embeddingModelPath) else {
            throw LlamaSummaryError.invalidModelPath(embeddingModelPath.isEmpty ? "(empty)" : embeddingModelPath)
        }

        guard !summaryModelPath.isEmpty, fileManager.fileExists(atPath: summaryModelPath) else {
            throw LlamaSummaryError.invalidModelPath(summaryModelPath.isEmpty ? "(empty)" : summaryModelPath)
        }

        return LlamaSummaryConfiguration(
            embeddingModelPath: embeddingModelPath,
            summaryModelPath: summaryModelPath
        )
    }

    private func makeChunks(from transcript: String) -> [String] {
        let paragraphs = transcript
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var current = ""
        let maxCharacters = 1200

        for paragraph in paragraphs {
            let candidate = current.isEmpty ? paragraph : current + "\n" + paragraph
            if candidate.count <= maxCharacters {
                current = candidate
                continue
            }

            if !current.isEmpty {
                chunks.append(current)
            }

            if paragraph.count <= maxCharacters {
                current = paragraph
                continue
            }

            var startIndex = paragraph.startIndex
            while startIndex < paragraph.endIndex {
                let endIndex = paragraph.index(startIndex, offsetBy: maxCharacters, limitedBy: paragraph.endIndex) ?? paragraph.endIndex
                let slice = paragraph[startIndex..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if !slice.isEmpty {
                    chunks.append(String(slice))
                }
                startIndex = endIndex
            }
            current = ""
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.isEmpty ? [transcript] : chunks
    }

    private func selectRepresentativeChunks(
        from chunks: [String],
        using embedder: EmbeddedLlamaEmbedder
    ) throws -> [Int] {
        let embeddings = try chunks.map { try embedder.embed(text: $0) }
        guard let first = embeddings.first else {
            return []
        }

        var centroid = Array(repeating: Float.zero, count: first.count)
        for embedding in embeddings {
            for index in embedding.indices {
                centroid[index] += embedding[index]
            }
        }

        let scale = Float(1) / Float(embeddings.count)
        for index in centroid.indices {
            centroid[index] *= scale
        }

        return embeddings.enumerated()
            .map { (index: $0.offset, score: cosineSimilarity($0.element, centroid)) }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.index < rhs.index
                }
                return lhs.score > rhs.score
            }
            .prefix(min(4, embeddings.count))
            .map(\.index)
    }

    private func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return -.infinity
        }

        var dot: Float = 0
        var lhsNorm: Float = 0
        var rhsNorm: Float = 0

        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }

        guard lhsNorm > 0, rhsNorm > 0 else {
            return -.infinity
        }

        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }
}

private enum EmbeddedLlamaRuntime {
    private static let initializeOnce: Void = {
        llama_backend_init()
        ggml_backend_load_all()
    }()

    static func bootstrap() {
        _ = initializeOnce
    }
}

private final class EmbeddedLlamaEmbedder {
    private let modelPath: String
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer

    init(modelPath: String) throws {
        self.modelPath = modelPath

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 999

        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw LlamaSummaryError.failedToLoadModel(modelPath)
        }
        self.model = model

        guard let vocab = llama_model_get_vocab(model) else {
            llama_model_free(model)
            throw LlamaSummaryError.missingVocabulary
        }
        self.vocab = vocab

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_batch = 2048
        contextParams.n_ubatch = 2048
        contextParams.n_seq_max = 1
        contextParams.n_threads = threadCount()
        contextParams.n_threads_batch = threadCount()
        contextParams.pooling_type = LLAMA_POOLING_TYPE_MEAN
        contextParams.embeddings = true

        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw LlamaSummaryError.failedToCreateContext(modelPath)
        }
        self.context = context
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    func embed(text: String) throws -> [Float] {
        let tokens = try tokenize(text: text, addBOS: true, parseSpecial: true)
        let nCtx = Int(llama_n_ctx(context))
        guard tokens.count <= nCtx else {
            throw LlamaSummaryError.promptTooLong(tokens.count, nCtx)
        }

        llama_memory_clear(llama_get_memory(context), true)
        llama_set_embeddings(context, true)

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer {
            llama_batch_free(batch)
        }

        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = 1
        }
        batch.n_tokens = Int32(tokens.count)

        let result = llama_decode(context, batch)
        guard result == 0 else {
            throw LlamaSummaryError.failedToDecode("embedding decode returned \(result)")
        }

        let embeddingSize = Int(llama_model_n_embd_out(model))
        guard let rawEmbedding = llama_get_embeddings_seq(context, 0) else {
            throw LlamaSummaryError.failedToReadEmbedding
        }

        let buffer = UnsafeBufferPointer(start: rawEmbedding, count: embeddingSize)
        return Array(buffer)
    }

    private func tokenize(text: String, addBOS: Bool, parseSpecial: Bool) throws -> [llama_token] {
        let estimatedCount = max(text.utf8.count + (addBOS ? 1 : 0) + 8, 32)
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: estimatedCount)
        defer {
            tokens.deallocate()
        }

        let tokenCount = llama_tokenize(vocab, text, Int32(text.utf8.count), tokens, Int32(estimatedCount), addBOS, parseSpecial)
        if tokenCount < 0 {
            let requiredCount = Int(-tokenCount)
            let resized = UnsafeMutablePointer<llama_token>.allocate(capacity: requiredCount)
            defer {
                resized.deallocate()
            }
            let actualCount = llama_tokenize(vocab, text, Int32(text.utf8.count), resized, Int32(requiredCount), addBOS, parseSpecial)
            return Array(UnsafeBufferPointer(start: resized, count: Int(actualCount)))
        }

        return Array(UnsafeBufferPointer(start: tokens, count: Int(tokenCount)))
    }
}

private final class EmbeddedLlamaGenerator {
    private let modelPath: String
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>

    init(modelPath: String) throws {
        self.modelPath = modelPath

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 999

        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw LlamaSummaryError.failedToLoadModel(modelPath)
        }
        self.model = model

        guard let vocab = llama_model_get_vocab(model) else {
            llama_model_free(model)
            throw LlamaSummaryError.missingVocabulary
        }
        self.vocab = vocab

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 4096
        contextParams.n_batch = 4096
        contextParams.n_ubatch = 4096
        contextParams.n_threads = threadCount()
        contextParams.n_threads_batch = threadCount()

        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw LlamaSummaryError.failedToCreateContext(modelPath)
        }
        self.context = context

        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            llama_free(context)
            llama_model_free(model)
            throw LlamaSummaryError.failedToCreateContext(modelPath)
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.2))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(42))
        self.sampler = sampler
    }

    deinit {
        llama_sampler_free(sampler)
        llama_free(context)
        llama_model_free(model)
    }

    func generateSummary(for transcriptContext: String) throws -> String {
        let systemPrompt = """
        You summarize recording transcripts into short, factual notes.
        Respond in the same language as the transcript.
        Do not invent facts that are not grounded in the provided context.
        Return exactly these sections:
        Key points:
        - ...
        Action items:
        - ...
        If there are no action items, write "- None".
        """

        let userPrompt = """
        Summarize the key content of this transcript context.

        Transcript context:
        \(transcriptContext)
        """

        let prompt = try formattedPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt)
        var promptTokens = try tokenize(text: prompt, addBOS: false, parseSpecial: true)
        let maxTokens = 320
        let nCtx = Int(llama_n_ctx(context))

        guard promptTokens.count + maxTokens < nCtx else {
            throw LlamaSummaryError.promptTooLong(promptTokens.count + maxTokens, nCtx)
        }

        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)

        var batch = promptTokens.withUnsafeMutableBufferPointer { buffer in
            llama_batch_get_one(buffer.baseAddress, Int32(buffer.count))
        }

        guard llama_decode(context, batch) == 0 else {
            throw LlamaSummaryError.failedToDecode("prompt decode failed")
        }

        var generated = ""
        var pieceBuffer: [CChar] = []

        for _ in 0..<maxTokens {
            let token = llama_sampler_sample(sampler, context, -1)
            if token == LLAMA_TOKEN_NULL {
                throw LlamaSummaryError.failedToSampleToken
            }
            if llama_vocab_is_eog(vocab, token) {
                break
            }

            generated += try tokenToPiece(token, buffer: &pieceBuffer)
            var nextToken = token
            batch = llama_batch_get_one(&nextToken, 1)

            let decodeStatus = llama_decode(context, batch)
            guard decodeStatus == 0 else {
                throw LlamaSummaryError.failedToDecode("generation decode returned \(decodeStatus)")
            }
        }

        return generated
    }

    private func formattedPrompt(systemPrompt: String, userPrompt: String) throws -> String {
        let systemRole = strdup("system")
        let userRole = strdup("user")
        let systemCString = strdup(systemPrompt)
        let userCString = strdup(userPrompt)
        defer {
            free(systemRole)
            free(userRole)
            free(systemCString)
            free(userCString)
        }

        var messages = [
            llama_chat_message(role: systemRole, content: systemCString),
            llama_chat_message(role: userRole, content: userCString)
        ]

        if let template = llama_model_chat_template(model, nil) {
            var capacity = max((systemPrompt.count + userPrompt.count) * 3, 1024)
            var buffer = [CChar](repeating: 0, count: capacity)
            var length = llama_chat_apply_template(template, &messages, messages.count, true, &buffer, Int32(buffer.count))
            if length < 0 {
                throw LlamaSummaryError.failedToApplyTemplate
            }
            if length >= buffer.count {
                capacity = Int(length) + 1
                buffer = [CChar](repeating: 0, count: capacity)
                length = llama_chat_apply_template(template, &messages, messages.count, true, &buffer, Int32(buffer.count))
                if length < 0 {
                    throw LlamaSummaryError.failedToApplyTemplate
                }
            }
            let actualLength = Int(length)
            return String(decoding: buffer.prefix(actualLength).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }

        return """
        System:
        \(systemPrompt)

        User:
        \(userPrompt)

        Assistant:
        """
    }

    private func tokenize(text: String, addBOS: Bool, parseSpecial: Bool) throws -> [llama_token] {
        let estimatedCount = max(text.utf8.count + (addBOS ? 1 : 0) + 8, 32)
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: estimatedCount)
        defer {
            tokens.deallocate()
        }

        let tokenCount = llama_tokenize(vocab, text, Int32(text.utf8.count), tokens, Int32(estimatedCount), addBOS, parseSpecial)
        if tokenCount < 0 {
            let requiredCount = Int(-tokenCount)
            let resized = UnsafeMutablePointer<llama_token>.allocate(capacity: requiredCount)
            defer {
                resized.deallocate()
            }
            let actualCount = llama_tokenize(vocab, text, Int32(text.utf8.count), resized, Int32(requiredCount), addBOS, parseSpecial)
            return Array(UnsafeBufferPointer(start: resized, count: Int(actualCount)))
        }

        return Array(UnsafeBufferPointer(start: tokens, count: Int(tokenCount)))
    }

    private func tokenToPiece(_ token: llama_token, buffer: inout [CChar]) throws -> String {
        var localBuffer = [CChar](repeating: 0, count: max(buffer.count, 8))
        let pieceLength = llama_token_to_piece(vocab, token, &localBuffer, Int32(localBuffer.count), 0, true)

        if pieceLength > 0 {
            buffer = localBuffer
            return String(decoding: localBuffer.prefix(Int(pieceLength)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }

        let requiredLength = Int(-pieceLength)
        guard requiredLength > 0 else {
            throw LlamaSummaryError.failedToConvertToken
        }

        localBuffer = [CChar](repeating: 0, count: requiredLength)
        let finalLength = llama_token_to_piece(vocab, token, &localBuffer, Int32(localBuffer.count), 0, true)
        guard finalLength > 0 else {
            throw LlamaSummaryError.failedToConvertToken
        }

        buffer = localBuffer
        return String(decoding: localBuffer.prefix(Int(finalLength)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

private func threadCount() -> Int32 {
    Int32(max(1, min(8, ProcessInfo.processInfo.processorCount - 2)))
}
