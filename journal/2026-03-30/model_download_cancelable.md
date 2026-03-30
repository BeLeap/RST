# Model download cancelable

## What changed
- Added explicit cancellation support to `WhisperModelStore` with `cancelActiveDownload()` and tracked `activeDownloadTask`.
- Refactored model download flow to run in a tracked task and handle `CancellationError` explicitly.
- Added cooperative cancellation checks while streaming bytes and before moving files.
- Added temporary file cleanup helper for canceled/failed downloads.
- Added a `Cancel` button in the model controls while a preset download is active.

## Notes for next task
- Cancellation now updates status with "Canceling..." then "Canceled download for <model>.".
- Download cancellation currently cleans destination `.download` temp files and stream temp files.
