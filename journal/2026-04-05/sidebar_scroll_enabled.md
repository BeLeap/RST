# Sidebar scroll enabled

## Summary
- Wrapped the left sidebar container in a `ScrollView` so long sidebar content can be vertically scrolled when window height is limited.
- Kept the existing sidebar content structure and delete confirmation behavior unchanged.

## Notes for next task
- `Files` section still uses a `List` inside the sidebar; this remains independently scrollable for recordings while the overall sidebar is now scrollable.
