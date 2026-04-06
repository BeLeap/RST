# Live chunk transcript indicator

## What changed
- Added a dedicated live chunk transcript field in `RecorderViewModel` so the UI can show per-refresh chunk output while recording.
- Extended `TranscriptionResult` with `liveChunkText` and populated it from the latest decoded live chunk in `WhisperTranscriptionSession.transcribeLive`.
- Added a new "Live Chunk Transcript" panel at the bottom of the sidebar in `RecorderView` so users can verify recording/transcription activity in real time.

## Why
- User requested a bottom-area live chunk display to confirm recording/transcription is actively working.

## Notes
- The chunk preview resets to a default instructional message when recording stops or a final pass completes.
