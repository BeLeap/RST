# Model download resume timeout follow-up

## Summary
- Fixed resumable download regression where partial `*.download` files were deleted on transfer errors.
- Increased request timeout for model download requests to 300 seconds to reduce false timeout failures on slow networks.
- Added explicit resume status text indicating the saved byte size when a partial file is reused.

## Rationale
- The previous cleanup behavior removed partial files in `downloadFile`'s error path, which forced retries to restart from zero after timeout.
- Keeping partial files makes retries truly resumable and more robust for long model downloads.
