# Delete recording feature

## What changed
- Added `TranscriptStore.deleteRecording(_:)` to remove:
  - selected WAV file
  - matching `-transcript.txt` if present
  - matching `-transcript.json` if present
- Added `RecorderViewModel.deleteSelectedRecording()` to drive deletion from UI, reload list, keep selection stable, and surface explicit errors.
- Added a destructive **Delete Recording** action in the files toolbar with confirmation alert.

## Notes
- Deletion is blocked while recording or transcription is in progress.
- Error handling intentionally surfaces failures via `statusMessage` (no silent fallback).
