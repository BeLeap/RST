# persistent transcription queue and file status

## Summary

- Reworked final/manual transcription flow to enqueue jobs instead of running immediately.
- Added persistent queue storage (`transcription-queue.json`) so queued/running work resumes after app restart.
- Added sequential queue worker logic that marks each job as queued/running/completed/failed and persists every transition.
- Updated Files list UI to show per-recording transcription status and current queue size.
- Ensured queue metadata follows rename/delete operations so stale jobs are not left behind.

## Error handling notes

- Queue persistence errors now surface through `statusMessage`.
- Live/final transcription failures are saved back into job state (`failed`) and shown in UI status text.

## Relevant files

- `RST/Features/RecorderViewModel.swift`
- `RST/Features/RecorderView.swift`
- `RST/Core/TranscriptStore.swift`
- `RST/Core/TranscriptionQueue.swift`
- `RST/Core/WhisperTranscriber.swift`
- `RST.xcodeproj/project.pbxproj`
