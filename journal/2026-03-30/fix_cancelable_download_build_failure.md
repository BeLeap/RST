# Fix cancelable download build failure

## What changed
- Fixed `WhisperModelStore.download(...)` task creation so the task type is `Task<Void, Never>`.
- Removed optional-returning weak-self task body that caused a type mismatch during compilation.

## Why
- `Task { [weak self] in await self?.performDownload(...) }` returns `Void?`, which does not match `activeDownloadTask: Task<Void, Never>`.
- The corrected task body calls `performDownload(...)` directly and returns `Void`.
