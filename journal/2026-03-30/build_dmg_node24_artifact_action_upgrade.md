# Build DMG workflow Node 24 compatibility update

## Summary
- Updated the `build-dmg` GitHub Actions workflow to use `actions/upload-artifact@v5` for both artifact upload steps.
- This removes reliance on a Node.js 20-backed action runtime and aligns with the upcoming Node.js 24 default on GitHub-hosted runners.

## Why
- CI emitted a deprecation notice indicating Node.js 20 JavaScript actions are being phased out.
- `actions/upload-artifact@v4` was flagged; upgrading to the latest major version is the direct fix.

## Validation
- Searched workflow files for `upload-artifact@` references and confirmed only `build-dmg.yml` needed updates.
- No behavior changes to artifact names or paths.
