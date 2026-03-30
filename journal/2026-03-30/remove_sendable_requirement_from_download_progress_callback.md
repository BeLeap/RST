# Remove Sendable requirement from download progress callback

- Removed the `@Sendable` requirement from the download progress callback in `WhisperModelStore`.
- The callback is only used for local UI updates, so forcing `@Sendable` introduced unnecessary strict-concurrency constraints in Release builds.
- This keeps progress reporting behavior intact while reducing Swift concurrency compatibility risk.
