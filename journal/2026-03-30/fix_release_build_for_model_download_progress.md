# Fix release build for model download progress

- Reworked model download progress tracking to avoid delegate/continuation concurrency issues seen in Release CI builds.
- Switched to observing `URLSessionTask.progress.fractionCompleted` on a normal `downloadTask` and awaiting `task.value`.
- Kept explicit HTTP validation and surfaced failures through existing error messaging.
