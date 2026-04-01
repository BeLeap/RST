# Files list multiselect + shift-click range selection

## Summary
- Switched the Files list selection binding from a single `RecordingItem.ID?` to `Set<RecordingItem.ID>` in the view so macOS list multi-selection behavior (including click + shift-click range selection) is enabled.
- Added `selectedRecordingIDs` handling in `RecorderViewModel` with normalization against current recordings and primary-selection synchronization for transcript/detail behavior.
- Added bulk delete support (`deleteRecordings(ids:)`) so deleting after multi-select removes all selected items in one confirmation flow.
- Updated delete confirmation state in `RecorderView` to support confirming deletion for both single-item context-menu deletes and multi-selected deletes.

## Notes for follow-up
- Current action menu items still run against the primary selected item (for rename/transcribe/export/reveal). If needed, batch actions (e.g., transcribe selected) can be added in a follow-up.
