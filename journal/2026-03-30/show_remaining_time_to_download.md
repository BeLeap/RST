# Show remaining time to download

## Summary
- Added download ETA estimation in `WhisperModelStore` based on streamed bytes and elapsed time.
- Exposed a new published `activeDownloadRemainingTime` string for UI consumption.
- Updated status text to include percent and remaining time when available.
- Updated both live and batch model download rows in `RecorderView` to show a small remaining-time label under the progress bar.

## Notes
- ETA is only shown when total content length is known and throughput can be estimated.
- On completion/cancel/reset, the remaining-time value is cleared.
