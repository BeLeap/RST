# Build DMG workflow artifact action follow-up for Node 24 deprecation warning

## Summary
- Updated `.github/workflows/build-dmg.yml` again, moving artifact uploads from `actions/upload-artifact@v5` to `actions/upload-artifact@v6`.
- Kept artifact names (`RST-app`, `RST-dmg`) and paths unchanged.

## Why
- CI still reported Node.js 20 deprecation warnings after the v5 upgrade.
- The warning explicitly identified `actions/upload-artifact@v5`, so the workflow now targets the next major (`v6`) to pick up Node 24-compatible runtime support.

## Validation
- Confirmed the workflow now references `actions/upload-artifact@v6` in both upload steps.
- Confirmed no remaining `upload-artifact@v5` references exist in `.github/workflows`.
