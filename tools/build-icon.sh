#!/bin/bash
# Render the app icon and assemble AppIcon.icns into the app source folder.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="$(mktemp -d)/icon-1024.png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="ChargeGuard/AppIcon.icns"

echo "==> Rendering 1024px base"
swift tools/make-icon.swift "$BASE"

echo "==> Generating iconset sizes"
mkdir -p "$ICONSET"
sips -z 16 16     "$BASE" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$BASE" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$BASE" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$BASE" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$BASE" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$BASE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$BASE" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$BASE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$BASE" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$BASE"        "$ICONSET/icon_512x512@2x.png"

echo "==> Building $OUT"
iconutil -c icns "$ICONSET" -o "$OUT"
echo "==> Done: $OUT"
