import AppKit
import Foundation

@MainActor
final class RecorderViewModel: ObservableObject {
    @Published private(set) var recordings: [RecordingItem] = []
    @Published var selectedRecordingID: RecordingItem.ID?
    @Published private(set) var selectedTranscript = "No transcript selected."
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var statusMessage = "Ready."

    private let store: TranscriptStore
    private let recorder: AudioRecorderService
    private let transcriber: WhisperTranscriber
    private var activeRecordingURL: URL?
    private var liveSession: WhisperTranscriptionSession?
    private var liveUpdateTimer: Timer?
    private var liveUpdateTask: Task<Void, Never>?

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
            if let first = recordings.first {
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

    func reloadRecordings() throws {
        recordings = try store.loadRecordings()
    }

    func selectRecording(id: RecordingItem.ID?) {
        selectedRecordingID = id

        guard let item = recordings.first(where: { $0.id == id }) else {
            selectedTranscript = "No transcript selected."
            return
        }

        do {
            try loadTranscript(for: item)
        } catch {
            selectedTranscript = error.localizedDescription
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
            selectedTranscript = "Listening..."
            scheduleLiveUpdates()
            if let modelErrorMessage {
                statusMessage = "Recording to \(url.lastPathComponent). \(modelErrorMessage)"
            } else if liveSession == nil {
                statusMessage = "Recording to \(url.lastPathComponent). Live transcription is unavailable until a valid model path is set."
            } else {
                statusMessage = "Recording to \(url.lastPathComponent). Live transcription is active."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        do {
            liveUpdateTimer?.invalidate()
            liveUpdateTimer = nil
            let url = try recorder.stopRecording()
            activeRecordingURL = url
            isRecording = false
            try reloadRecordings()
            selectedRecordingID = url.path
            if let item = selectedRecording {
                try loadTranscript(for: item)
            }
            statusMessage = "Saved recording \(url.lastPathComponent)"
            Task {
                await refreshLiveTranscript(finalPass: true)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func transcribeSelected(configuration: WhisperConfiguration) async {
        guard let item = selectedRecording else {
            statusMessage = "Select a recording to transcribe."
            return
        }

        await transcribe(audioURL: item.audioURL, configuration: configuration)
    }

    func transcribeLatest(configuration: WhisperConfiguration) async {
        guard let activeRecordingURL = activeRecordingURL ?? recordings.first?.audioURL else {
            statusMessage = "There is no recording to transcribe."
            return
        }

        await transcribe(audioURL: activeRecordingURL, configuration: configuration)
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

        guard let destination = PanelPicker.saveFile(
            title: "Export Recording",
            suggestedName: recording.audioURL.lastPathComponent,
            allowedFileTypes: [recording.audioURL.pathExtension]
        ) else {
            return
        }

        exportItem(at: recording.audioURL, to: destination)
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

    private func transcribe(audioURL: URL, configuration: WhisperConfiguration) async {
        isTranscribing = true
        statusMessage = "Transcribing \(audioURL.lastPathComponent) with embedded Whisper..."

        do {
            let result = try transcriber.transcribe(audioURL: audioURL, configuration: configuration)
            try reloadRecordings()
            selectedRecordingID = audioURL.path
            selectedTranscript = result.transcriptText
            statusMessage = "Transcript saved to \(result.transcriptURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }

        isTranscribing = false
    }

    private func loadTranscript(for item: RecordingItem) throws {
        selectedTranscript = try store.loadTranscript(for: item)
    }

    private func scheduleLiveUpdates() {
        liveUpdateTimer?.invalidate()
        liveUpdateTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
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
            let result = try liveSession.transcribe(audioURL: activeRecordingURL)
            selectedTranscript = result.transcriptText.isEmpty ? "Listening..." : result.transcriptText
            if finalPass {
                try reloadRecordings()
                selectedRecordingID = activeRecordingURL.path
                statusMessage = "Saved recording and transcript."
                self.liveSession = nil
            } else {
                statusMessage = "Recording and updating transcript..."
            }
        } catch {
            if finalPass {
                statusMessage = error.localizedDescription
            }
        }

        isTranscribing = false
    }

    private func exportItem(at sourceURL: URL, to destinationURL: URL) {
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            statusMessage = "Exported \(sourceURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
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
}
