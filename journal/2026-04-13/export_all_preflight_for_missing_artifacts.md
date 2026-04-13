# Export All preflight for missing artifacts

## Request
- User reported that `Export All` only outputs `.m4a`, while transcript and summary `.txt` files do not appear.

## What changed
- Added explicit `ExportError` cases in `RecorderViewModel` to surface real export failure conditions:
  - missing source file
  - destination folder equal to source recording folder (overwrite/self-copy hazard)
- Added preflight validation in `exportItems(_:to:)` so export fails before partial copying when any source artifact is missing.
- Added a same-path guard in `copyItemReplacingDestination(at:to:)` to prevent removing/copying the same file path.

## Why
- Previous behavior could partially copy the first artifact (`.m4a`) and fail later on missing or unsafe paths, producing the user-visible symptom of audio-only export.
- New behavior is explicit and fail-fast with clear error messaging, matching the error-handling requirement.

## Follow-up
- If users often choose the recording folder by mistake, consider showing a confirmation dialog with the source folder path in UI.
