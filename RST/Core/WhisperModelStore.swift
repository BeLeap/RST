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

    private let fileManager: FileManager
    private let transcriptStore: TranscriptStore
    private let urlSession: URLSession

    init(
        fileManager: FileManager = .default,
        transcriptStore: TranscriptStore = TranscriptStore(),
        urlSession: URLSession = .shared
    ) {
        self.fileManager = fileManager
        self.transcriptStore = transcriptStore
        self.urlSession = urlSession
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

            let (downloadedFileURL, _) = try await urlSession.download(from: preset.downloadURL)
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
    }
}
