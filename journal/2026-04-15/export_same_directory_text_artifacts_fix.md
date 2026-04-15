# Fix export to same directory deleting transcript/summary files

## Request
- User reported that export produced only audio and transcript/summary `.txt` artifacts did not appear.

## Root cause
- `copyItemReplacingDestination(at:to:)` always removed an existing destination before copy.
- When exporting transcript/summary to the same folder with the same filename as the source, destination equaled source.
- The code removed the source file and then attempted to copy from a now-missing file.

## What changed
- Updated `copyItemReplacingDestination(at:to:)` to compare standardized source/destination URLs.
- If source and destination are the same file path, return early without deleting/copying.
- Existing replacement behavior remains unchanged for truly different destination paths.

## Notes
- This keeps failure handling explicit while preventing destructive self-copy behavior.
