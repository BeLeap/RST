# Move sidebar bottom actions to row context menu

## Request
- User suggested that actions in the bottom button area should be handled from the recording row right-click menu instead.

## Changes made
- Updated `RST/Features/RecorderView.swift` in the Files section.
- Removed the bottom action-button stack entirely (Transcribe/Reveal/Export/Rename/Delete).
- Expanded each recording row context menu to include `Export Audio` and `Export Transcript` so the removed bottom actions remain available per-item.
- Kept existing per-row selection behavior (`viewModel.selectRecording(id:)`) before action execution.

## Rationale
- Consolidating file actions into a single per-item context menu reduces sidebar clutter.
- Removing the bottom action area also eliminates the original clipping hotspot without relying on extra spacing.

## Notes
- This is a UI interaction simplification; no model/transcription engine logic changed.
