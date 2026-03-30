# DMG Applications link

- Updated `scripts/create-dmg.sh` to add a symlink to `/Applications` in the staging directory before creating the DMG.
- This enables drag-and-drop installation from the mounted DMG (`AppName.app` -> `Applications`).
- Kept existing explicit error behavior and script flags (`set -euo pipefail`) unchanged.
