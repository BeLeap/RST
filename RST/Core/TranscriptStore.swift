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

    func deleteRecording(_ item: RecordingItem) throws {
        if fileManager.fileExists(atPath: item.audioURL.path) {
            try fileManager.removeItem(at: item.audioURL)
        }

        if let transcriptURL = item.transcriptURL, fileManager.fileExists(atPath: transcriptURL.path) {
            try fileManager.removeItem(at: transcriptURL)
        }

        let transcriptJSONURL = transcriptJSONURL(for: item.audioURL)
        if fileManager.fileExists(atPath: transcriptJSONURL.path) {
            try fileManager.removeItem(at: transcriptJSONURL)
        }
    }

    func renameRecording(_ item: RecordingItem, to newTitle: String) throws -> URL {
        let sanitizedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedTitle.isEmpty else {
            throw NSError(
                domain: "TranscriptStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Recording name cannot be empty."]
            )
        }

        guard !sanitizedTitle.contains("/") else {
            throw NSError(
                domain: "TranscriptStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Recording name cannot contain '/'. Use a plain file name."]
            )
        }

        let oldAudioURL = item.audioURL
        let newAudioURL = oldAudioURL
            .deletingLastPathComponent()
            .appendingPathComponent(sanitizedTitle)
            .appendingPathExtension(oldAudioURL.pathExtension)

        guard oldAudioURL != newAudioURL else {
            return oldAudioURL
        }

        guard !fileManager.fileExists(atPath: newAudioURL.path) else {
            throw NSError(
                domain: "TranscriptStore",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "A recording with that name already exists."]
            )
        }

        let oldTranscriptURL = transcriptURL(for: oldAudioURL)
        let oldTranscriptJSONURL = transcriptJSONURL(for: oldAudioURL)
        let newTranscriptURL = transcriptURL(for: newAudioURL)
        let newTranscriptJSONURL = transcriptJSONURL(for: newAudioURL)

        try fileManager.moveItem(at: oldAudioURL, to: newAudioURL)

        do {
            if fileManager.fileExists(atPath: oldTranscriptURL.path) {
                try fileManager.moveItem(at: oldTranscriptURL, to: newTranscriptURL)
            }
            if fileManager.fileExists(atPath: oldTranscriptJSONURL.path) {
                try fileManager.moveItem(at: oldTranscriptJSONURL, to: newTranscriptJSONURL)
            }
            return newAudioURL
        } catch {
            var rollbackMessage = ""
            if fileManager.fileExists(atPath: newAudioURL.path) {
                do {
                    try fileManager.moveItem(at: newAudioURL, to: oldAudioURL)
                } catch {
                    rollbackMessage = " Rollback failed: \(error.localizedDescription)"
                }
            }
            throw NSError(
                domain: "TranscriptStore",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to rename transcript files: \(error.localizedDescription).\(rollbackMessage)"]
            )
        }
    }
}
