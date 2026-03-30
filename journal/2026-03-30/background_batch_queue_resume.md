# Background batch transcription queue with restart recovery

## Summary
- Changed stop-recording flow to enqueue final(batch) transcription jobs and return immediately so new recordings appear in Files right away.
- Added persisted queue storage (`batch-transcription-queue.json`) under app support.
- Added startup resume behavior: queued jobs automatically continue after app relaunch.
- Kept explicit error behavior: when queue processing fails, the job remains queued and the status message surfaces the failure clearly.

## Notes for next task
- Current retry policy is conservative: failed jobs pause the queue and retry on next launch.
- Could add a manual "Retry Queue" action and per-item queue status in Files for clearer UX.
