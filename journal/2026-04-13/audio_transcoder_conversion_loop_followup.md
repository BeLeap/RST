# Audio transcoder conversion loop follow-up

## Context
Followed up on compressed export/import conversion reliability after review feedback.

## Changes
- Tightened `AudioFileTranscoder.convertToWAV` input validation to fail early with a clear unsupported-format error.
- Reworked conversion loop in `transcodeAudio` to drain `AVAudioConverter` output correctly per input chunk by looping on `.haveData` until `.inputRanDry`/`.noDataNow`.
- Kept explicit error propagation for converter/buffer failures (no silent fallback).

## Why
- Prevent partial-frame loss risk when a converter emits multiple output buffers for one input buffer.
- Improve diagnosability for invalid import types.
