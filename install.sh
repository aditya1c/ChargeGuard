#!/bin/bash
# Build and install ChargeGuard into /Applications (signed with the stable cert).
set -euo pipefail
cd "$(dirname "$0")"

APP_SRC="$HOME/Library/Developer/ChargeGuardDerived/Build/Products/Debug/ChargeGuard.app"
DEST="/Applications/ChargeGuard.app"

echo "==> Building"
SKIP_LAUNCH=1 ./run.sh

echo "==> Installing to $DEST"
pkill -x ChargeGuard 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R "$APP_SRC" "$DEST"

IDENTITY="-"
if security find-identity -p codesigning 2>/dev/null | grep -q "ChargeGuard Dev"; then
  IDENTITY="ChargeGuard Dev"
fi
codesign --force --deep --sign "$IDENTITY" "$DEST"

open "$DEST"
echo "==> Installed and launched: $DEST"
