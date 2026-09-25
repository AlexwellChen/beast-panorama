#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$(uname -m)" != arm64 ]; then echo 'Apple Silicon is required for this release target.' >&2; exit 1; fi
VERSION=$(tr -d '\n' < VERSION)
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/beast-app.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Beast Panorama.app"
OUTPUT_ROOT="${BEAST_BUILD_ROOT:-$PWD/dist/public}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUTPUT_ROOT"
cp "$BIN_DIR/BeastPanorama" "$APP/Contents/MacOS/BeastPanorama"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/使用说明.txt LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
# Explicit opt-in only; never discover or bundle a developer's SDK automatically.
if [ -n "${VITURE_SDK_DIR:-}" ]; then
  test -f "$VITURE_SDK_DIR/libglasses.dylib" || { echo 'VITURE_SDK_DIR must contain libglasses.dylib' >&2; exit 1; }
  mkdir -p "$APP/Contents/Frameworks/VITURE"
  for lib in "$VITURE_SDK_DIR/"*.dylib; do
    cp "$lib" "$APP/Contents/Frameworks/VITURE/"
  done
fi
xattr -cr "$APP"
if [ -d "$APP/Contents/Frameworks/VITURE" ]; then
  for lib in "$APP/Contents/Frameworks/VITURE/"*.dylib; do codesign --force --sign - "$lib"; done
fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
# Replace only the generated app, ensuring no old bundled SDK survives a public build.
rm -rf "$OUTPUT_ROOT/Beast Panorama.app"
ditto --noextattr "$APP" "$OUTPUT_ROOT/Beast Panorama.app"
echo "$OUTPUT_ROOT/Beast Panorama.app"
