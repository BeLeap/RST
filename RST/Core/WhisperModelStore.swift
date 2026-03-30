import AppKit
import Combine
import Foundation

struct WhisperModelPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let filename: String
    let downloadURL: URL
    let sizeDescription: String

    static let customID = "custom"

    static let catalog: [WhisperModelPreset] = [
        WhisperModelPreset(
            id: "tiny",
            name: "Tiny",
            filename: "ggml-tiny.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin?download=true")!,
            sizeDescription: "~75 MB"
        ),
        WhisperModelPreset(
            id: "base",
            name: "Base",
            filename: "ggml-base.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin?download=true")!,
            sizeDescription: "~142 MB"
        ),
        WhisperModelPreset(
            id: "small",
            name: "Small",
            filename: "ggml-small.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin?download=true")!,
            sizeDescription: "~466 MB"
        ),
        WhisperModelPreset(
            id: "medium",
            name: "Medium",
            filename: "ggml-medium.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin?download=true")!,
            sizeDescription: "~1.5 GB"
        ),
        WhisperModelPreset(
            id: "large-v3-turbo",
            name: "Large v3 Turbo",
            filename: "ggml-large-v3-turbo.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin?download=true")!,
            sizeDescription: "~1.6 GB"
        )
    ]

    static func preset(id: String) -> WhisperModelPreset? {
        catalog.first { $0.id == id }
    }
}

@MainActor
final class WhisperModelStore: ObservableObject {
    @Published private(set) var downloadedModelIDs: Set<String> = []
    @Published private(set) var activeDownloadID: String?
    @Published private(set) var statusMessage = "Choose a Whisper model."
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var activeDownloadProgress: Double?

    private let fileManager: FileManager
    private let transcriptStore: TranscriptStore
    private let urlSessionConfiguration: URLSessionConfiguration

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
            WhisperModelPreset.catalog
                .filter { fileManager.fileExists(atPath: localURL(for: $0).path) }
                .map(\.id)
        )
    }

    func localURL(for preset: WhisperModelPreset) -> URL {
        transcriptStore.modelsDirectory.appendingPathComponent(preset.filename, isDirectory: false)
    }

    func localPath(for preset: WhisperModelPreset) -> String {
        localURL(for: preset).path
    }

    func isDownloaded(_ preset: WhisperModelPreset) -> Bool {
        downloadedModelIDs.contains(preset.id)
    }

    func resolveModelPath(selectedModelID: String, customModelPath: String) -> String {
        if let preset = WhisperModelPreset.preset(id: selectedModelID) {
            return isDownloaded(preset) ? localPath(for: preset) : ""
        }

        return customModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func selectionSummary(selectedModelID: String, customModelPath: String) -> String {
        if let preset = WhisperModelPreset.preset(id: selectedModelID) {
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
        guard let preset = WhisperModelPreset.preset(id: selectedModelID) else {
            statusMessage = "Using a custom Whisper model path."
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
        guard let preset = WhisperModelPreset.preset(id: selectedModelID) else {
            return
        }
        await download(preset: preset, force: true)
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

    private func download(preset: WhisperModelPreset, force: Bool = false) async {
        guard activeDownloadID == nil || activeDownloadID == preset.id else {
            statusMessage = "Another model download is already in progress."
            return
        }

        activeDownloadID = preset.id
        activeDownloadProgress = nil
        lastErrorMessage = nil
        statusMessage = "Downloading \(preset.name) model..."

        let destinationURL = localURL(for: preset)
        let temporaryURL = destinationURL.appendingPathExtension("download")

        do {
            try transcriptStore.ensureModelDirectory()

            if force, fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                downloadedModelIDs.insert(preset.id)
                statusMessage = "Using downloaded \(preset.name) model."
                activeDownloadID = nil
                return
            }

            if fileManager.fileExists(atPath: temporaryURL.path) {
                try fileManager.removeItem(at: temporaryURL)
            }

            let downloadedFileURL = try await downloadFile(from: preset.downloadURL) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.activeDownloadProgress = progress
                    if let progress {
                        let clampedProgress = min(max(progress, 0), 1)
                        let percent = Int((clampedProgress * 100).rounded())
                        self.statusMessage = "Downloading \(preset.name) model... \(percent)%"
                    } else {
                        self.statusMessage = "Downloading \(preset.name) model..."
                    }
                }
            }
            try fileManager.moveItem(at: downloadedFileURL, to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            downloadedModelIDs.insert(preset.id)
            statusMessage = "Downloaded \(preset.name) model."
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            lastErrorMessage = "Failed to download \(preset.name): \(error.localizedDescription)"
            statusMessage = lastErrorMessage ?? "Failed to download \(preset.name)."
        }

        activeDownloadID = nil
        activeDownloadProgress = nil
    }

    private func downloadFile(from sourceURL: URL, onProgress: @escaping (Double?) -> Void) async throws -> URL {
        let urlSession = URLSession(configuration: urlSessionConfiguration)
        let task = urlSession.downloadTask(with: sourceURL)

        let progressObservation = task.progress.observe(\.fractionCompleted, options: [.new, .initial]) { progress, _ in
            if progress.totalUnitCount > 0 {
                onProgress(progress.fractionCompleted)
            } else {
                onProgress(nil)
            }
        }

        defer {
            progressObservation.invalidate()
            urlSession.invalidateAndCancel()
        }

        task.resume()
        let (localURL, response) = try await task.value

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DownloadError.invalidStatusCode(httpResponse.statusCode)
        }

        return localURL
    }
}

private enum DownloadError: LocalizedError {
    case invalidResponse
    case invalidStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Model download returned an invalid response."
        case .invalidStatusCode(let statusCode):
            return "Model download failed with status code \(statusCode)."
        }
    }
}
