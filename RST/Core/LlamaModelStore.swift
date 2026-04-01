import AppKit
import Foundation

enum LlamaModelRole: String {
    case embedding
    case summary
}

struct LlamaModelPreset: Identifiable, Equatable {
    let id: String
    let role: LlamaModelRole
    let name: String
    let filename: String
    let downloadURL: URL
    let sizeDescription: String

    static let customID = "custom"

    static let catalog: [LlamaModelPreset] = [
        LlamaModelPreset(
            id: "nomic-embed-text-v1.5-f32",
            role: .embedding,
            name: "Nomic Embed Text v1.5",
            filename: "nomic-embed-text-v1.5.f32.gguf",
            downloadURL: URL(string: "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f32.gguf?download=true")!,
            sizeDescription: "~548 MB"
        ),
        LlamaModelPreset(
            id: "qwen2.5-0.5b-instruct-q4_k_m",
            role: .summary,
            name: "Qwen2.5 0.5B Instruct Q4_K_M",
            filename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf?download=true")!,
            sizeDescription: "~438 MB"
        ),
        LlamaModelPreset(
            id: "qwen2.5-1.5b-instruct-q4_k_m",
            role: .summary,
            name: "Qwen2.5 1.5B Instruct Q4_K_M",
            filename: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true")!,
            sizeDescription: "~986 MB"
        )
    ]

    static func catalog(for role: LlamaModelRole) -> [LlamaModelPreset] {
        catalog.filter { $0.role == role }
    }

    static func preset(id: String) -> LlamaModelPreset? {
        catalog.first { $0.id == id }
    }
}

@MainActor
final class LlamaModelStore: ObservableObject {
    @Published private(set) var downloadedModelIDs: Set<String> = []
    @Published private(set) var activeDownloadID: String?
    @Published private(set) var statusMessage = "Choose llama.cpp models."
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var activeDownloadProgress: Double?
    @Published private(set) var activeDownloadRemainingTime: String?

    private let fileManager: FileManager
    private let transcriptStore: TranscriptStore
    private let urlSessionConfiguration: URLSessionConfiguration
    private var activeDownloadTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        transcriptStore: TranscriptStore = TranscriptStore(),
        urlSessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.fileManager = fileManager
        self.transcriptStore = transcriptStore
        self.urlSessionConfiguration = urlSessionConfiguration
        refreshLocalModels()
    }

    func refreshLocalModels() {
        downloadedModelIDs = Set(
            LlamaModelPreset.catalog
                .filter { fileManager.fileExists(atPath: localURL(for: $0).path) }
                .map(\.id)
        )
    }

    func localURL(for preset: LlamaModelPreset) -> URL {
        transcriptStore.modelsDirectory.appendingPathComponent(preset.filename, isDirectory: false)
    }

    func localPath(for preset: LlamaModelPreset) -> String {
        localURL(for: preset).path
    }

    func isDownloaded(_ preset: LlamaModelPreset) -> Bool {
        downloadedModelIDs.contains(preset.id)
    }

    func resolveModelPath(selectedModelID: String, customModelPath: String) -> String {
        if let preset = LlamaModelPreset.preset(id: selectedModelID) {
            return isDownloaded(preset) ? localPath(for: preset) : ""
        }

        return customModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectionSummary(selectedModelID: String, customModelPath: String) -> String {
        if let preset = LlamaModelPreset.preset(id: selectedModelID) {
            if isDownloaded(preset) {
                return "Using downloaded \(preset.name) model."
            }
            if activeDownloadID == preset.id {
                return "Downloading \(preset.name) model..."
            }
            if let lastErrorMessage {
                return lastErrorMessage
            }
            return "\(preset.name) is not downloaded yet."
        }

        if customModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Choose a model preset or enter a custom path."
        }

        return "Using custom model path."
    }

    func prepareSelection(_ selectedModelID: String) async {
        guard let preset = LlamaModelPreset.preset(id: selectedModelID) else {
            statusMessage = "Using a custom llama.cpp model path."
            lastErrorMessage = nil
            return
        }

        refreshLocalModels()
        guard !isDownloaded(preset) else {
            statusMessage = "Using downloaded \(preset.name) model."
            lastErrorMessage = nil
            return
        }

        await download(preset: preset)
    }

    func redownloadSelectedModel(_ selectedModelID: String) async {
        guard let preset = LlamaModelPreset.preset(id: selectedModelID) else {
            return
        }
        await download(preset: preset, force: true)
    }

    func cancelActiveDownload() {
        guard activeDownloadTask != nil else {
            statusMessage = "No model download is currently in progress."
            return
        }

        activeDownloadTask?.cancel()
        statusMessage = "Canceling model download..."
    }

    func openModelsFolder() {
        do {
            try transcriptStore.ensureModelDirectory()
            NSWorkspace.shared.open(transcriptStore.modelsDirectory)
        } catch {
            lastErrorMessage = error.localizedDescription
            statusMessage = error.localizedDescription
        }
    }

    private func download(preset: LlamaModelPreset, force: Bool = false) async {
        guard activeDownloadTask == nil else {
            statusMessage = "Another model download is already in progress."
            return
        }

        activeDownloadID = preset.id
        activeDownloadProgress = nil
        activeDownloadRemainingTime = nil
        lastErrorMessage = nil
        statusMessage = "Downloading \(preset.name) model..."

        let downloadTask = Task {
            await performDownload(preset: preset, force: force)
        }
        activeDownloadTask = downloadTask
        await downloadTask.value

        activeDownloadTask = nil
        activeDownloadID = nil
        activeDownloadProgress = nil
        activeDownloadRemainingTime = nil
    }

    private func performDownload(preset: LlamaModelPreset, force: Bool) async {
        let destinationURL = localURL(for: preset)
        let temporaryURL = destinationURL.appendingPathExtension("download")

        do {
            try transcriptStore.ensureModelDirectory()
            try Task.checkCancellation()

            if force, fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            if force, fileManager.fileExists(atPath: temporaryURL.path) {
                try fileManager.removeItem(at: temporaryURL)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                downloadedModelIDs.insert(preset.id)
                statusMessage = "Using downloaded \(preset.name) model."
                return
            }

            let existingBytes = currentFileSize(at: temporaryURL)
            if existingBytes > 0 {
                let resumeSize = ByteCountFormatter.string(fromByteCount: existingBytes, countStyle: .file)
                statusMessage = "Resuming \(preset.name) model download from \(resumeSize)..."
            }

            _ = try await downloadFile(
                from: preset.downloadURL,
                to: temporaryURL,
                existingBytes: existingBytes
            ) { [weak self] update in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.activeDownloadProgress = update.progress
                    self.activeDownloadRemainingTime = self.formatRemainingTime(update.estimatedRemaining)
                    if let progress = update.progress {
                        let clampedProgress = min(max(progress, 0), 1)
                        let percent = Int((clampedProgress * 100).rounded())
                        if let remainingTime = self.activeDownloadRemainingTime {
                            self.statusMessage = "Downloading \(preset.name) model... \(percent)% (\(remainingTime) remaining)"
                        } else {
                            self.statusMessage = "Downloading \(preset.name) model... \(percent)%"
                        }
                    } else {
                        self.statusMessage = "Downloading \(preset.name) model..."
                    }
                }
            }

            try Task.checkCancellation()
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            downloadedModelIDs.insert(preset.id)
            statusMessage = "Downloaded \(preset.name) model."
        } catch is CancellationError {
            let partialSize = currentFileSize(at: temporaryURL)
            if partialSize > 0 {
                statusMessage = "Canceled download for \(preset.name). \(ByteCountFormatter.string(fromByteCount: partialSize, countStyle: .file)) saved for resume."
            } else {
                statusMessage = "Canceled download for \(preset.name)."
            }
        } catch {
            lastErrorMessage = "Failed to download \(preset.name): \(error.localizedDescription)"
            statusMessage = lastErrorMessage ?? "Failed to download \(preset.name)."
        }
    }

    private func downloadFile(
        from sourceURL: URL,
        to temporaryFileURL: URL,
        existingBytes: Int64,
        onProgress: @Sendable @escaping (LlamaDownloadProgressUpdate) -> Void
    ) async throws -> URL {
        let downloader = ModelFileDownloader(sessionConfiguration: urlSessionConfiguration)
        return try await downloader.download(
            from: sourceURL,
            to: temporaryFileURL,
            existingBytes: existingBytes
        ) { @Sendable progress in
            onProgress(
                LlamaDownloadProgressUpdate(
                    progress: progress.progress,
                    estimatedRemaining: progress.estimatedRemaining
                )
            )
        }
    }

    private func currentFileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }
    private func formatRemainingTime(_ remaining: TimeInterval?) -> String? {
        guard let remaining else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = remaining >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter.string(from: remaining)
    }
}

private struct LlamaDownloadProgressUpdate {
    let progress: Double?
    let estimatedRemaining: TimeInterval?
}
