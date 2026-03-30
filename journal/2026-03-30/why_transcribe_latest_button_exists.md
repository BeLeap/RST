# Why the "Transcribe Latest" button exists

## Context
- User asked why the sidebar Recorder section has a **Transcribe Latest** action.

## Findings
- `RecorderView` places **Transcribe Latest** in the Recorder action row and wires it to `viewModel.transcribeLatest(configuration: batchWhisperConfiguration)`.
- `transcribeLatest` in `RecorderViewModel` chooses `activeRecordingURL` first, and falls back to the newest saved recording (`recordings.first?.audioURL`) if there is no active one.
- This gives a one-click way to re-run batch transcription for the most recent audio without opening each file context menu.
- There is also a per-file **Transcribe** action in the Files list context menu (`transcribeSelected`), which is for explicit target selection.
- Stop recording already triggers final transcription automatically, but **Transcribe Latest** remains useful for manual re-transcription (e.g., after changing batch model settings).

## Notes for next task
- If users find this redundant, potential UI refinements:
  - Rename to **Re-transcribe Latest** for clarity.
  - Hide the button when there are no recordings.
  - Move manual transcription controls entirely into Files context menu if reducing sidebar actions is preferred.
