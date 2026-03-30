# Model download resume support

## Summary
- Updated `WhisperModelStore` model downloads to resume from a partial `*.download` file instead of deleting it before each retry.
- Added HTTP `Range` request support and append-mode file writing for resumed downloads.
- Kept partial downloads on cancellation so users can continue later.
- Added explicit error when the remote host does not honor range requests for resumed downloads.

## Notes
- `force` redownload now clears both the final model file and partial download file.
- Progress calculation now accounts for bytes already present in resumed downloads.
