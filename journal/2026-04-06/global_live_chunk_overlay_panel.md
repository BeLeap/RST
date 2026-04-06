# Global live chunk overlay panel

## What changed
- Removed the in-app live chunk PiP overlay from `RecorderView`.
- Added `LiveChunkOverlayController` that manages a non-activating floating `NSPanel` with SwiftUI content bound to `RecorderViewModel`.
- Configured the panel to remain visible across app switches/spaces (`.canJoinAllSpaces`, `.fullScreenAuxiliary`) and show above other apps (`.statusBar`, `orderFrontRegardless`).
- Wired the controller in `RSTApp` so recording state changes show/hide the global panel.

## Why
- Follow-up request asked for truly global visibility while using other apps (e.g., taking notes) to verify recording/transcription activity.

## Notes
- Panel is intentionally non-key/non-main so it does not steal focus while typing in other apps.
