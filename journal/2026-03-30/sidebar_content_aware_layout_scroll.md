# Sidebar content-aware layout with scrolling

## Request
- User feedback: previous fix pushed the lower button block up too much.
- Requested a more content-aware placement strategy.

## Changes made
- Updated `RST/Features/RecorderView.swift` sidebar container from a plain `VStack` to a `ScrollView` wrapping the same section stack.
- Restored recordings list sizing from `.frame(minHeight: 120, idealHeight: 220)` back to `.frame(minHeight: 260)`.
- Kept bottom action block padding to preserve visual breathing room.

## Why this is content-aware
- Sections now keep their intended natural sizes.
- When viewport height is short, the sidebar can scroll rather than compressing sections aggressively and making controls look pushed upward.

## Notes
- This is a layout-only change; view-model logic and button actions are unchanged.
