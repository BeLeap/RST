# Sidebar buttons clipping fix

## Request
- User reported the lower action buttons in the left sidebar were still being clipped.

## Root cause
- The `Files` list used a hard `minHeight` of `260`, which consumed too much vertical space in shorter window heights.
- This pushed the bottom action buttons toward/under the visible lower edge.

## Changes made
- Updated `RST/Features/RecorderView.swift`.
- Changed the recordings `List` frame from `.frame(minHeight: 260)` to `.frame(minHeight: 120, idealHeight: 220)`.

## Rationale
- Keeps the list usable but allows it to shrink on shorter windows, preserving space for the bottom button area.
- Reduces clipping risk without changing action behavior.

## Notes
- Layout-only update.
