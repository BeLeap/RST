# Files context menu with rename/delete

## What changed
- Added right-click context menu on each item in the Files list.
- Context menu now includes:
  - Rename…
  - Delete (destructive)
  - Transcribe
  - Reveal Audio
  - Reveal Transcript
- Added rename flow in `RecorderViewModel` using `NSAlert` + text field.
- Added `TranscriptStore.renameRecording(_:to:)` that renames WAV and associated transcript files (`.txt`, `.json`) together, with explicit error messages and rollback reporting.
- Kept existing delete confirmation flow, now also used by context-menu delete.

## Error-handling notes
- Rename validates empty names, invalid path separators, and duplicate file names.
- Rename failures are surfaced with explicit status messages.
- Transcript move failures include rollback status so partial-failure states are visible.
