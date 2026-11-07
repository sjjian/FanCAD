#!/usr/bin/env bash
# Build an unsigned, non-notarized DMG from the Flutter macOS release app.
#
# FanCAD ships Apple Silicon only. The executable is checked with lipo so a
# stale x64 build cannot be published under an arm64 name.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/macos/Build/Products/Release/fancad.app}"
VERSION="${1:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
ARCH="arm64"

if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' "$ROOT_DIR/pubspec.yaml" | head -n1)"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  echo "run: flutter build macos --release" >&2
  exit 1
fi

executable="$APP_PATH/Contents/MacOS/$(basename "${APP_PATH%.app}")"
actual_archs="$(lipo -archs "$executable" 2>/dev/null || true)"
if [[ " $actual_archs " != *" arm64 "* ]]; then
  echo "error: $executable is '$actual_archs', expected arm64 (Apple Silicon)" >&2
  exit 1
fi

DMG_NAME="fancad-macos-${ARCH}-${VERSION}.dmg"
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
