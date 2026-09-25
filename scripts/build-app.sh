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
cp Resources/AppIcon.icns Resources/使用说明.txt Resources/Privacy.txt LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
# Explicit opt-in only; never discover or bundle a developer's SDK automatically.
if [ -n "${VITURE_SDK_DIR:-}" ]; then
  test -f "$VITURE_SDK_DIR/libglasses.dylib" || { echo 'VITURE_SDK_DIR must contain libglasses.dylib' >&2; exit 1; }
  mkdir -p "$APP/Contents/Frameworks/VITURE"
  python3 - "$APP/Contents/Resources/使用说明.txt" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
start = s.index("此公开构建")
end = s.index("打开或拖入")
s = s[:start] + "此为本机私人使用的 SDK 内置构建，连接眼镜即可开启头追。\n不作为公开发布附件；SDK 仍受 VITURE 专有协议约束。\nhttps://www.viture.com/viture-sdk-license-agreement\n\n" + s[end:]
p.write_text(s)
PY
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
