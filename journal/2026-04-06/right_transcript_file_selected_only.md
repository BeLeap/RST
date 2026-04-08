# Keep right transcript panel file-selection-only while live PiP is active

## What changed
- Stopped mutating `selectedTranscript` and `selectedSummary` when a new recording starts.
- Stopped writing live realtime transcript text into `selectedTranscript` during periodic live updates.
- Left `liveChunkTranscript` updates unchanged so realtime text continues to appear in the PiP overlay only.

## Why
- With the realtime PiP window now present, the right-side transcript panel should remain focused on the currently selected item in **Files** instead of switching to live text during recording.

## Notes
- Final/batch transcription flow after recording stop is unchanged; selecting a file still loads transcript/summary from disk as before.
