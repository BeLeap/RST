# Show active recording in Files while recording is in progress

## What changed
- Updated `RecorderViewModel.startRecording` to reload the Files list immediately after recording starts.
- Automatically selected the newly started recording in Files (`selectedRecordingID` / `selectedRecordingIDs`) so the right panel stays aligned with Files selection.
- Loaded transcript/summary from store for the selected item (which naturally resolves to "No transcript yet." / "No summary yet." early in recording).
- Preserved explicit error visibility: if Files refresh fails after recording starts, the status message now appends a concrete failure detail.

## Why
- Follow-up request asked to make in-progress recordings visible in Files to reduce confusion.
- This keeps UI mental model consistent: right panel is file-selection-driven, and the active recording is now also a file selection.

## Notes
- Live realtime text still remains in PiP (`liveChunkTranscript`) only.
