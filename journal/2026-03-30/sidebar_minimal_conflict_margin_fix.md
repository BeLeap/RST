# Sidebar minimal-conflict bottom margin fix

## Request
- User noted the previous approach conflicted with `master` and asked for a more content-aware/minimal change.

## Changes made
- Reverted the large sidebar structural rewrite.
- Applied a minimal layout tweak in `RST/Features/RecorderView.swift`:
  - Added `.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 8) }` to the sidebar container.

## Rationale
- Keeps original layout structure intact (lower merge/conflict risk).
- Adds explicit bottom inset near the sidebar edge without aggressively shrinking list/content heights.

## Notes
- Layout-only change.
