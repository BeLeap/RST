# Export All preflight validation for missing text artifacts

## Request
- User reported that even exporting to an empty folder still produced only audio, without transcript/summary text artifacts.

## Analysis
- Filename collision was only one possible failure mode.
- `exportAll()` exported compressed audio first, then copied transcript/summary.
- If transcript/summary source files were missing on disk (while stale URLs still existed in memory), export failed after audio had already been written, which looked like "audio only export".

## What changed
- Added explicit preflight validation in `exportAll()` via `ensureExportSourcesExist(_:)`.
- Preflight now fails fast with a clear error message listing missing source files before writing any export artifacts.
- This prevents partial export outputs caused by missing transcript/summary source files.

## Notes
- Existing same-file copy guard remains in place for the separate self-copy deletion issue.
