# Files list multi-selection with shift-click support

## Request
- Update the Files section to support multi-selection, including range selection via Shift-click.

## Changes made
- Switched `List` selection binding from a single optional recording ID to a `Set<RecordingItem.ID>`.
- Added multi-selection state handling in `RecorderViewModel` with `selectedRecordingIDs`.
- Preserved existing single-selection workflows by deriving a primary selected recording from the current ordered recordings list.
- Added `selectRecordings(ids:)` to handle list-driven multi-selection updates.
- Updated delete behavior:
  - `deleteSelectedRecording()` now deletes all selected items when multiple recordings are selected.
  - Added `deleteRecordings(ids:)` with explicit per-file error reporting and refresh-failure messaging.
- Kept context-menu actions targeting the clicked row by continuing to explicitly select that row before action execution.
- Added guardrails for rename to require exactly one selected recording.

## Notes for next task
- Current delete confirmation copy says "Delete recording?" even when multiple are selected. If desired, this can be improved to pluralize based on count.
- Transcript pane currently reflects a single "primary" selection when multiple files are selected; this is chosen by list order.
