# Sidebar bottom buttons layout fix

## Request
- User reported that text in the small buttons at the bottom of the left sidebar was clipped.

## Changes made
- Updated `RST/Features/RecorderView.swift` in the **Files** section.
- Replaced the bottom action button container from a horizontal `HStack` to a vertical `VStack`.
- Kept all existing button actions and disabled-state conditions unchanged.

## Rationale
- In a narrow sidebar, multiple action buttons in a single row force labels to truncate.
- A vertical stack gives each button enough width to display full labels reliably.

## Notes
- This is a UI/layout-only change; no recording/transcription logic changed.
