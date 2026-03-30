# Switch model download to streaming bytes API

- Replaced `downloadTask` progress observation with `URLSession.bytes(from:)` streaming to avoid stricter Release concurrency issues.
- Implemented explicit byte streaming into a temporary file and computed progress from `expectedContentLength` for determinate updates.
- Added an explicit error for temporary-file creation failures to keep download setup failures visible.
