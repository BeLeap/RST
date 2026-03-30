import SwiftUI

struct RecorderView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @StateObject private var modelStore = WhisperModelStore()
    @State private var pendingDeleteRecordingID: RecordingItem.ID?

    @AppStorage("whisperLiveModelSelection") private var whisperLiveModelSelection = "tiny"
    @AppStorage("whisperLiveModelPath") private var whisperLiveModelPath = ""
    @AppStorage("whisperBatchModelSelection") private var whisperBatchModelSelection = WhisperModelPreset.customID
    @AppStorage("whisperBatchModelPath") private var whisperBatchModelPath = ""
    @AppStorage("whisperLanguage") private var whisperLanguage = "auto"

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .task(id: "\(whisperLiveModelSelection)|\(whisperBatchModelSelection)") {
            await modelStore.prepareSelection(whisperLiveModelSelection)
            if whisperBatchModelSelection != whisperLiveModelSelection {
                await modelStore.prepareSelection(whisperBatchModelSelection)
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local Whisper")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Live Model (realtime)")
                            .font(.headline)

                        Picker("Live Model", selection: $whisperLiveModelSelection) {
                            Text("Custom Path").tag(WhisperModelPreset.customID)
                            ForEach(WhisperModelPreset.catalog) { preset in
                                Text("\(preset.name) (\(preset.sizeDescription))").tag(preset.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if let preset = WhisperModelPreset.preset(id: whisperLiveModelSelection) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(modelStore.localPath(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                HStack(spacing: 8) {
                                    Button(modelStore.isDownloaded(preset) ? "Redownload" : "Download") {
                                        Task {
                                            await modelStore.redownloadSelectedModel(whisperLiveModelSelection)
                                        }
                                    }
                                    .disabled(modelStore.activeDownloadID != nil)

                                    if modelStore.activeDownloadID == preset.id {
                                        Button("Cancel") {
                                            modelStore.cancelActiveDownload()
                                        }
                                    }

                                    Button("Open Models Folder") {
                                        modelStore.openModelsFolder()
                                    }

                                    if modelStore.activeDownloadID == preset.id {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let activeDownloadProgress = modelStore.activeDownloadProgress {
                                                ProgressView(value: activeDownloadProgress, total: 1.0)
                                                    .frame(width: 120)
                                                    .controlSize(.small)
                                            } else {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }

                                            if let remainingTime = modelStore.activeDownloadRemainingTime {
                                                Text("\(remainingTime) remaining")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            pathField(title: "Live Model (.bin)", text: $whisperLiveModelPath, browseAction: {
                                if let url = PanelPicker.chooseFile(title: "Choose Whisper model", allowedFileTypes: ["bin"]) {
                                    whisperLiveModelPath = url.path
                                }
                            })
                        }

                        Text("Batch Model (final transcript)")
                            .font(.headline)

                        Picker("Batch Model", selection: $whisperBatchModelSelection) {
                            Text("Custom Path").tag(WhisperModelPreset.customID)
                            ForEach(WhisperModelPreset.catalog) { preset in
                                Text("\(preset.name) (\(preset.sizeDescription))").tag(preset.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if let preset = WhisperModelPreset.preset(id: whisperBatchModelSelection) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(modelStore.localPath(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                HStack(spacing: 8) {
                                    Button(modelStore.isDownloaded(preset) ? "Redownload" : "Download") {
                                        Task {
                                            await modelStore.redownloadSelectedModel(whisperBatchModelSelection)
                                        }
                                    }
                                    .disabled(modelStore.activeDownloadID != nil)

                                    if modelStore.activeDownloadID == preset.id {
                                        Button("Cancel") {
                                            modelStore.cancelActiveDownload()
                                        }
                                    }

                                    if modelStore.activeDownloadID == preset.id {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let activeDownloadProgress = modelStore.activeDownloadProgress {
                                                ProgressView(value: activeDownloadProgress, total: 1.0)
                                                    .frame(width: 120)
                                                    .controlSize(.small)
                                            } else {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }

                                            if let remainingTime = modelStore.activeDownloadRemainingTime {
                                                Text("\(remainingTime) remaining")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            pathField(title: "Batch Model (.bin)", text: $whisperBatchModelPath, browseAction: {
                                if let url = PanelPicker.chooseFile(title: "Choose Whisper model", allowedFileTypes: ["bin"]) {
                                    whisperBatchModelPath = url.path
                                }
                            })
                        }

                        Button("Open Models Folder") {
                            modelStore.openModelsFolder()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Language")
                            .font(.headline)
                        TextField("auto", text: $whisperLanguage)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("Live: \(modelStore.selectionSummary(selectedModelID: whisperLiveModelSelection, customModelPath: whisperLiveModelPath))")
                        .font(.footnote)
                        .foregroundStyle(modelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Batch: \(modelStore.selectionSummary(selectedModelID: whisperBatchModelSelection, customModelPath: whisperBatchModelPath))")
                        .font(.footnote)
                        .foregroundStyle(modelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The app records WAV files locally and transcribes them with embedded Whisper. No external API is used.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recorder")
                        .font(.title3.bold())

                    HStack(spacing: 12) {
                        Button("Start Recording") {
                            Task {
                                await viewModel.startRecording(configuration: whisperConfiguration)
                            }
                        }
                        .keyboardShortcut("r")
                        .disabled(viewModel.isRecording)

                        Button("Stop Recording") {
                            Task {
                                await viewModel.stopRecording(finalConfiguration: batchWhisperConfiguration)
                            }
                        }
                        .keyboardShortcut(".", modifiers: [.command])
                        .disabled(!viewModel.isRecording)
                    }

                    HStack(spacing: 12) {
                        Button("Transcribe Latest") {
                            Task {
                                await viewModel.transcribeLatest(configuration: batchWhisperConfiguration)
                            }
                        }
                        .disabled(viewModel.isRecording || viewModel.isTranscribing)

                        Button("Open Recordings Folder") {
                            viewModel.openRecordingsFolder()
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Files")
                        .font(.title3.bold())

                    List(viewModel.recordings, selection: Binding(
                        get: { viewModel.selectedRecordingID },
                        set: { viewModel.selectRecording(id: $0) }
                    )) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Rename…") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.renameRecording(id: item.id)
                            }

                            Button("Delete", role: .destructive) {
                                viewModel.selectRecording(id: item.id)
                                pendingDeleteRecordingID = item.id
                            }

                            Divider()

                            Button("Transcribe") {
                                viewModel.selectRecording(id: item.id)
                                Task {
                                    await viewModel.transcribeSelected(configuration: batchWhisperConfiguration)
                                }
                            }
                            .disabled(viewModel.isRecording || viewModel.isTranscribing)

                            Button("Reveal Audio") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.revealAudio()
                            }

                            Button("Reveal Transcript") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.revealTranscript()
                            }
                            .disabled(item.transcriptURL == nil)

                            Button("Export Audio") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.exportAudio()
                            }

                            Button("Export Transcript") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.exportTranscript()
                            }
                            .disabled(item.transcriptURL == nil)
                        }
                    }
                    .frame(minHeight: 260)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 340)
        .alert("Delete recording?", isPresented: Binding(
            get: { pendingDeleteRecordingID != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteRecordingID = nil
                }
            }
        )) {
            Button("Delete", role: .destructive) {
                guard let pendingDeleteRecordingID else {
                    viewModel.deleteSelectedRecording()
                    return
                }
                viewModel.deleteRecording(id: pendingDeleteRecordingID)
                self.pendingDeleteRecordingID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected recording and related transcript files from disk.")
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript")
                        .font(.largeTitle.bold())
                    Text(viewModel.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isTranscribing {
                    ProgressView()
                        .controlSize(.large)
                }
            }

            ScrollView {
                Text(viewModel.selectedTranscript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
        }
        .padding(24)
    }

    private func pathField(title: String, text: Binding<String>, browseAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            HStack(spacing: 8) {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
                Button("Browse", action: browseAction)
            }
        }
    }

    private var whisperConfiguration: WhisperConfiguration {
        WhisperConfiguration(
            modelPath: modelStore.resolveModelPath(
                selectedModelID: whisperLiveModelSelection,
                customModelPath: whisperLiveModelPath
            ),
            language: whisperLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var batchWhisperConfiguration: WhisperConfiguration {
        WhisperConfiguration(
            modelPath: modelStore.resolveModelPath(
                selectedModelID: whisperBatchModelSelection,
                customModelPath: whisperBatchModelPath
            ),
            language: whisperLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
