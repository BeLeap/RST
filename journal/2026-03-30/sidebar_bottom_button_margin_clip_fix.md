# Sidebar bottom button margin/clip fix

## Request
- User reported the bottom action button area in the left sidebar had no bottom margin and appeared clipped.

## Changes made
- Updated `RST/Features/RecorderView.swift`.
- Added bottom padding (`.padding(.bottom, 12)`) to the bottom action button group in the **Files** section.

## Rationale
- The extra bottom inset prevents the action button area from visually touching the sidebar edge and reduces clipping at the lower boundary.

## Notes
- UI-only spacing adjustment; no behavior changes to actions, selection, or recording/transcription flows.
