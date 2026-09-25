#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(tr -d '\n' < VERSION)
FLAVOR=''
if [ -n "${VITURE_SDK_DIR:-}" ]; then
  if [ "${BEAST_ALLOW_SDK_BUNDLE:-0}" != 1 ]; then
    echo 'Public DMGs exclude the vendor SDK. For a private licensed build, explicitly set BEAST_ALLOW_SDK_BUNDLE=1.' >&2
    exit 1
  fi
  FLAVOR='-private-sdk'
fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/beast-dmg.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
BEAST_BUILD_ROOT="$WORK/build" ./scripts/build-app.sh
APP="$WORK/build/Beast Panorama.app"
"$APP/Contents/MacOS/BeastPanorama" --self-check
mkdir -p "$WORK/stage" dist/public
ditto --noextattr "$APP" "$WORK/stage/Beast Panorama.app"
ln -s /Applications "$WORK/stage/Applications"
cp Resources/使用说明.txt "$WORK/stage/安装与使用.txt"
DMG="dist/public/Beast-Panorama-$VERSION-arm64$FLAVOR.dmg"
hdiutil create -volname 'Beast Panorama' -srcfolder "$WORK/stage" -format UDZO -fs HFS+ -ov "$DMG"
hdiutil verify "$DMG"
(cd dist/public && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "$PWD/$DMG"
