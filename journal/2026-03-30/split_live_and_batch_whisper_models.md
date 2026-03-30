# Split live and batch Whisper models

## What changed
- Split model settings in the sidebar into two independent selections:
  - **Live Model (realtime)** used only while recording for periodic transcript updates.
  - **Batch Model (final transcript)** used for manual transcribe actions and post-stop final transcription.
- Updated the view model stop flow to run final transcription with the batch configuration instead of reusing the live transcription session.
- Kept explicit error behavior: invalid/missing model paths still surface as clear status messages (no silent fallback).

## Notes
- The UI still uses the same model downloader/store, and prepares downloads for both selected presets.
- Default live model is `tiny` to prioritize speed for realtime feedback.
