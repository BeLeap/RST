# Files panel scroll fix

## Summary
- Investigated the sidebar layout in `RecorderView` where `List` for the Files area was nested inside an outer `ScrollView`.
- Removed the outer `ScrollView` wrapper so the Files `List` can own vertical scrolling behavior.
- Set the Files section container to expand with `.frame(minHeight: 260, maxHeight: .infinity)` and aligned sidebar layout to top-leading with full available height.

## Rationale
- Nesting SwiftUI scroll containers (`List` inside `ScrollView`) can cause the inner list scrolling to be blocked or unreliable.
- Promoting the Files `List` to the primary scrollable region resolves the user-visible issue where the Files area did not scroll.

## Validation
- Attempted local build check, but `xcodebuild` is unavailable in this environment.
