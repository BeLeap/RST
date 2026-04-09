# Whisper consecutive duplicate sentence filter

## Summary
- Updated final-pass transcription assembly to build the transcript from decoded Whisper segments and remove consecutive duplicate segment text before writing the transcript file.
- Updated live transcription rendering to remove consecutive duplicate segments at display/join time so repeated hallucinated lines do not flood the visible transcript.
- Added a canonical text key (case/diacritic-insensitive with normalized whitespace) to make duplicate detection robust across minor formatting differences.

## Notes for next task
- The filter currently removes only consecutive duplicates. If repeated non-consecutive loops appear, consider adding a bounded rolling-window duplicate detector with timestamps.
