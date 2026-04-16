import SwiftUI

struct RecorderView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @StateObject private var whisperModelStore = WhisperModelStore()
    @StateObject private var llamaModelStore = LlamaModelStore()
    @State private var pendingDeleteRecordingID: RecordingItem.ID?
    @State private var isShowingDeleteConfirmation = false
    @State private var isFileDropTargeted = false

    @AppStorage("whisperLiveModelSelection") private var whisperLiveModelSelection = "tiny"
    @AppStorage("whisperLiveModelPath") private var whisperLiveModelPath = ""
    @AppStorage("whisperBatchModelSelection") private var whisperBatchModelSelection = WhisperModelPreset.customID
    @AppStorage("whisperBatchModelPath") private var whisperBatchModelPath = ""
    @AppStorage("whisperLanguage") private var whisperLanguage = "auto"
    @AppStorage("llamaEmbeddingModelSelection") private var llamaEmbeddingModelSelection = LlamaModelPreset.customID
    @AppStorage("llamaEmbeddingModelPath") private var llamaEmbeddingModelPath = ""
    @AppStorage("llamaSummaryModelSelection") private var llamaSummaryModelSelection = LlamaModelPreset.customID
    @AppStorage("llamaSummaryModelPath") private var llamaSummaryModelPath = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .task(id: "\(whisperLiveModelSelection)|\(whisperBatchModelSelection)|\(llamaEmbeddingModelSelection)|\(llamaSummaryModelSelection)") {
            await whisperModelStore.prepareSelection(whisperLiveModelSelection)
            if whisperBatchModelSelection != whisperLiveModelSelection {
                await whisperModelStore.prepareSelection(whisperBatchModelSelection)
            }

            await llamaModelStore.prepareSelection(llamaEmbeddingModelSelection)
            if llamaSummaryModelSelection != llamaEmbeddingModelSelection {
                await llamaModelStore.prepareSelection(llamaSummaryModelSelection)
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
                                Text(whisperModelStore.localPath(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                HStack(spacing: 8) {
                                    Button(whisperModelStore.isDownloaded(preset) ? "Redownload" : "Download") {
                                        Task {
                                            await whisperModelStore.redownloadSelectedModel(whisperLiveModelSelection)
                                        }
                                    }
                                    .disabled(whisperModelStore.activeDownloadID != nil)

                                    if whisperModelStore.activeDownloadID == preset.id {
                                        Button("Cancel") {
                                            whisperModelStore.cancelActiveDownload()
                                        }
                                    }

                                    Button("Open Models Folder") {
                                        whisperModelStore.openModelsFolder()
                                    }

                                    if whisperModelStore.activeDownloadID == preset.id {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let activeDownloadProgress = whisperModelStore.activeDownloadProgress {
                                                ProgressView(value: activeDownloadProgress, total: 1.0)
                                                    .frame(width: 120)
                                                    .controlSize(.small)
                                            } else {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }

                                            if let remainingTime = whisperModelStore.activeDownloadRemainingTime {
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
                                Text(whisperModelStore.localPath(for: preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                HStack(spacing: 8) {
                                    Button(whisperModelStore.isDownloaded(preset) ? "Redownload" : "Download") {
                                        Task {
                                            await whisperModelStore.redownloadSelectedModel(whisperBatchModelSelection)
                                        }
                                    }
                                    .disabled(whisperModelStore.activeDownloadID != nil)

                                    if whisperModelStore.activeDownloadID == preset.id {
                                        Button("Cancel") {
                                            whisperModelStore.cancelActiveDownload()
                                        }
                                    }

                                    if whisperModelStore.activeDownloadID == preset.id {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let activeDownloadProgress = whisperModelStore.activeDownloadProgress {
                                                ProgressView(value: activeDownloadProgress, total: 1.0)
                                                    .frame(width: 120)
                                                    .controlSize(.small)
                                            } else {
                                                ProgressView()
                                                    .controlSize(.small)
                                            }

                                            if let remainingTime = whisperModelStore.activeDownloadRemainingTime {
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
                            whisperModelStore.openModelsFolder()
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Language")
                            .font(.headline)
                        TextField("auto", text: $whisperLanguage)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("llama.cpp Summary")
                            .font(.headline)

                        llamaModelSection(
                            title: "Embedding Model",
                            role: .embedding,
                            selection: $llamaEmbeddingModelSelection,
                            customPath: $llamaEmbeddingModelPath,
                            browseTitle: "Choose embedding model"
                        )

                        llamaModelSection(
                            title: "Summary Model",
                            role: .summary,
                            selection: $llamaSummaryModelSelection,
                            customPath: $llamaSummaryModelPath,
                            browseTitle: "Choose summary model"
                        )

                        Button("Open Models Folder") {
                            llamaModelStore.openModelsFolder()
                        }
                    }

                    Text("Live: \(whisperModelStore.selectionSummary(selectedModelID: whisperLiveModelSelection, customModelPath: whisperLiveModelPath))")
                        .font(.footnote)
                        .foregroundStyle(whisperModelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Batch: \(whisperModelStore.selectionSummary(selectedModelID: whisperBatchModelSelection, customModelPath: whisperBatchModelPath))")
                        .font(.footnote)
                        .foregroundStyle(whisperModelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Embedding: \(llamaModelStore.selectionSummary(selectedModelID: llamaEmbeddingModelSelection, customModelPath: llamaEmbeddingModelPath))")
                        .font(.footnote)
                        .foregroundStyle(llamaModelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Summary: \(llamaModelStore.selectionSummary(selectedModelID: llamaSummaryModelSelection, customModelPath: llamaSummaryModelPath))")
                        .font(.footnote)
                        .foregroundStyle(llamaModelStore.lastErrorMessage == nil ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The app stores WAV recordings locally, exports compressed M4A audio, transcribes with embedded Whisper, and can summarize final transcripts through embedded llama.cpp.")
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
                                await viewModel.stopRecording(
                                    finalConfiguration: batchWhisperConfiguration,
                                    summaryConfiguration: llamaSummaryConfiguration
                                )
                            }
                        }
                        .keyboardShortcut(".", modifiers: [.command])
                        .disabled(!viewModel.isRecording)
                    }

                    HStack(spacing: 12) {
                        Button("Open Recordings Folder") {
                            viewModel.openRecordingsFolder()
                        }
                    }
                }

                ZStack(alignment: .topTrailing) {
                    List(viewModel.recordings, selection: Binding(
                        get: { viewModel.selectedRecordingIDs },
                        set: { viewModel.setSelectedRecordings(ids: $0) }
                    )) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.transcriptionStatusText(for: item))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Rename…") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.renameRecording(id: item.id)
                            }

                            Button("Delete", role: .destructive) {
                                if viewModel.selectedRecordingIDs.contains(item.id),
                                   viewModel.selectedRecordingIDs.count > 1 {
                                    pendingDeleteRecordingID = nil
                                    isShowingDeleteConfirmation = true
                                } else {
                                    viewModel.selectRecording(id: item.id)
                                    pendingDeleteRecordingID = item.id
                                    isShowingDeleteConfirmation = true
                                }
                            }

                            Divider()

                            Button("Transcribe") {
                                viewModel.selectRecording(id: item.id)
                                Task {
                                    await viewModel.transcribeSelected(
                                        configuration: batchWhisperConfiguration,
                                        summaryConfiguration: llamaSummaryConfiguration
                                    )
                                }
                            }
                            .disabled(viewModel.isRecording)

                            Button("Summarize") {
                                viewModel.selectRecording(id: item.id)
                                Task {
                                    await viewModel.summarizeSelected(
                                        summaryConfiguration: llamaSummaryConfiguration
                                    )
                                }
                            }
                            .disabled(viewModel.isRecording || item.transcriptURL == nil)

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

                            Button("Export All") {
                                viewModel.selectRecording(id: item.id)
                                viewModel.exportAll()
                            }
                            .disabled(item.transcriptURL == nil || item.summaryURL == nil)
                        }
                    }
                    .scrollDisabled(true)

                    if isFileDropTargeted {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                            )
                            .overlay(
                                Text("Drop WAV/M4A/MP3/AAC/MP4 audio to import as WAV")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            )
                            .padding(8)
                            .allowsHitTesting(false)
                    }

                    if viewModel.queuedJobCount > 0 {
                        Text("Queue: \(viewModel.queuedJobCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        .padding(.trailing, 12)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 260)
                .onDrop(of: ["public.file-url"], isTargeted: $isFileDropTargeted) { providers in
                    viewModel.importDroppedAudio(providers: providers)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            }
            .padding(20)
            .frame(minWidth: 340, alignment: .topLeading)
        }
        .frame(minWidth: 340, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete recording?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let pendingDeleteRecordingID else {
                    viewModel.deleteSelectedRecording()
                    return
                }
                viewModel.deleteRecording(id: pendingDeleteRecordingID)
                self.pendingDeleteRecordingID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteRecordingID = nil
            }
        } message: {
            Text("This removes the selected recording and related transcript files from disk.")
        }
    }

    private func llamaModelSection(
        title: String,
        role: LlamaModelRole,
        selection: Binding<String>,
        customPath: Binding<String>,
        browseTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Picker(title, selection: selection) {
                Text("Custom Path").tag(LlamaModelPreset.customID)
                ForEach(LlamaModelPreset.catalog(for: role)) { preset in
                    Text("\(preset.name) (\(preset.sizeDescription))").tag(preset.id)
                }
            }
            .pickerStyle(.menu)

            if let preset = LlamaModelPreset.preset(id: selection.wrappedValue) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(llamaModelStore.localPath(for: preset))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Button(llamaModelStore.isDownloaded(preset) ? "Redownload" : "Download") {
                            Task {
                                await llamaModelStore.redownloadSelectedModel(selection.wrappedValue)
                            }
                        }
                        .disabled(llamaModelStore.activeDownloadID != nil)

                        if llamaModelStore.activeDownloadID == preset.id {
                            Button("Cancel") {
                                llamaModelStore.cancelActiveDownload()
                            }
                        }

                        if llamaModelStore.activeDownloadID == preset.id {
                            VStack(alignment: .leading, spacing: 4) {
                                if let activeDownloadProgress = llamaModelStore.activeDownloadProgress {
                                    ProgressView(value: activeDownloadProgress, total: 1.0)
                                        .frame(width: 120)
                                        .controlSize(.small)
                                } else {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                if let remainingTime = llamaModelStore.activeDownloadRemainingTime {
                                    Text("\(remainingTime) remaining")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                pathField(title: "\(title) (.gguf)", text: customPath, browseAction: {
                    if let url = PanelPicker.chooseFile(title: browseTitle, allowedFileTypes: ["gguf"]) {
                        customPath.wrappedValue = url.path
                    }
                })
            }
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
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.title3.bold())
                        Text(viewModel.selectedSummary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcript")
                            .font(.title3.bold())
                        Text(viewModel.selectedTranscript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
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
            modelPath: whisperModelStore.resolveModelPath(
                selectedModelID: whisperLiveModelSelection,
                customModelPath: whisperLiveModelPath
            ),
            language: whisperLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var batchWhisperConfiguration: WhisperConfiguration {
        WhisperConfiguration(
            modelPath: whisperModelStore.resolveModelPath(
                selectedModelID: whisperBatchModelSelection,
                customModelPath: whisperBatchModelPath
            ),
            language: whisperLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var llamaSummaryConfiguration: LlamaSummaryConfiguration {
        LlamaSummaryConfiguration(
            embeddingModelPath: llamaModelStore.resolveModelPath(
                selectedModelID: llamaEmbeddingModelSelection,
                customModelPath: llamaEmbeddingModelPath
            ),
            summaryModelPath: llamaModelStore.resolveModelPath(
                selectedModelID: llamaSummaryModelSelection,
                customModelPath: llamaSummaryModelPath
            )
        )
    }
}
