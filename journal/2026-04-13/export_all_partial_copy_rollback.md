# Export All partial-copy rollback

## Feedback addressed
- User clarified this is likely not an overwrite/same-folder issue.
- Symptom remains: only `.m4a` appears after Export All.

## Changes
- Removed same-folder export blocking logic from `ExportError` and copy path checks.
- Kept strict source existence preflight for transcript/summary/audio.
- Added transactional behavior to `exportItems(_:to:)`:
  - track successfully copied files
  - if any later copy fails, rollback previously copied outputs
  - surface explicit error messages with the file that failed and reason
- Added explicit rollback failure error path so cleanup problems are visible.

## Rationale
- This directly targets the observed partial export symptom (audio only).
- Even if a later artifact copy fails for any reason, users do not end up with misleading partial results.
- Errors are now explicit and actionable in status messages.
