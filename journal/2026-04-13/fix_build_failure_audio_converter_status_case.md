# Fix build failure: invalid AVAudioConverter output status case

## Issue
- Release build failed due to `AudioFileTranscoder` using `.noDataNow` in a switch over `AVAudioConverterOutputStatus`.
- `.noDataNow` is an `AVAudioConverterInputStatus` case, not an output status case.

## Fix
- Updated output-status handling to valid cases only:
  - `.haveData`
  - `.inputRanDry`
  - `.endOfStream`
  - `.error` (explicit failure with clear message)
- Kept unknown-default explicit failure for forward compatibility.

## Result
- Removes the compile-time enum-case mismatch and keeps error signaling explicit.
