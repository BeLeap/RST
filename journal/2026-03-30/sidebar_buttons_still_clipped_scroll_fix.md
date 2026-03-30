# Sidebar buttons still clipped: scroll layout fix

## Request
- User reported that bottom buttons in the left sidebar were still clipped after the previous bottom-padding-only adjustment.

## Changes made
- Updated `RST/Features/RecorderView.swift` sidebar container structure.
- Wrapped the entire sidebar content in a `ScrollView`.
- Removed the trailing `Spacer()` that forced static vertical layout pressure.
- Kept existing button actions and disabled-state logic unchanged.
- Kept bottom padding on the bottom action-button group.

## Rationale
- A fixed vertical stack can still clip lower controls when window height is small.
- Allowing the sidebar to scroll ensures controls remain accessible instead of being cut off.

## Notes
- This is a layout/UX fix only; no recorder/transcription business logic changed.
