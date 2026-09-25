#!/usr/bin/env bash
# Build an unsigned, non-notarized DMG from the Flutter macOS release app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/macos/Build/Products/Release/fancad.app}"
VERSION="${1:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"

if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' "$ROOT_DIR/pubspec.yaml" | head -n1)"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  echo "run: flutter build macos --release" >&2
  exit 1
fi

DMG_NAME="fancad-macos-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/fancad-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$STAGE"
cp -R "$APP_PATH" "$STAGE/fancad.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "FanCAD" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
