#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <app-bundle-path> <output-dmg-path>" >&2
  exit 1
fi

APP_BUNDLE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUTPUT_DMG="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
VOLUME_NAME="$(basename "$APP_BUNDLE" .app)"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

rm -f "$OUTPUT_DMG"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

echo "Created $OUTPUT_DMG"
