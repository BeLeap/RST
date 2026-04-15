# Compressed export + drag-and-drop decode to WAV

## Request
- Exporting recording audio should use a compressed format instead of WAV.
- When compressed files are dragged into Files, convert them back to WAV on import.

## What changed
- Added `AudioFileTranscoder` to handle:
  - WAV -> compressed M4A export
  - compressed audio (M4A/AAC/MP3/MP4) -> WAV conversion
- Updated `RecorderViewModel.exportAudio()` to export compressed `.m4a` instead of copying `.wav`.
- Updated `RecorderViewModel.exportAll()` so exported audio artifact is compressed `.m4a` while transcript/summary remain text files.
- Updated import messaging to reflect supported formats and WAV conversion behavior.
- Updated `TranscriptStore.importRecording(from:)` to accept WAV + compressed inputs and convert compressed inputs to WAV before storing.
- Updated sidebar/help/drop-overlay copy to explain compressed export and supported drag/drop formats.
- Added new source file to Xcode project so it builds.

## Notes
- Error handling intentionally surfaces conversion failures directly so users can see which file failed and why.
