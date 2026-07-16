# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS menu bar app (SwiftUI `MenuBarExtra`, no Dock icon) that periodically TCP-probes a fixed
set of hosts to detect whether the network can actually reach the outside world — useful on
captive-portal Wi-Fi (cafes, etc.) where AP association can succeed while real reachability fails.
It shows a colored status dot + elapsed time in the menu bar and fires a notification on
reachable ⇄ unreachable transitions.

## Commands

```sh
swift build                   # debug build, compile-check only
./bundle/make-app.sh          # release build → assemble .app → ad-hoc sign → install to
                               # ~/Applications → register LaunchAgent → (re)start
./bundle/make-app.sh start    # restart the installed app via launchctl (no rebuild)
./bundle/make-app.sh stop     # stop it (launchctl bootout + pkill)
tail -f /tmp/reachmonitor.log # stdout/stderr of the running app
```

There is no test suite. `swift build` is the correctness gate for compile errors; behavior changes
must be verified by running the actual app (see "Runtime/deployment quirks" below — a plain
`swift build` binary won't get real permissions).

## Architecture

Single SwiftPM executable target (`Sources/ReachMonitor/`), no external dependencies — only
system frameworks (`Network`, `CoreWLAN`, `CoreLocation`, `UserNotifications`, `SwiftUI`, `AppKit`).
`Package.swift` pins `swiftLanguageModes: [.v5]` deliberately, to avoid strict-concurrency friction
with the callback-based Network/CoreWLAN APIs — UI state is instead funneled onto `@MainActor`
manually.

Data flow: three independent monitors push updates into a single `@MainActor` `AppState`
(`ObservableObject`), which derives everything the UI renders. Nothing else talks to the monitors
directly.

- **`ReachabilityMonitor`** — owns a background `DispatchSourceTimer` (interval in
  `MonitorConfig.checkInterval`) that TCP-connects (`NWConnection`) to every `Target` in
  `Targets.swift`, each with its own timeout. Reports `[TargetResult]` + aggregate `ReachStatus`
  (`.reachable` if *any* target succeeds, else `.unreachable`) back via `onUpdate` on the main
  queue. Also exposes `checkNow()` for the manual "recheck" button.
- **`WiFiMonitor`** — reads current SSID/BSSID via `CWWiFiClient`. On macOS 14+ these are `nil`
  without Location authorization, so it drives a `CLLocationManager` permission request and only
  reports real values once granted. Combines CoreWLAN change-event delegates with a polling
  fallback (`MonitorConfig.wifiPollInterval`) for reliability.
- **`LinkMonitor`** — wraps `NWPathMonitor` to report which interface type (Wi-Fi/Ethernet/etc.)
  is actually carrying the system's default route, independent of `WiFiMonitor`'s Wi-Fi-only
  association info. `AppState.isLinkWiFi` derives from this and gates both the popover's SSID row
  and the menu bar dot's reachable-state color (see ADR-0008/0009).
- **`AppState`** — the only piece that decides *edges*, not just current values. It tracks
  `lastConfirmedStatus` separately from the published `status` because `checkNow()` optimistically
  sets `status = .checking` before the async result lands; if edge-detection used `status` directly
  it would misfire on every manual recheck. Elapsed-time semantics (see below) and
  `NotificationManager.handle(...)` (which fires only on reachable⇄unreachable transitions) both
  key off this same confirmed-status edge.
- **`ReachMonitorApp` / `MenuContent`** — SwiftUI shell. The menu bar label is intentionally *not*
  a plain SwiftUI `Circle()`: `MenuBarExtra` renders SwiftUI label content as a template image
  (monochrome), which strips the reachable/unreachable color. `AppState.menuBarIcon` instead
  renders a `NSImage` with `isTemplate = false` to keep the dot in color (blue/red/black/gray
  depending on reachability + link type, see ADR-0009).
- **`ClockTick`** — a tiny separate `ObservableObject` that ticks `now` every second, deliberately
  kept *outside* `AppState`. Only the specific views that render elapsed time (the menu bar label,
  `MenuContent`'s `ElapsedTimeRow`) observe it. Do not move per-second ticking back into `AppState`
  as a `@Published` property — `AppState` is observed by all of `MenuContent` (target list, buttons,
  etc.), so a 1 Hz publish there forces the *entire* popover view tree to re-evaluate every second
  even while the popover is closed (`MenuBarExtra(style: .window)` keeps its content mounted whether
  visible or not), which was a real, measurable CPU cost. Elapsed-time accessors on `AppState`
  (`reachElapsedSeconds(at:)`, `menuBarElapsedText(at:)`) take `now` as a parameter instead of
  reading a stored clock, so they stay pure and callers supply whichever clock is appropriate.

### Elapsed-time semantics (non-obvious, easy to regress)

The menu bar's `h:mm` / popover's `hh:mm:ss` timer tracks **time since reachability was last
confirmed**, not AP-connection time:
- First `.reachable` confirmation (or recovery from `.unreachable`) → `reachTimerStart = Date()`,
  restart from 0:00.
- Transition into `.unreachable` → freeze: capture elapsed into `reachTimerFrozenElapsed`, clear
  `reachTimerStart` so the clock stops advancing.
- Staying in the same status → no change; either still ticking from `reachTimerStart` or still
  showing the frozen value.

`AppState.reachElapsedSeconds(at:)` is the single source of truth for this; both the menu bar label
and the popover format the same value differently, each passing in the current time from
`ClockTick`. Don't reintroduce a separate AP-connection-based timer (an earlier version of this app
used `WiFiMonitor`'s BSSID-change time for this and it was deliberately removed in favor of the
reachability-based one).

## Runtime/deployment quirks

- **Must run from the built `.app` bundle, not `swift run`.** Location/notification permissions
  are tied to the bundle identity (`com.mamoru.reachmonitor`, set in `bundle/Info.plist`); a bare
  `swift run` binary has neither a stable bundle id nor a code signature, so both permissions
  silently fail.
- **Launched via a LaunchAgent, not Finder.** On this machine's macOS version, Gatekeeper blocks
  double-clicking an ad-hoc-signed (`codesign --sign -`) app from Finder with no override dialog.
  `make-app.sh` installs `~/Library/LaunchAgents/com.mamoru.reachmonitor.plist` and starts the app
  via `launchctl bootstrap`, which is unaffected by that restriction. If you change the install
  path or bundle id, update the plist template inside `make-app.sh` accordingly.
- Re-signing with a different signing identity can reset the Location-permission grant (ad-hoc
  identity is derived from the binary's hash), so a Location prompt reappearing after a rebuild is
  expected, not a bug.

## Adding/changing monitored targets

Edit `DefaultTargets.all` and `MonitorConfig` in `Sources/ReachMonitor/Targets.swift` — there is no
settings UI by design. Rebuild with `./bundle/make-app.sh` to pick up changes.
