# Add model download progress bar

- Added tracked model download progress to `WhisperModelStore` using a dedicated `URLSessionDownloadDelegate`.
- Exposed `activeDownloadProgress` so the UI can render determinate progress while a model is downloading.
- Replaced the prior indeterminate download spinner in `RecorderView` with a determinate progress bar when the server reports content length.
- Added explicit download error cases for invalid response/status/missing file to keep failures visible.
