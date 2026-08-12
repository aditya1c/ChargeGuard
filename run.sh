#!/bin/bash
# Build and (re)launch ChargeGuard. Regenerates the Xcode project from
# project.yml, builds with ad-hoc signing, then relaunches the app.
set -euo pipefail
cd "$(dirname "$0")"

# Build OUTSIDE iCloud: iCloud Drive stamps files with extended attributes that
# make codesign fail ("resource fork ... not allowed"). Keep source in iCloud,
# put DerivedData on the local disk.
DERIVED="$HOME/Library/Developer/ChargeGuardDerived"
APP="$DERIVED/Build/Products/Debug/ChargeGuard.app"

echo "==> Regenerating project"
xcodegen generate

# Use a stable self-signed code-signing cert if present so macOS keeps any
# TCC grants across rebuilds; otherwise fall back to ad-hoc.
IDENTITY="-"
if security find-identity -p codesigning 2>/dev/null | grep -q "ChargeGuard Dev"; then
  IDENTITY="ChargeGuard Dev"
fi
echo "==> Signing identity: $IDENTITY"

# Build everything UNSIGNED, then sign the finished bundle ourselves with $IDENTITY.
echo "==> Building (unsigned)"
xcodebuild \
  -project ChargeGuard.xcodeproj \
  -scheme ChargeGuard \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build | tail -20

echo "==> Signing bundle with: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" "$APP"
codesign -dvv "$APP" 2>&1 | grep -iE "Authority|Signature|Identifier=" | head -4

if [ -n "${SKIP_LAUNCH:-}" ]; then
  echo "==> Built (launch skipped): $APP"
  exit 0
fi

echo "==> Relaunching"
pkill -x ChargeGuard 2>/dev/null || true
sleep 1  # let the old instance fully exit so LaunchServices doesn't return -600
open "$APP"
echo "==> Launched: $APP"
