import Foundation

struct ModelDownloadProgressUpdate {
    let progress: Double?
    let estimatedRemaining: TimeInterval?
}

enum ModelFileDownloadError: LocalizedError {
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

final class ModelFileDownloader: NSObject {
    private let sessionConfiguration: URLSessionConfiguration

    init(sessionConfiguration: URLSessionConfiguration) {
        self.sessionConfiguration = sessionConfiguration
    }

    func download(
        from sourceURL: URL,
        to temporaryFileURL: URL,
        existingBytes: Int64,
        onProgress: @Sendable @escaping (ModelDownloadProgressUpdate) -> Void
    ) async throws -> URL {
        let transfer = ModelFileDownloadTransfer(
            sessionConfiguration: sessionConfiguration,
            sourceURL: sourceURL,
            temporaryFileURL: temporaryFileURL,
            existingBytes: existingBytes,
            onProgress: onProgress
        )
        return try await transfer.run()
    }
}

private final class ModelFileDownloadTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let sessionConfiguration: URLSessionConfiguration
    private let sourceURL: URL
    private let temporaryFileURL: URL
    private let existingBytes: Int64
    private let onProgress: @Sendable (ModelDownloadProgressUpdate) -> Void

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var fileHandle: FileHandle?
    private var totalContentLength: Int64 = -1
    private var downloadedBytes: Int64
    private let downloadStartTime = Date()
    private var isFinished = false

    init(
        sessionConfiguration: URLSessionConfiguration,
        sourceURL: URL,
        temporaryFileURL: URL,
        existingBytes: Int64,
        onProgress: @Sendable @escaping (ModelDownloadProgressUpdate) -> Void
    ) {
        self.sessionConfiguration = sessionConfiguration
        self.sourceURL = sourceURL
        self.temporaryFileURL = temporaryFileURL
        self.existingBytes = existingBytes
        self.onProgress = onProgress
        self.downloadedBytes = existingBytes
    }

    func run() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation

                let session = URLSession(
                    configuration: sessionConfiguration,
                    delegate: self,
                    delegateQueue: nil
                )
                self.session = session

                var request = URLRequest(url: sourceURL)
                request.timeoutInterval = 300
                if existingBytes > 0 {
                    request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
                }

                let dataTask = session.dataTask(with: request)
                self.dataTask = dataTask
                dataTask.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    private func cancel() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !isFinished else { return }
        isFinished = true

        if let fileHandle {
            try? fileHandle.close()
            self.fileHandle = nil
        }

        if case .success = result {
            session?.finishTasksAndInvalidate()
        } else {
            session?.invalidateAndCancel()
        }

        continuation?.resume(with: result)
        continuation = nil
        dataTask = nil
        session = nil
    }

    private func prepareFileHandle(for response: HTTPURLResponse) throws {
        if existingBytes > 0 && response.statusCode != 206 {
            throw ModelFileDownloadError.rangeNotSupported
        }

        if !FileManager.default.fileExists(atPath: temporaryFileURL.path) {
            guard FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil) else {
                throw ModelFileDownloadError.unableToCreateTemporaryFile(temporaryFileURL.path)
            }
        }

        let expectedContentLength = response.expectedContentLength
        totalContentLength = {
            if response.statusCode == 206 {
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
        self.fileHandle = fileHandle
    }

    private func reportProgressIfNeeded(forceCompletion: Bool = false) {
        guard totalContentLength > 0 else { return }
        guard forceCompletion || downloadedBytes % Int64(256 * 1024) == 0 else { return }

        onProgress(
            ModelDownloadProgressUpdate(
                progress: forceCompletion ? 1 : Double(downloadedBytes) / Double(totalContentLength),
                estimatedRemaining: forceCompletion ? 0 : estimateRemainingTime()
            )
        )
    }

    private func estimateRemainingTime() -> TimeInterval? {
        let downloadedThisAttempt = downloadedBytes - existingBytes
        guard downloadedThisAttempt > 0 else { return nil }

        let elapsed = Date().timeIntervalSince(downloadStartTime)
        guard elapsed > 0 else { return nil }

        let bytesPerSecond = Double(downloadedThisAttempt) / elapsed
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return nil }

        let remainingBytes = totalContentLength - downloadedBytes
        guard remainingBytes > 0 else { return 0 }

        let remaining = Double(remainingBytes) / bytesPerSecond
        return remaining.isFinite ? max(remaining, 0) : nil
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(ModelFileDownloadError.invalidResponse))
            return
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            completionHandler(.cancel)
            finish(.failure(ModelFileDownloadError.invalidStatusCode(httpResponse.statusCode)))
            return
        }

        do {
            try prepareFileHandle(for: httpResponse)
            completionHandler(.allow)
        } catch {
            completionHandler(.cancel)
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isFinished else { return }
        guard let fileHandle else {
            finish(.failure(ModelFileDownloadError.unableToCreateTemporaryFile(temporaryFileURL.path)))
            return
        }

        do {
            try fileHandle.write(contentsOf: data)
            downloadedBytes += Int64(data.count)
            reportProgressIfNeeded()
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isFinished else { return }

        if let error {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                finish(.failure(CancellationError()))
            } else {
                finish(.failure(error))
            }
            return
        }

        if totalContentLength > 0 {
            reportProgressIfNeeded(forceCompletion: true)
        } else {
            onProgress(ModelDownloadProgressUpdate(progress: nil, estimatedRemaining: nil))
        }

        finish(.success(temporaryFileURL))
    }
}
