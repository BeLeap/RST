import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class RecorderViewModel: ObservableObject {
    private static let liveUpdateInterval: TimeInterval = 2.5

    @Published private(set) var recordings: [RecordingItem] = []
    @Published var selectedRecordingID: RecordingItem.ID?
    @Published var selectedRecordingIDs: Set<RecordingItem.ID> = []
    @Published private(set) var selectedTranscript = "No transcript selected."
    @Published private(set) var selectedSummary = "No summary selected."
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var statusMessage = "Ready."
    @Published private(set) var queuedJobCount = 0
    @Published private(set) var runningJobID: UUID?
    @Published private(set) var liveChunkTranscript = "Live chunk transcript will appear while recording."

    private let store: TranscriptStore
    private let recorder: AudioRecorderService
    private let transcriber: WhisperTranscriber
    private var activeRecordingURL: URL?
    private var liveSession: WhisperTranscriptionSession?
    private var liveUpdateTimer: Timer?
    private var liveUpdateTask: Task<Void, Never>?
    private var queueWorkerTask: Task<Void, Never>?
    private var transcriptionQueue: [TranscriptionJob] = []

    init(
        store: TranscriptStore = TranscriptStore(),
        recorder: AudioRecorderService = AudioRecorderService(),
        transcriber: WhisperTranscriber = WhisperTranscriber()
    ) {
        self.store = store
        self.recorder = recorder
        self.transcriber = transcriber

        do {
            try reloadRecordings()
            try loadTranscriptionQueue()
            startQueueWorkerIfNeeded()
            if let first = recordings.first {
                selectedRecordingIDs = [first.id]
                selectedRecordingID = first.id
                try loadTranscript(for: first)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    var selectedRecording: RecordingItem? {
        recordings.first { $0.id == selectedRecordingID }
    }

    func transcriptionStatusText(for item: RecordingItem) -> String {
        guard let job = latestJob(for: item.audioURL.path) else {
            return item.transcriptURL == nil ? "Not transcribed" : "Transcribed"
        }

        switch job.status {
        case .queued:
            return "Queued"
        case .running:
            return "Transcribing..."
        case .completed:
            return "Transcribed"
        case .failed:
            let message = job.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let message, !message.isEmpty {
                return "Failed: \(message)"
            }
            return "Failed"
        }
    }

    func reloadRecordings() throws {
        recordings = try store.loadRecordings()
    }

    func selectRecording(id: RecordingItem.ID?) {
        if let id {
            selectedRecordingIDs = [id]
        } else {
            selectedRecordingIDs = []
        }
        updatePrimarySelection(id: id)
    }

    func setSelectedRecordings(ids: Set<RecordingItem.ID>) {
        let validIDs = Set(recordings.map(\.id))
        let normalizedIDs = ids.intersection(validIDs)
        selectedRecordingIDs = normalizedIDs

        if normalizedIDs.isEmpty {
            updatePrimarySelection(id: nil)
            return
        }

        if let selectedRecordingID, normalizedIDs.contains(selectedRecordingID) {
            return
        }

        let prioritizedID = firstRecordingID(in: normalizedIDs)
        updatePrimarySelection(id: prioritizedID)
    }

    private func updatePrimarySelection(id: RecordingItem.ID?) {
        selectedRecordingID = id

        guard let item = recordings.first(where: { $0.id == id }) else {
            selectedTranscript = "No transcript selected."
            selectedSummary = "No summary selected."
            return
        }

        do {
            try loadTranscript(for: item)
        } catch {
            selectedTranscript = error.localizedDescription
            selectedSummary = "No summary selected."
        }
    }

    func startRecording(configuration: WhisperConfiguration) async {
        do {
            try store.ensureDirectories()
            try await recorder.requestPermission()
            let url = try store.nextRecordingURL()
            let modelErrorMessage = try prepareLiveSession(configuration: configuration)
            try recorder.startRecording(to: url)
            activeRecordingURL = url
            isRecording = true
            liveChunkTranscript = "Listening for chunk updates..."
            scheduleLiveUpdates()
            var filesRefreshErrorDetail: String?
            do {
                try reloadRecordings()
                selectedRecordingIDs = [url.path]
                selectedRecordingID = url.path
                if let recordingItem = selectedRecording {
                    try loadTranscript(for: recordingItem)
                } else {
                    selectedTranscript = "No transcript selected."
                    selectedSummary = "No summary selected."
                }
            } catch {
                filesRefreshErrorDetail = " Failed to refresh Files list: \(error.localizedDescription)"
            }
            if let modelErrorMessage {
                statusMessage = "Recording to \(url.lastPathComponent). \(modelErrorMessage)\(filesRefreshErrorDetail ?? "")"
            } else if liveSession == nil {
                statusMessage = "Recording to \(url.lastPathComponent). Live transcription is unavailable until a valid model path is set.\(filesRefreshErrorDetail ?? "")"
            } else {
                statusMessage = "Recording to \(url.lastPathComponent). Live transcription is active.\(filesRefreshErrorDetail ?? "")"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stopRecording(
        finalConfiguration: WhisperConfiguration,
        summaryConfiguration: LlamaSummaryConfiguration
    ) async {
        do {
            liveUpdateTimer?.invalidate()
            liveUpdateTimer = nil
            liveUpdateTask?.cancel()
            let url = try recorder.stopRecording()
            activeRecordingURL = url
            isRecording = false
            liveChunkTranscript = "Live chunk transcript will appear while recording."
            try reloadRecordings()
            selectedRecordingIDs = [url.path]
            selectedRecordingID = url.path
            if let item = selectedRecording {
                try loadTranscript(for: item)
            }
            liveSession = nil
            try enqueueTranscription(
                audioURL: url,
                configuration: finalConfiguration,
                summaryConfiguration: summaryConfiguration
            )
            statusMessage = "Saved recording \(url.lastPathComponent). Added final transcription to queue."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func transcribeSelected(
        configuration: WhisperConfiguration,
        summaryConfiguration: LlamaSummaryConfiguration
    ) async {
        guard let item = selectedRecording else {
            statusMessage = "Select a recording to transcribe."
            return
        }

        do {
            try enqueueTranscription(
                audioURL: item.audioURL,
                configuration: configuration,
                summaryConfiguration: summaryConfiguration
            )
            statusMessage = "Queued transcription for \(item.audioURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func summarizeSelected(summaryConfiguration: LlamaSummaryConfiguration) async {
        guard let item = selectedRecording else {
            statusMessage = "Select a recording to summarize."
            return
        }

        guard item.transcriptURL != nil else {
            statusMessage = "Transcribe this recording before generating a summary."
            return
        }

        let configuration = LlamaSummaryConfiguration(
            embeddingModelPath: summaryConfiguration.embeddingModelPath.trimmingCharacters(in: .whitespacesAndNewlines),
            summaryModelPath: summaryConfiguration.summaryModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard configuration.isConfigured else {
            statusMessage = "Summary failed: llama.cpp summary settings are incomplete."
            return
        }

        isTranscribing = true
        statusMessage = "Summarizing \(item.audioURL.lastPathComponent)..."
        defer {
            isTranscribing = false
        }

        do {
            let transcriptText = try store.loadTranscript(for: item)
            let summary = try await summarizeInBackground(
                audioURL: item.audioURL,
                transcriptText: transcriptText,
                configuration: configuration
            )
            try reloadRecordings()
            selectedSummary = summary.summaryText
            statusMessage = "Summary saved to \(summary.summaryURL.lastPathComponent)"
        } catch {
            statusMessage = "Summary failed for \(item.audioURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func revealAudio() {
        guard let url = selectedRecording?.audioURL else {
            statusMessage = "Select a recording first."
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealTranscript() {
        guard let url = selectedRecording?.transcriptURL else {
            statusMessage = "The selected recording does not have a transcript yet."
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openRecordingsFolder() {
        NSWorkspace.shared.open(store.recordingsDirectory)
    }

    func exportAudio() {
        guard let recording = selectedRecording else {
            statusMessage = "Select a recording first."
            return
        }

        let compressedFileName = recording.audioURL
            .deletingPathExtension()
            .lastPathComponent
            .appending(".\(AudioFileTranscoder.compressedExportExtension)")

        guard let destination = PanelPicker.saveFile(
            title: "Export Recording",
            suggestedName: compressedFileName,
            allowedFileTypes: [AudioFileTranscoder.compressedExportExtension]
        ) else {
            return
        }

        do {
            try AudioFileTranscoder.exportCompressedAudio(from: recording.audioURL, to: destination)
            statusMessage = "Exported compressed audio \(destination.lastPathComponent)"
        } catch {
            statusMessage = "Audio export failed: \(error.localizedDescription)"
        }
    }

    func exportTranscript() {
        guard let transcriptURL = selectedRecording?.transcriptURL else {
            statusMessage = "The selected recording does not have a transcript yet."
            return
        }

        guard let destination = PanelPicker.saveFile(
            title: "Export Transcript",
            suggestedName: transcriptURL.lastPathComponent,
            allowedFileTypes: ["txt"]
        ) else {
            return
        }

        exportItem(at: transcriptURL, to: destination)
    }

    func exportAll() {
        guard let recording = selectedRecording else {
            statusMessage = "Select a recording first."
            return
        }

        guard let transcriptURL = recording.transcriptURL else {
            statusMessage = "Cannot export all artifacts because transcript text is missing."
            return
        }

        guard let summaryURL = recording.summaryURL else {
            statusMessage = "Cannot export all artifacts because summary text is missing."
            return
        }

        guard let destinationDirectory = PanelPicker.chooseDirectory(title: "Choose Export Folder for All Files") else {
            return
        }

        do {
            try ensureExportSourcesExist([
                transcriptURL,
                summaryURL
            ])

            try exportItems([
                transcriptURL,
                summaryURL
            ], to: destinationDirectory)

            let compressedAudioURL = destinationDirectory
                .appendingPathComponent(recording.audioURL.deletingPathExtension().lastPathComponent)
                .appendingPathExtension(AudioFileTranscoder.compressedExportExtension)
            try AudioFileTranscoder.exportCompressedAudio(from: recording.audioURL, to: compressedAudioURL)
            statusMessage = "Exported all artifacts for \(recording.audioURL.lastPathComponent)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func deleteSelectedRecording() {
        guard !selectedRecordingIDs.isEmpty else {
            statusMessage = "Select a recording first."
            return
        }

        deleteRecordings(ids: selectedRecordingIDs)
    }

    func deleteRecording(id: RecordingItem.ID) {
        guard let recording = recordings.first(where: { $0.id == id }) else {
            statusMessage = "The selected recording could not be found."
            return
        }

        do {
            try store.deleteRecording(recording)
            removeQueueJobs(forAudioPath: recording.audioURL.path)
            try reloadRecordings()
            if let nextID = recordings.first?.id {
                selectedRecordingIDs = [nextID]
                selectedRecordingID = nextID
            } else {
                selectedRecordingIDs = []
                selectedRecordingID = nil
            }

            if let next = selectedRecording {
                try loadTranscript(for: next)
            } else {
                selectedTranscript = "No transcript selected."
                selectedSummary = "No summary selected."
            }

            statusMessage = "Deleted \(recording.audioURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteRecordings(ids: Set<RecordingItem.ID>) {
        let targets = recordings.filter { ids.contains($0.id) }
        guard !targets.isEmpty else {
            statusMessage = "The selected recordings could not be found."
            return
        }

        do {
            for recording in targets {
                try store.deleteRecording(recording)
                removeQueueJobs(forAudioPath: recording.audioURL.path)
            }

            try reloadRecordings()
            if let nextID = recordings.first?.id {
                selectedRecordingIDs = [nextID]
                selectedRecordingID = nextID
            } else {
                selectedRecordingIDs = []
                selectedRecordingID = nil
            }

            if let next = selectedRecording {
                try loadTranscript(for: next)
            } else {
                selectedTranscript = "No transcript selected."
                selectedSummary = "No summary selected."
            }

            statusMessage = "Deleted \(targets.count) recording(s)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func renameRecording(id: RecordingItem.ID) {
        guard let recording = recordings.first(where: { $0.id == id }) else {
            statusMessage = "The selected recording could not be found."
            return
        }

        let prompt = NSAlert()
        prompt.messageText = "Rename Recording"
        prompt.informativeText = "Enter a new file name for this recording."
        prompt.alertStyle = .informational
        prompt.addButton(withTitle: "Rename")
        prompt.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        inputField.stringValue = recording.title
        prompt.accessoryView = inputField

        let response = prompt.runModal()
        guard response == .alertFirstButtonReturn else {
            statusMessage = "Rename canceled."
            return
        }

        do {
            let newAudioURL = try store.renameRecording(recording, to: inputField.stringValue)
            try rebindQueueJobs(fromAudioPath: recording.audioURL.path, toAudioPath: newAudioURL.path)
            try reloadRecordings()
            selectedRecordingIDs = [newAudioURL.path]
            selectedRecordingID = newAudioURL.path
            if let renamed = selectedRecording {
                try loadTranscript(for: renamed)
            }
            statusMessage = "Renamed recording to \(newAudioURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func renameSelectedRecording() {
        guard let selectedRecordingID else {
            statusMessage = "Select a recording first."
            return
        }

        renameRecording(id: selectedRecordingID)
    }

    func importDroppedAudio(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else {
            statusMessage = "No files were dropped."
            return false
        }

        let acceptedProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !acceptedProviders.isEmpty else {
            statusMessage = "Drop one or more local WAV, M4A, AAC, MP3, or MP4 files."
            return false
        }

        Task { @MainActor in
            let dropLoadResult = await loadDroppedFileURLs(from: acceptedProviders)
            await importAudioFiles(from: dropLoadResult.urls, preflightErrors: dropLoadResult.errors)
        }

        return true
    }

    func importAudioFiles(from urls: [URL], preflightErrors: [String] = []) async {
        guard !urls.isEmpty else {
            if preflightErrors.isEmpty {
                statusMessage = "Could not read dropped files."
            } else {
                statusMessage = "Could not read dropped files: \(preflightErrors.joined(separator: " | "))"
            }
            return
        }

        var importedURLs: [URL] = []
        var errors = preflightErrors

        for url in urls {
            do {
                let importedURL = try store.importRecording(from: url)
                importedURLs.append(importedURL)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        do {
            try reloadRecordings()
        } catch {
            statusMessage = "Imported \(importedURLs.count) file(s), but failed to refresh the list: \(error.localizedDescription)"
            return
        }

        if let firstImported = importedURLs.first,
           let importedItem = recordings.first(where: { $0.audioURL == firstImported }) {
            selectedRecordingIDs = [importedItem.id]
            selectedRecordingID = importedItem.id
            do {
                try loadTranscript(for: importedItem)
            } catch {
                selectedTranscript = error.localizedDescription
                selectedSummary = "No summary selected."
            }
        }

        if errors.isEmpty {
            statusMessage = "Imported \(importedURLs.count) audio file(s) as WAV."
        } else if importedURLs.isEmpty {
            statusMessage = "Import failed: \(errors.joined(separator: " | "))"
        } else {
            statusMessage = "Imported \(importedURLs.count) file(s), \(errors.count) failed: \(errors.joined(separator: " | "))"
        }
    }

    private func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> (urls: [URL], errors: [String]) {
        var urls: [URL] = []
        var errors: [String] = []

        for provider in providers {
            do {
                let url = try await loadDroppedFileURL(from: provider)
                urls.append(url)
            } catch {
                let providerName = provider.suggestedName ?? "unknown file"
                errors.append("\(providerName): \(error.localizedDescription)")
            }
        }

        return (urls, errors)
    }

    private func loadDroppedFileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(throwing: NSError(
                    domain: "RecorderViewModel",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode dropped file URL."]
                ))
            }
        }
    }

    private func loadTranscriptionQueue() throws {
        transcriptionQueue = try store.loadTranscriptionQueue().map { job in
            var normalized = job
            if normalized.status == .running {
                normalized.status = .queued
                normalized.updatedAt = .now
                normalized.errorMessage = nil
            }
            return normalized
        }
        try store.saveTranscriptionQueue(transcriptionQueue)
        recalculateQueueState()
    }

    private func enqueueTranscription(
        audioURL: URL,
        configuration: WhisperConfiguration,
        summaryConfiguration: LlamaSummaryConfiguration
    ) throws {
        let modelPath = configuration.modelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelPath.isEmpty else {
            throw WhisperTranscriptionError.invalidModelPath("(empty)")
        }

        let language = configuration.language.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLanguage = language.isEmpty ? "auto" : language

        if let existing = latestJob(for: audioURL.path), existing.status == .queued || existing.status == .running {
            throw NSError(
                domain: "RecorderViewModel",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Transcription is already queued for \(audioURL.lastPathComponent)."]
            )
        }

        let job = TranscriptionJob(
            audioPath: audioURL.path,
            modelPath: modelPath,
            language: normalizedLanguage,
            summaryEmbeddingModelPath: summaryConfiguration.embeddingModelPath.trimmingCharacters(in: .whitespacesAndNewlines),
            summaryModelPath: summaryConfiguration.summaryModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        transcriptionQueue.append(job)
        try persistQueue()
        recalculateQueueState()
        startQueueWorkerIfNeeded()
    }

    private func startQueueWorkerIfNeeded() {
        guard queueWorkerTask == nil else {
            return
        }

        queueWorkerTask = Task { @MainActor [weak self] in
            await self?.runTranscriptionQueue()
        }
    }

    private func runTranscriptionQueue() async {
        while true {
            guard let nextJob = nextQueuedJob() else {
                queueWorkerTask = nil
                recalculateQueueState()
                return
            }

            do {
                try markJobStatus(nextJob.id, status: .running, errorMessage: nil)
                isTranscribing = true
                statusMessage = "Transcribing \(URL(fileURLWithPath: nextJob.audioPath).lastPathComponent)..."

                let result = try await transcribeInBackground(
                    audioURL: URL(fileURLWithPath: nextJob.audioPath),
                    configuration: WhisperConfiguration(modelPath: nextJob.modelPath, language: nextJob.language)
                )

                try markJobStatus(nextJob.id, status: .completed, errorMessage: nil)
                let summaryOutcome = try await summarizeIfConfigured(
                    job: nextJob,
                    transcriptText: result.transcriptText
                )
                try reloadRecordings()
                if selectedRecordingID == nextJob.audioPath {
                    selectedTranscript = result.transcriptText
                    switch summaryOutcome {
                    case .generated(let summary):
                        selectedSummary = summary.summaryText
                    case .skipped(let message), .failed(let message):
                        selectedSummary = message
                    }
                }
                switch summaryOutcome {
                case .generated(let summary):
                    statusMessage = "Transcript and summary saved to \(result.transcriptURL.lastPathComponent) and \(summary.summaryURL.lastPathComponent)"
                case .skipped(let message):
                    statusMessage = "Transcript saved to \(result.transcriptURL.lastPathComponent). \(message)"
                case .failed(let message):
                    statusMessage = "Transcript saved to \(result.transcriptURL.lastPathComponent), but summary failed: \(message)"
                }
            } catch {
                do {
                    try markJobStatus(nextJob.id, status: .failed, errorMessage: error.localizedDescription)
                } catch {
                    statusMessage = "Queue persistence failed: \(error.localizedDescription)"
                }
                statusMessage = "Transcription failed for \(URL(fileURLWithPath: nextJob.audioPath).lastPathComponent): \(error.localizedDescription)"
            }

            isTranscribing = false
        }
    }

    private func markJobStatus(_ id: UUID, status: TranscriptionJobStatus, errorMessage: String?) throws {
        guard let index = transcriptionQueue.firstIndex(where: { $0.id == id }) else {
            throw NSError(
                domain: "RecorderViewModel",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Queue job \(id.uuidString) was not found."]
            )
        }

        transcriptionQueue[index].status = status
        transcriptionQueue[index].errorMessage = errorMessage
        transcriptionQueue[index].updatedAt = .now
        try persistQueue()
        recalculateQueueState()
    }

    private func nextQueuedJob() -> TranscriptionJob? {
        transcriptionQueue
            .filter { $0.status == .queued }
            .sorted(by: { $0.createdAt < $1.createdAt })
            .first
    }

    private func latestJob(for audioPath: String) -> TranscriptionJob? {
        transcriptionQueue
            .filter { $0.audioPath == audioPath }
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first
    }

    private func persistQueue() throws {
        try store.saveTranscriptionQueue(transcriptionQueue)
    }

    private func recalculateQueueState() {
        queuedJobCount = transcriptionQueue.filter { $0.status == .queued }.count
        runningJobID = transcriptionQueue.first(where: { $0.status == .running })?.id
    }

    private func removeQueueJobs(forAudioPath audioPath: String) {
        transcriptionQueue.removeAll { $0.audioPath == audioPath }

        do {
            try persistQueue()
            recalculateQueueState()
        } catch {
            statusMessage = "Failed to update transcription queue after delete: \(error.localizedDescription)"
        }
    }

    private func rebindQueueJobs(fromAudioPath oldPath: String, toAudioPath newPath: String) throws {
        for index in transcriptionQueue.indices where transcriptionQueue[index].audioPath == oldPath {
            transcriptionQueue[index] = TranscriptionJob(
                id: transcriptionQueue[index].id,
                audioPath: newPath,
                modelPath: transcriptionQueue[index].modelPath,
                language: transcriptionQueue[index].language,
                summaryEmbeddingModelPath: transcriptionQueue[index].summaryEmbeddingModelPath,
                summaryModelPath: transcriptionQueue[index].summaryModelPath,
                status: transcriptionQueue[index].status,
                errorMessage: transcriptionQueue[index].errorMessage,
                createdAt: transcriptionQueue[index].createdAt,
                updatedAt: .now
            )
        }
        try persistQueue()
        recalculateQueueState()
    }

    private func loadTranscript(for item: RecordingItem) throws {
        selectedTranscript = try store.loadTranscript(for: item)
        selectedSummary = try store.loadSummary(for: item)
    }

    private func scheduleLiveUpdates() {
        liveUpdateTimer?.invalidate()
        liveUpdateTimer = Timer.scheduledTimer(withTimeInterval: Self.liveUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.liveUpdateTask?.cancel()
                self.liveUpdateTask = Task { @MainActor [weak self] in
                    await self?.refreshLiveTranscript(finalPass: false)
                }
            }
        }
    }

    private func refreshLiveTranscript(finalPass: Bool) async {
        guard let activeRecordingURL, let liveSession else {
            return
        }

        if !finalPass && isTranscribing {
            return
        }

        isTranscribing = true

        do {
            let result = try await transcribeLiveInBackground(
                with: liveSession,
                audioURL: activeRecordingURL,
                finalPass: finalPass
            )
            if finalPass {
                liveChunkTranscript = "Live chunk transcript will appear while recording."
            } else {
                liveChunkTranscript = result.liveChunkText ?? "Listening for chunk updates..."
            }
            if finalPass {
                try reloadRecordings()
                selectedRecordingIDs = [activeRecordingURL.path]
                selectedRecordingID = activeRecordingURL.path
                statusMessage = "Saved recording and transcript."
                selectedSummary = "Summary will be generated after final transcription finishes."
                self.liveSession = nil
            } else {
                statusMessage = "Recording and updating transcript..."
            }
        } catch {
            statusMessage = finalPass
                ? error.localizedDescription
                : "Live transcription update failed: \(error.localizedDescription)"
        }

        isTranscribing = false
    }

    private func exportItems(_ sourceURLs: [URL], to destinationDirectory: URL) throws {
        for sourceURL in sourceURLs {
            let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)
            do {
                try copyItemReplacingDestination(at: sourceURL, to: destinationURL)
            } catch {
                throw NSError(
                    domain: "RecorderViewModel.Export",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to export \(sourceURL.lastPathComponent): \(error.localizedDescription)"]
                )
            }
        }
    }

    private func exportItem(at sourceURL: URL, to destinationURL: URL) {
        do {
            try copyItemReplacingDestination(at: sourceURL, to: destinationURL)
            statusMessage = "Exported \(sourceURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func copyItemReplacingDestination(at sourceURL: URL, to destinationURL: URL) throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(
                domain: "RecorderViewModel.Export",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Source file not found: \(sourceURL.lastPathComponent)"]
            )
        }

        let normalizedSource = sourceURL.standardizedFileURL
        let normalizedDestination = destinationURL.standardizedFileURL

        if normalizedSource == normalizedDestination {
            return
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func ensureExportSourcesExist(_ sourceURLs: [URL]) throws {
        let missingFiles = sourceURLs.filter { !FileManager.default.fileExists(atPath: $0.path) }
        guard missingFiles.isEmpty else {
            let names = missingFiles.map(\.lastPathComponent).joined(separator: ", ")
            throw NSError(
                domain: "RecorderViewModel.Export",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Export failed because source files are missing: \(names)"]
            )
        }
    }

    private func firstRecordingID(in ids: Set<RecordingItem.ID>) -> RecordingItem.ID? {
        recordings.first(where: { ids.contains($0.id) })?.id
    }

    private func prepareLiveSession(configuration: WhisperConfiguration) throws -> String? {
        let modelPath = configuration.modelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelPath.isEmpty else {
            liveSession = nil
            return "Live transcription is unavailable until a model is selected."
        }

        do {
            liveSession = try transcriber.makeSession(configuration: configuration)
            return nil
        } catch {
            liveSession = nil
            return "Live transcription is unavailable: \(error.localizedDescription)"
        }
    }

    private func transcribeInBackground(audioURL: URL, configuration: WhisperConfiguration) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            let transcriber = WhisperTranscriber()
            return try transcriber.transcribe(audioURL: audioURL, configuration: configuration)
        }.value
    }

    private func transcribeLiveInBackground(
        with session: WhisperTranscriptionSession,
        audioURL: URL,
        finalPass: Bool
    ) async throws -> TranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try session.transcribeLive(audioURL: audioURL, finalPass: finalPass)
        }.value
    }

    private func summarizeIfConfigured(
        job: TranscriptionJob,
        transcriptText: String
    ) async throws -> SummaryOutcome {
        let configuration = LlamaSummaryConfiguration(
            embeddingModelPath: job.summaryEmbeddingModelPath,
            summaryModelPath: job.summaryModelPath
        )

        guard configuration.isConfigured else {
            return .skipped("Summary skipped because llama.cpp summary settings are incomplete.")
        }

        statusMessage = "Summarizing \(URL(fileURLWithPath: job.audioPath).lastPathComponent)..."

        do {
            let summary = try await summarizeInBackground(
                audioURL: URL(fileURLWithPath: job.audioPath),
                transcriptText: transcriptText,
                configuration: configuration
            )
            return .generated(summary)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func summarizeInBackground(
        audioURL: URL,
        transcriptText: String,
        configuration: LlamaSummaryConfiguration
    ) async throws -> SummaryResult {
        try await Task.detached(priority: .userInitiated) {
            let service = LlamaSummaryService()
            return try service.summarize(
                transcriptText: transcriptText,
                audioURL: audioURL,
                configuration: configuration
            )
        }.value
    }
}

private enum SummaryOutcome {
    case generated(SummaryResult)
    case skipped(String)
    case failed(String)
}
