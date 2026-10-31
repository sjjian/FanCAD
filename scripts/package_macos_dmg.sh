#!/usr/bin/env bash
# Build an unsigned, non-notarized DMG from the Flutter macOS release app.
#
# ARCH defaults to arm64. Set ARCH=x64 or ARCH=universal when packaging another
# slice; the executable is checked with lipo before the DMG is named.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/macos/Build/Products/Release/fancad.app}"
VERSION="${1:-}"
ARCH="${ARCH:-arm64}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"

case "$ARCH" in
  universal) expected_archs=("arm64" "x86_64") ;;
  arm64) expected_archs=("arm64") ;;
  x64) expected_archs=("x86_64") ;;
  *)
    echo "error: ARCH must be universal, arm64 or x64 (got $ARCH)" >&2
    exit 2
    ;;
esac

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
for wanted in "${expected_archs[@]}"; do
  if [[ " $actual_archs " != *" $wanted "* ]]; then
    echo "error: $executable is '$actual_archs', expected $ARCH ($wanted)" >&2
    echo "build a universal app or set ARCH to the architecture you built" >&2
    exit 1
  fi
done

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
