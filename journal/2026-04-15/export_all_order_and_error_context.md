# Export All ordering and per-file error context

## Request
- User reported transcript file can be revealed, so missing source might not explain why export-all yielded audio-only results.

## Analysis
- Even with source preflight checks, partial export behavior can still confuse users depending on operation order.
- Previous order wrote audio before text copy, so users could still observe audio-only output when text export failed for other reasons.
- Generic copy errors also made diagnosis difficult.

## What changed
- Reordered `exportAll()` so transcript/summary text export happens before compressed audio export.
- Added per-file export error wrapping (`Failed to export <file>: <reason>`) in `exportItems(_:,to:)`.
- Added explicit missing-source error in `copyItemReplacingDestination(at:to:)` (`Source file not found: <file>`).

## Notes
- This keeps failures explicit and visible, and avoids the most confusing partial state (audio-only) when text export fails.
