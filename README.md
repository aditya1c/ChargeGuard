# ChargeGuard

A minimal macOS menu-bar app that holds MacBook battery charge within a custom
lower/upper range (e.g. 40–80%), so it can stay plugged in permanently without
sitting at 100% — useful for running it as an always-on machine.

ChargeGuard is a thin UI layer; all privileged charging control is handled by
[batt](https://github.com/charlie0129/batt), an open-source daemon that writes
the relevant SMC keys via its own root `launchd` service. ChargeGuard just
shells out to the `batt` CLI.

## Requirements

- Apple Silicon Mac, macOS 14+.
- Xcode, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- [batt](https://github.com/charlie0129/batt), installed once:
  ```bash
  brew install batt
  sudo brew services start batt   # one-time admin password prompt
  ```

**Known issue (as of macOS 27 beta):** `batt` doesn't yet support this macOS
version's charging-control APIs — `batt status` will show
`"chargingControl": false` and setting a range won't actually be enforced
until `batt` ships a fix ([tracking issue #148](https://github.com/charlie0129/batt/issues/148)).
ChargeGuard detects this and shows a warning in the popover instead of
failing silently; everything else (UI, settings, launch-at-login) works
regardless.

## Build & run

```bash
./run.sh      # regenerate project → build → sign → launch (dev loop)
./install.sh  # build → copy to /Applications → launch
```

## Signing (self-signed, no Apple Developer account)

`run.sh`/`install.sh` build ad-hoc signed by default (`CODE_SIGN_IDENTITY: "-"`),
which is enough for local builds — unlike WhisperType, ChargeGuard requests no
TCC-gated permission (Accessibility, Microphone, etc.), so there's no grant
that a changing signature could invalidate, and a stable cert isn't required.

If you ever zip and share the built app rather than running it locally, the
scripts will also auto-detect a self-signed identity named **"ChargeGuard Dev"**
if one exists (Keychain Access → Certificate Assistant → Create a Certificate →
Name `ChargeGuard Dev`, Identity Type **Self-Signed Root**, Certificate Type
**Code Signing**) and use it instead — useful mainly so re-signed rebuilds share
one identity. A downloaded/AirDropped copy would also need one Gatekeeper
**Open Anyway** click in System Settings → Privacy & Security (local Xcode
builds aren't quarantined, so this doesn't apply to `run.sh`/`install.sh`).

## Features

- Custom lower/upper charge range (`batt limit` + `batt lower-limit-delta`).
- Sail mode — holds tight near the upper limit (~2% band) instead of ranging
  across the full lower–upper band, for fewer/smaller top-up cycles.
- Top up to 100% — temporarily lifts the limit; ChargeGuard polls status and
  restores your saved range automatically once charge is near full (`batt`
  also restores it on its own after 6h as a safety net if ChargeGuard quits).
- Calibration — runs `batt`'s multi-phase auto-calibration
  (discharge → charge → hold → post-hold discharge → restore).
- Launch at login (`SMAppService`).

Deferred to a later pass: battery health/cycle count, power adapter wattage,
top energy-consuming apps, and battery temperature — all readable without
root via `ioreg -rn AppleSmartBattery` / `system_profiler SPPowerDataType`,
to be added once the core range-limiting is validated.
