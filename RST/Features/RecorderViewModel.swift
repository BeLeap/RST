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
    private let transcriber: WhisperCLITranscriber
    private var activeRecordingURL: URL?

    init(
        store: TranscriptStore = TranscriptStore(),
        recorder: AudioRecorderService = AudioRecorderService(),
        transcriber: WhisperCLITranscriber = WhisperCLITranscriber()
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

    func startRecording() async {
        do {
            try store.ensureDirectories()
            try await recorder.requestPermission()
            let url = try store.nextRecordingURL()
            try recorder.startRecording(to: url)
            activeRecordingURL = url
            isRecording = true
            statusMessage = "Recording to \(url.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func stopRecording() {
        do {
            let url = try recorder.stopRecording()
            activeRecordingURL = url
            isRecording = false
            try reloadRecordings()
            selectedRecordingID = url.path
            if let item = selectedRecording {
                try loadTranscript(for: item)
            }
            statusMessage = "Saved recording \(url.lastPathComponent)"
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
        guard let activeRecordingURL ?? recordings.first?.audioURL else {
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

    private func transcribe(audioURL: URL, configuration: WhisperConfiguration) async {
        isTranscribing = true
        statusMessage = "Transcribing \(audioURL.lastPathComponent) with local Whisper..."

        do {
            let result = try await transcriber.transcribe(audioURL: audioURL, configuration: configuration)
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
}
