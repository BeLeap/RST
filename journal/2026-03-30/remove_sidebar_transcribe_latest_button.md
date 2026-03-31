# Remove sidebar "Transcribe Latest" button

## Request
- User feedback: keeping only the Files context-menu transcription flow is sufficient.

## What changed
- Removed the Recorder-section sidebar button **Transcribe Latest** from `RecorderView`.
- Kept manual transcription available through the per-file context menu **Transcribe** action in Files.
- Removed now-unused `RecorderViewModel.transcribeLatest(configuration:)` for tidy code and to avoid dead paths.

## Why
- Reduces duplicated entry points for manual transcription.
- Keeps interaction focused on explicit per-file actions in the Files list.

## Notes for next task
- If needed later, a clearer global action could be reintroduced as **Re-transcribe Selected** to align with selection-based workflow.
