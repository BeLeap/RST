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

    private func download(preset: WhisperModelPreset, force: Bool = false) async {
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

    private func performDownload(preset: WhisperModelPreset, force: Bool) async {
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
        onProgress: @escaping (DownloadProgressUpdate) -> Void
    ) async throws -> URL {
        let urlSession = URLSession(configuration: urlSessionConfiguration)
        defer {
            urlSession.invalidateAndCancel()
        }

        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 300
        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        let (bytes, response) = try await urlSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw DownloadError.invalidStatusCode(httpResponse.statusCode)
        }

        if existingBytes > 0 && httpResponse.statusCode != 206 {
            throw DownloadError.rangeNotSupported
        }

        if !FileManager.default.fileExists(atPath: temporaryFileURL.path) {
            guard FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil) else {
                throw DownloadError.unableToCreateTemporaryFile(temporaryFileURL.path)
            }
        }

        let expectedContentLength = httpResponse.expectedContentLength
        let totalContentLength: Int64 = {
            if httpResponse.statusCode == 206 {
                return expectedContentLength > 0 ? existingBytes + expectedContentLength : -1
            }
            return expectedContentLength
        }()

        let fileHandle = try FileHandle(forWritingTo: temporaryFileURL)
        if existingBytes > 0 {
            try fileHandle.seekToEnd()
        } else {
            try fileHandle.truncate(atOffset: 0)
        }
        var writeBuffer = Data()
        writeBuffer.reserveCapacity(64 * 1024)
        var downloadedBytes: Int64 = existingBytes
        let downloadStartTime = Date()

        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                writeBuffer.append(byte)
                downloadedBytes += 1

                if writeBuffer.count >= 64 * 1024 {
                    try fileHandle.write(contentsOf: writeBuffer)
                    writeBuffer.removeAll(keepingCapacity: true)
                }

                if totalContentLength > 0, downloadedBytes % Int64(256 * 1024) == 0 {
                    onProgress(
                        DownloadProgressUpdate(
                            progress: Double(downloadedBytes) / Double(totalContentLength),
                            estimatedRemaining: estimateRemainingTime(
                                totalBytes: totalContentLength,
                                downloadedBytes: downloadedBytes,
                                existingBytes: existingBytes,
                                downloadStartTime: downloadStartTime
                            )
                        )
                    )
                }
            }

            if !writeBuffer.isEmpty {
                try fileHandle.write(contentsOf: writeBuffer)
            }
            try fileHandle.close()
        } catch {
            try? fileHandle.close()
            throw error
        }

        if expectedContentLength > 0 {
            onProgress(DownloadProgressUpdate(progress: 1, estimatedRemaining: 0))
        } else {
            onProgress(DownloadProgressUpdate(progress: nil, estimatedRemaining: nil))
        }

        return temporaryFileURL
    }

    private func currentFileSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    private func estimateRemainingTime(
        totalBytes: Int64,
        downloadedBytes: Int64,
        existingBytes: Int64,
        downloadStartTime: Date
    ) -> TimeInterval? {
        let downloadedThisAttempt = downloadedBytes - existingBytes
        guard downloadedThisAttempt > 0 else { return nil }

        let elapsed = Date().timeIntervalSince(downloadStartTime)
        guard elapsed > 0 else { return nil }

        let bytesPerSecond = Double(downloadedThisAttempt) / elapsed
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return nil }

        let remainingBytes = totalBytes - downloadedBytes
        guard remainingBytes > 0 else { return 0 }

        let remaining = Double(remainingBytes) / bytesPerSecond
        return remaining.isFinite ? max(remaining, 0) : nil
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

private struct DownloadProgressUpdate {
    let progress: Double?
    let estimatedRemaining: TimeInterval?
}

private enum DownloadError: LocalizedError {
    case invalidResponse
    case invalidStatusCode(Int)
    case unableToCreateTemporaryFile(String)
    case rangeNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Model download returned an invalid response."
        case .invalidStatusCode(let statusCode):
            return "Model download failed with status code \(statusCode)."
        case .unableToCreateTemporaryFile(let filePath):
            return "Model download could not create a temporary file at \(filePath)."
        case .rangeNotSupported:
            return "Model host does not support resumable downloads for this file."
        }
    }
}
