# Add Summarize context-menu action using llama.cpp

## What changed
- Added a new **Summarize** action in the Files row context menu in `RecorderView`.
- Wired the action to `RecorderViewModel.summarizeSelected(summaryConfiguration:)`.
- Disabled the action while recording and when the selected row has no transcript yet.

## View model behavior
- Added `summarizeSelected(summaryConfiguration:)` in `RecorderViewModel`.
- The method now:
  - Fails fast with clear status messages when no recording is selected.
  - Fails fast when no transcript exists for the selected recording.
  - Validates llama.cpp summary config before doing work.
  - Loads transcript text from disk and runs `summarizeInBackground(...)`.
  - Reloads recordings after summary generation and updates `selectedSummary`.
  - Surfaces explicit error status on failure.

## Notes for next task
- Summarize remains a **single-item** action (it follows the right-clicked item by selecting that row first).
- Existing queued transcription flow is unchanged; this is an on-demand summary path for already transcribed audio.
