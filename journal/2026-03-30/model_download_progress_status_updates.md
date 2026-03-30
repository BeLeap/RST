# Model download progress status updates

- Updated model download progress handling to also publish a percentage in `statusMessage` while a download is active.
- Kept the message deterministic by clamping progress into `0...1` before formatting percent output.
- This makes in-progress state more visible in text-based status UI in addition to the progress bar.
