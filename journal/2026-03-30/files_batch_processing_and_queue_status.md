# Files batch processing and queue status

## What changed
- Added per-recording transcription state in `RecorderViewModel`:
  - `activelyTranscribingRecordingID`
  - `queuedTranscriptionRecordingIDs`
- Added queueing flow with `enqueueTranscription(audioURL:configuration:)` so incoming transcription requests while another is running are queued instead of silently ignored.
- Prevented duplicate queue entries for the same file and surfaced explicit status messages for already-processing files.
- Added `transcriptionQueuePosition(for:)` to expose queue position to the UI.
- Updated Files list row UI to show:
  - `Batch processing` badge for the currently-running item
  - `Queue #N` badge for queued items

## Why
User requested clearer state visibility in Files: show when an item is currently in batch processing and, when queued, display its queue position.

## Notes
- Queue execution currently uses the same `WhisperConfiguration` as the request that started processing.
- Missing queued files are explicitly surfaced via status message and skipped.
