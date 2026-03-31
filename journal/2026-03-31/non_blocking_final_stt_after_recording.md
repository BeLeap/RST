# non blocking final stt after recording

## Summary

- Confirmed final transcription was executing on `RecorderViewModel`'s `@MainActor` context, which can block UI updates when recording stops.
- Moved both final-pass transcription and live-update transcription work onto detached background tasks, then applied results back on the main actor.
- Updated live transcription error handling so incremental update failures are surfaced in `statusMessage` instead of being silently ignored.

## Verification

- `swift` source inspection confirms `transcribe(audioURL:configuration:)` now awaits `transcribeInBackground(...)`.
- `refreshLiveTranscript(finalPass:)` now awaits `transcribeLiveInBackground(...)` and reports non-final errors.

## Relevant files

- `RST/Features/RecorderViewModel.swift`
