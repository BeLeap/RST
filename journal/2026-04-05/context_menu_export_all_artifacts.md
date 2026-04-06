# Context menu export all artifacts

## Summary
- Added a new context-menu action to export WAV, transcript TXT, and summary TXT in one step.
- Added a folder picker helper to `PanelPicker` so batch export can target a destination directory.
- Refactored export copy logic in `RecorderViewModel` to share replacement-safe copy behavior between single-file and multi-file exports.

## Notes
- The new action is disabled unless both transcript and summary files exist.
- Export intentionally fails fast with explicit status messages if required artifacts are missing.
