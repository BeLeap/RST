# Live chunk transcript PiP overlay

## What changed
- Replaced the sidebar-bottom live chunk section with a global PiP-style overlay anchored to the bottom-right of the app.
- The overlay appears only while recording (`viewModel.isRecording`) to keep normal browsing uncluttered.
- Kept the live chunk text source as `viewModel.liveChunkTranscript` and reused monospaced selectable text for quick verification.

## Why
- Follow-up request asked for a global bottom placement, specifically PiP-like behavior instead of a sidebar-local panel.

## Notes
- Existing live chunk generation and state updates in `RecorderViewModel`/`WhisperTranscriber` were retained.
