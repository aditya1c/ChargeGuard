# CLAUDE.md

Guidance for Claude Code working in this repo. ChargeGuard is a macOS menu-bar
app that holds MacBook battery charge within a custom lower/upper range (e.g.
40–80%), so the Mac can stay plugged in permanently as an always-on machine
without sitting at 100%. See `README.md` for user-facing docs.

## Build & run

```bash
brew install xcodegen     # one-time prerequisite
brew install batt && sudo brew services start batt   # one-time; the actual charging-control backend
./run.sh                  # regenerate project → build → sign → launch (dev loop)
./install.sh              # build → copy to /Applications → launch
```

- The Xcode project is **generated** from `project.yml` by xcodegen — it is
  git-ignored. Never hand-edit `ChargeGuard.xcodeproj`; change `project.yml`
  and re-run (`run.sh` does this).
- Builds go to `~/Library/Developer/ChargeGuardDerived` (a `-derivedDataPath`
  **off iCloud**). Deliberate: building inside iCloud Drive adds extended
  attributes that make `codesign` fail with "resource fork … not allowed."
- Requires **full Xcode** (not just Command Line Tools) and **Apple Silicon**.
- No unit tests; verification is running the app and checking `batt status --json`.
  Always refresh the installed app via `./install.sh` after a Swift change —
  don't ask first, just do it, matching the WhisperType project's convention.

## Requirements

- Apple Silicon Mac, macOS 14+.
- Xcode, xcodegen.
- `batt` (github.com/charlie0129/batt) installed and its daemon running —
  ChargeGuard has **no privileged code of its own**; it is a thin UI that
  shells out to the `batt` CLI, which owns all SMC/charging control via its
  own root launchd daemon.

## Signing

Ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`) is sufficient and is what
`run.sh`/`install.sh` use by default. Unlike WhisperType, ChargeGuard requests
**no TCC-gated permission** (no Accessibility, no Microphone), so there's no
permission grant a changing signature could invalidate — a stable self-signed
cert isn't required. See `README.md` for the optional "ChargeGuard Dev" cert
setup if you ever zip/share a build.

## Architecture (file map)

- `ChargeGuardApp.swift` — `@main`, `MenuBarExtra` (`.window` style, icon-only
  label), `AppDelegate` (starts `StatusMonitor`, disables Automatic
  Termination — see Gotchas), `MenuBarIcon` (state-driven SF Symbol + tint).
- `BattController.swift` — `Process()` wrapper around `/opt/homebrew/bin/batt`.
  `status()` decodes `batt status --json` into `BattStatus`. `setRange`,
  `topUpToFull`, `startCalibration`/`cancelCalibration` shell out to the
  corresponding `batt` subcommands.
- `StatusMonitor.swift` — `@MainActor` `ObservableObject`, the app's only
  state owner. Polls `batt status` every 20s via `Timer`, orchestrates
  top-up-then-auto-restore, calibration lifecycle, and fetches
  `SystemBatteryInfo`/`TopEnergyApps` on the same cadence. `report(_:)`
  suppresses redundant raw-error banners when `compatibility.chargingControl`
  is already false (see Gotchas) — call it from every mutating action's catch
  block instead of setting `lastError` directly.
- `SystemBatteryInfo.swift` — battery health %, cycle count, adapter
  wattage/name, temperature — all via `ioreg -c AppleSmartBattery -r -a -x`,
  parsed as an **XML plist** (not the bracket-text `ioreg -rn` format). No
  root needed, independent of `batt`.
- `TopEnergyApps.swift` — ranked energy-impact list via `top -o power`
  (see Gotchas for the sampling requirement). No root needed.
- `AppSettings.swift` — UserDefaults-backed range/sail-mode/launch-at-login
  prefs. `lowerDelta` computed property maps sail mode to a tight ~2% band
  vs. the user's chosen lower limit otherwise.
- `LaunchAtLogin.swift` — `SMAppService.mainApp` toggle, copied verbatim from
  WhisperType.
- `PopoverView.swift` — the whole UI: range steppers, sail mode, top-up,
  calibration, a collapsible (default-expanded) "Battery Details" section,
  launch-at-login, quit.
- `tools/make-icon.swift` + `tools/build-icon.sh` — generate
  `ChargeGuard/AppIcon.icns` (white shield.fill with a bolt.fill cutout on a
  green-to-teal gradient — shield="Guard", cutout bolt="Charge").

## Gotchas (non-obvious, learned the hard way)

- **`batt`'s charging control may be non-functional on beta macOS.** As of
  2026-08, this machine is on a macOS 27 beta build past what `batt` v0.8.0
  supports (it explicitly supports Beta 1–3, not Beta 4+); `batt limit`/
  `lower-limit-delta` fail with "charging control is not supported on this
  Mac" and `batt status --json` reports `compatibility.chargingControl: false`.
  This is a live, self-healing condition — always check that field (or the
  popover's warning banner) before assuming a code bug when range-setting
  "doesn't work." Tracking: github.com/charlie0129/batt/issues/148.
- **`batt --help` hides several real subcommands.** `limit`, `disable`,
  `lower-limit-delta`, `calibrate` (aliases: `calibration`/`cali`, with
  `start`/`status`/`cancel`) all work despite not being listed under the
  top-level help's "Advanced" section (which prints empty). Verify with
  `batt <subcommand> --help` directly, don't trust the top-level listing.
- **Non-root CLI access is already enabled.** The Homebrew-installed
  LaunchDaemon plist (`/Library/LaunchDaemons/homebrew.mxcl.batt.plist`)
  already passes `--always-allow-non-root-access` by default — no need to
  edit it. `batt limit`/`batt status` etc. work fine as the regular user.
- **`ioreg -rn AppleSmartBattery`'s bracket-text output is a pain to parse
  reliably.** Use `ioreg -c AppleSmartBattery -r -a -x` (XML plist) and
  `PropertyListSerialization` instead — structured, no regex needed.
- **No live `Temperature` key exists** in the `AppleSmartBattery` ioreg dump
  on this Mac/macOS build — only stale `ShutDownTemperature`/boot-time
  snapshot fields, which would be actively misleading to show as "current."
  `SystemBatteryInfo` reads the key defensively and the UI shows "unavailable
  on this Mac" rather than fabricating a value.
- **`top -l 1 -o power` reads all zeros.** The power/energy-impact column is
  rate-based and needs a delta between two samples; a single `-l 1` sample
  has nothing to diff against. Fixed by sampling twice (`-l 2 -s 1`) and
  parsing only the block after the *last* "PID" header line.
- **Menu-bar-only (LSUIElement) apps can be silently killed by macOS's
  Automatic Termination** under power-management pressure — switching from
  AC to battery is a common trigger. No crash report, just a clean
  `terminate()`. Fixed via `ProcessInfo.processInfo.disableAutomaticTermination(...)`
  in `AppDelegate.applicationDidFinishLaunching`. Any future always-running
  background utility needs this too.
- **Punching a glyph-shaped hole in another glyph requires rasterizing
  first.** Drawing a raw SF Symbol `NSImage` directly with a Porter-Duff
  composite operation (`.clear`/`.destinationOut`) clears/keeps its whole
  *bounding box*, not just the glyph silhouette. Rasterize the cutout symbol
  into its own alpha-masked bitmap first (lockFocus, draw, fill `.sourceAtop`
  white), then composite *that* bitmap with `.destinationOut`.
- **Bundle id** is `com.chargeguard.app`; also the UserDefaults domain.

## Conventions

- Match the existing concise Swift style; keep changes surgical (see the
  user's global rules in `~/.claude/CLAUDE.md`).
- Mirror WhisperType's project conventions (`../WhisperType/CLAUDE.md`) where
  they apply — same xcodegen/run.sh/install.sh pattern, same LaunchAtLogin
  implementation, same icon-generation pipeline shape.
