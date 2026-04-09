# Sidebar files flat list

## Summary
- Removed the explicit `Files` section wrapper (header + section divider) from the sidebar so recordings appear as part of the main scrollable sidebar flow.
- Kept the recordings `List` and context menu actions unchanged, preserving selection, multi-select, drag-drop import, and file actions.
- Moved the queue count indicator to a small top-right overlay on the recordings list so queue visibility remains without reintroducing a separate section header.

## Notes for next task
- Queue count currently overlays within the recordings list area (`ZStack` top trailing). If this competes visually with row content, consider moving it to a footer/status area.
