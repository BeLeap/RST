# Files list batch queue status labels

## Summary
- Added per-recording batch queue labels in Files list:
  - "Batch processing in progress" for the currently running job
  - "Queued for batch transcription (N)" for waiting jobs
- Added queue UI state syncing in `RecorderViewModel` so labels stay accurate after enqueue/process transitions.
- Reloaded persisted queue from store after delete/rename so in-memory queue state stays consistent with disk updates.

## Follow-up ideas
- If needed, localize label text and include estimated wait time.
