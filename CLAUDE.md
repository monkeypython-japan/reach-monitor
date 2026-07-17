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
  it would misfire on every manual recheck. This confirmed-status edge drives both
  `NotificationManager.handle(...)` (fires only on reachable⇄unreachable transitions) and the
  popover's reachability-based elapsed timer (see Elapsed-time semantics below). Separately,
  `AppState` compares each `LinkMonitor` update's `interfaceType` against the current
  `link.interfaceType` to detect link-type edges, which drive both the menu bar's link-based
  elapsed timer and `LinkHistoryLogger`.
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
  (`linkElapsedSeconds(at:)`, `menuBarElapsedText(at:)`) take `now` as a parameter instead of
  reading a stored clock, so they stay pure and callers supply whichever clock is appropriate.
- **`LinkHistoryLogger`** — appends one line per `LinkMonitor` interface-type transition to
  `~/Library/Logs/reachmonitor_history.log` (timestamp, previous→current type, concurrent
  `WiFiInfo`, and what happened to the elapsed timer), rotating to `.log.1` past 5MB. Pure side
  effect for offline troubleshooting (e.g. correlating Wi-Fi⇄Ethernet flaps with SMB reconnects on
  another machine); never affects UI or app behavior on write failure (see ADR-0011).

### Elapsed-time semantics (non-obvious, easy to regress)

**There are two independent elapsed timers that deliberately show different things** — don't
conflate them or make one drive the other; the whole point is that they can diverge (e.g. a
Wi-Fi⇄Ethernet flap resets the menu bar to 0:00 while the popover keeps counting straight through,
because reachability never dropped).

**Menu bar (`h:mm`, `AppState.menuBarElapsedText(at:)` / `menuBarTimerElapsedSeconds(at:)`) —
"fully healthy" (link connected *and* reachable).** Tracks time since the connection was last both
link-connected and TCP-reachable at once, using a single `menuBarTimerStart`/
`menuBarTimerFrozenElapsed` pair driven by *two* independent edge sources:
- `AppState`'s `linkMonitor.onUpdate` compares each update's `interfaceType` against the current
  `link.interfaceType`; only an actual change calls `updateLinkTimer(newType:)`, which resets on a
  new link (`interfaceType` from `nil` to some type, *or* switching directly from one type to
  another, e.g. Wi-Fi→Ethernet — treated as "old link gone, new link up") and freezes when the link
  drops (`interfaceType` becomes `nil`).
- `apply(results:status:)`'s confirmed-status edges (the same ones driving the popover's timer,
  see below) *also* reset the menu bar timer on reachability recovery and freeze it on reachability
  loss, via the shared `resetMenuBarTimer()`/`freezeMenuBarTimer()` helpers.
- Both `resetMenuBarTimer()`/`freezeMenuBarTimer()` are no-ops-safe to call redundantly: freezing an
  already-frozen timer keeps the existing frozen value, and whichever of the two edge sources resets
  *last* naturally becomes the new start time — no explicit coordination between them is needed.
- Only the link-edge path is recorded by `LinkHistoryLogger` (`timer=reset` /
  `timer=freeze(upSeconds=N)` on the same log line as the transition, see ADR-0011); reachability-
  driven resets/freezes are not logged there, since that log is scoped to link/interface changes for
  SMB-flap correlation, not TCP-reachability failures (which are already visible via the dot color
  and notifications).

**Popover (`hh:mm:ss`, `MenuContent`'s `ElapsedTimeRow` / `AppState.reachElapsedSeconds(at:)`) —
reachability-only**, unchanged since [[0005-経過時間は到達確認基準とする|ADR-0005]]: tracks time
since reachability was last confirmed, via `lastConfirmedStatus` edges in `apply(results:status:)`.
First `.reachable` confirmation (or recovery from `.unreachable`) restarts from 0:00; transition
into `.unreachable` freezes it. Deliberately does *not* react to link-type changes, so it keeps
counting straight through a link flap that doesn't affect reachability — showing the popover and
menu bar side by side lets you tell "link flapped but reachability held" from "reachability itself
was lost" at a glance.

Both `menuBarTimerElapsedSeconds(at:)` and `reachElapsedSeconds(at:)` take `now` as a parameter
(rather than reading a `@Published` clock property on `AppState`) so that only the small views
which actually display elapsed time re-render every second, instead of every view that observes
`AppState` — see `ClockTick`. Callers supply the current time from `ClockTick`.

This split ([[0012-メニューバーの経過時間表示をリンク接続かつ到達確認基準にする|ADR-0012]]) exists to correlate
menu-bar-visible connectivity disruptions (of *either* kind — link flap or reachability loss) with
SMB reconnect issues on another machine, while keeping the popover as a pure reachability indicator
matching the app's original purpose. Don't collapse the two timers into one, and don't make the menu
bar timer link-only or reachability-only again, without checking whether that distinction is still
needed.

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
