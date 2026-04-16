# Files section flat scroll

## Summary
- Updated the sidebar recordings `List` to disable its internal scrolling so the Files area participates in the parent sidebar scroll flow.
- Removed the recordings container `maxHeight: .infinity` constraint to avoid creating a separate scrollable pane behavior.

## Notes for next task
- Multi-select behavior remains bound to `List(selection:)`; if users request fully custom row interactions later, we may need a non-`List` implementation.
