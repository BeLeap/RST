import Foundation

struct TranscriptStore {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("RST", isDirectory: true)
    }

    var recordingsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    var modelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Models", isDirectory: true)
    }

    func ensureDirectories() throws {
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    func ensureModelDirectory() throws {
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func nextRecordingURL(now: Date = .now) throws -> URL {
        try ensureDirectories()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "recording-\(formatter.string(from: now)).wav"
        return recordingsDirectory.appendingPathComponent(name, isDirectory: false)
    }

    func transcriptURL(for audioURL: URL) -> URL {
        let stem = audioURL.deletingPathExtension().lastPathComponent
        return audioURL.deletingLastPathComponent().appendingPathComponent("\(stem)-transcript.txt")
    }

    func transcriptJSONURL(for audioURL: URL) -> URL {
        let stem = audioURL.deletingPathExtension().lastPathComponent
        return audioURL.deletingLastPathComponent().appendingPathComponent("\(stem)-transcript.json")
    }

    func loadRecordings() throws -> [RecordingItem] {
        try ensureDirectories()

        let urls = try fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return try urls
            .filter { $0.pathExtension.lowercased() == "wav" }
            .map { audioURL in
                let values = try audioURL.resourceValues(forKeys: [.creationDateKey])
                let transcriptURL = transcriptURL(for: audioURL)
                return RecordingItem(
                    audioURL: audioURL,
                    transcriptURL: fileManager.fileExists(atPath: transcriptURL.path) ? transcriptURL : nil,
                    createdAt: values.creationDate ?? .distantPast
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func loadTranscript(for item: RecordingItem) throws -> String {
        guard let transcriptURL = item.transcriptURL else {
            return "No transcript yet."
        }

        return try String(contentsOf: transcriptURL, encoding: .utf8)
    }
}
