# Whisper repetition detection error handling

## Summary
- Replaced silent consecutive-duplicate removal with explicit repetition detection in transcription assembly.
- Added `WhisperTranscriptionError.suspiciousRepetitionDetected` so repeated segment loops now fail loudly with the repeated text and count.
- Applied repetition detection to both final transcription and live chunk transcription paths.

## Notes for next task
- Threshold is currently 6 consecutive repeats for normalized text with at least 12 characters.
- If users still see false positives/negatives, expose threshold settings or tune based on collected telemetry/log samples.
