# Sidebar bottom button margin adjustment

## Request
- User reported the left sidebar's bottom button area looked like it had no bottom margin.

## Changes made
- Updated `RST/Features/RecorderView.swift`.
- Added `.padding(.bottom, 8)` to the bottom action button `VStack` in the **Files** section.

## Rationale
- Adds clear breathing room below the bottom button block so it does not visually hug the lower edge.
- Keeps all existing actions and disabled state behavior intact.

## Notes
- Layout-only tweak; no recording/transcription/data-flow logic changed.
