# Whisper repetition warning instead of hard failure

## Summary
- Replaced hard failure on repeated Whisper segments with warning-based diagnostics so transcription can still complete.
- Restored consecutive duplicate collapsing for output text, but now emits explicit warnings when pathological repetition patterns are detected.
- Extended `TranscriptionResult` with `warnings` and surfaced these warnings in recorder status messages for both queue/final and live transcription flows.

## Notes for next task
- Warnings are currently surfaced via `statusMessage`; if persistent diagnostics are needed, add structured log persistence per recording.
- Threshold remains 6 consecutive repeats for normalized text length >= 12 characters.
