import Foundation
import Network
import SwiftUI

/// Central observable state. Owns the monitors, funnels their callbacks onto the
/// main actor, and exposes published values for the SwiftUI menu.
@MainActor
final class AppState: ObservableObject {
    @Published var status: ReachStatus = .checking
    @Published var results: [TargetResult] = []
    @Published var wifi: WiFiInfo = WiFiInfo(
        ssid: nil, bssid: nil, locationAuthorized: false, hasWiFiInterface: false
    )
    @Published var link: LinkInfo = LinkInfo(interfaceType: nil)

    /// Start of the current "fully healthy" streak (link connected *and*
    /// reachable); ticking while non-nil. Drives the menu bar label's
    /// elapsed time (see Elapsed-time semantics in CLAUDE.md). Reset by
    /// either a new link connecting or reachability recovering; frozen by
    /// either the link dropping or reachability being lost — whichever
    /// happens first "wins" for a freeze, and whichever happens last "wins"
    /// as the reset anchor.
    private var menuBarTimerStart: Date?
    /// Elapsed time captured at the moment the menu bar timer above was
    /// frozen; the non-ticking display value while frozen.
    private var menuBarTimerFrozenElapsed: TimeInterval?

    /// Start of the current reachable streak; ticking while non-nil. Drives
    /// the popover's elapsed time (reachability-based; deliberately distinct
    /// from the menu bar's link-based timer above, so the two surfaces show
    /// different information instead of duplicating each other).
    private var reachTimerStart: Date?
    /// Elapsed time captured at the moment reachability was lost; frozen
    /// (non-ticking) display value while unreachable.
    private var reachTimerFrozenElapsed: TimeInterval?
    /// Last *confirmed* status from the monitor, used to detect reachable/
    /// unreachable edges for `reachTimerStart`/`reachTimerFrozenElapsed`.
    /// Kept separate from `status` because `checkNow()` optimistically sets
    /// `status = .checking` before the async result lands; if edge-detection
    /// used `status` directly it would misfire on every manual recheck.
    private var lastConfirmedStatus: ReachStatus = .checking

    private let reachability = ReachabilityMonitor(targets: DefaultTargets.all)
    private let wifiMonitor = WiFiMonitor()
    private let linkMonitor = LinkMonitor()
    private let notifications = NotificationManager()
    private let linkHistory = LinkHistoryLogger()

    init() {
        results = DefaultTargets.all.map {
            TargetResult(target: $0, reachable: nil, lastChecked: nil, latency: nil)
        }

        reachability.onUpdate = { [weak self] results, status in
            // Delivered on the main queue by ReachabilityMonitor.
            Task { @MainActor in self?.apply(results: results, status: status) }
        }
        wifiMonitor.onUpdate = { [weak self] info in
            Task { @MainActor in self?.wifi = info }
        }
        linkMonitor.onUpdate = { [weak self] info in
            Task { @MainActor in
                guard let self else { return }
                if info.interfaceType != self.link.interfaceType {
                    let timerEvent = self.updateLinkTimer(newType: info.interfaceType)
                    self.linkHistory.logLinkChange(
                        from: self.link, to: info, wifi: self.wifi, timerEvent: timerEvent
                    )
                }
                self.link = info
            }
        }
    }

    func start() {
        notifications.requestAuthorization()
        reachability.start()
        wifiMonitor.start()
        linkMonitor.start()
    }

    func checkNow() {
        status = .checking
        reachability.checkNow()
    }

    private func apply(results: [TargetResult], status: ReachStatus) {
        self.results = results
        self.status = status

        let previous = lastConfirmedStatus
        lastConfirmedStatus = status

        if status == .reachable && previous != .reachable {
            // First confirmation, or recovery from unreachable: restart from 0:00.
            reachTimerStart = Date()
            reachTimerFrozenElapsed = nil
            resetMenuBarTimer()
        } else if status == .unreachable && previous == .reachable {
            // Just lost reachability: freeze the popover's timer at its current value.
            if let start = reachTimerStart {
                reachTimerFrozenElapsed = Date().timeIntervalSince(start)
            }
            reachTimerStart = nil
            freezeMenuBarTimer()
        }

        let failed = results.filter { $0.reachable != true }.map(\.target)
        notifications.handle(status: status, failedTargets: failed)
    }

    /// Updates the menu bar's elapsed timer for a link-type transition
    /// (called only when `interfaceType` actually changed) and reports what
    /// happened, for `LinkHistoryLogger` to record alongside the transition.
    /// - New link (non-nil `newType`, whether from no-link or from a different
    ///   type): restart from 0:00.
    /// - Link dropped (`newType == nil`): freeze at the current elapsed value.
    private func updateLinkTimer(newType: NWInterface.InterfaceType?) -> LinkHistoryLogger.TimerEvent {
        if newType != nil {
            resetMenuBarTimer()
            return .reset
        } else {
            freezeMenuBarTimer()
            return .freeze(elapsedSeconds: max(0, Int(menuBarTimerFrozenElapsed ?? 0)))
        }
    }

    private func resetMenuBarTimer() {
        menuBarTimerStart = Date()
        menuBarTimerFrozenElapsed = nil
    }

    private func freezeMenuBarTimer() {
        if let start = menuBarTimerStart {
            menuBarTimerFrozenElapsed = Date().timeIntervalSince(start)
        }
        menuBarTimerStart = nil
    }

    // MARK: - Derived presentation values

    /// Color of the circle shown in the menu bar.
    /// - Reachable   → リンク種別で色分け（Wi-Fi=青、Ethernet 等=赤）
    /// - Unreachable → primary (黒/白: adapts to menu bar appearance)
    /// - Checking    → secondary (gray)
    var menuBarCircleColor: Color {
        switch status {
        case .checking:    return .secondary
        case .reachable:   return isLinkWiFi ? .blue : .red
        case .unreachable: return .primary
        }
    }

    /// Seconds elapsed since the connection was last "fully healthy" (link
    /// connected *and* reachable), as of `now`. Ticks while healthy; frozen
    /// at its last value once either the link drops or reachability is lost;
    /// `nil` until the first time both are true. Drives the menu bar label
    /// only — see `reachElapsedSeconds(at:)` for the popover's (deliberately
    /// different) reachability-only value.
    ///
    /// Takes `now` as a parameter (rather than reading a `@Published` clock
    /// property on `AppState`) so that only the small views which actually
    /// display elapsed time re-render every second, instead of every view
    /// that observes `AppState` (see `ClockTick`).
    func menuBarTimerElapsedSeconds(at now: Date) -> Int? {
        if let start = menuBarTimerStart {
            return max(0, Int(now.timeIntervalSince(start)))
        }
        if let frozen = menuBarTimerFrozenElapsed {
            return max(0, Int(frozen))
        }
        return nil
    }

    /// Seconds elapsed since reachability was last (re)confirmed, as of `now`.
    /// Ticks while reachable; frozen at its last value while unreachable;
    /// `nil` until the first reachable confirmation. Drives the popover's
    /// elapsed-time row only — see `menuBarTimerElapsedSeconds(at:)` for the
    /// menu bar's (deliberately different) link+reachability-based value.
    func reachElapsedSeconds(at now: Date) -> Int? {
        if let start = reachTimerStart {
            return max(0, Int(now.timeIntervalSince(start)))
        }
        if let frozen = reachTimerFrozenElapsed {
            return max(0, Int(frozen))
        }
        return nil
    }

    /// "h:mm" elapsed string for the menu bar label (no seconds), as of `now`.
    func menuBarElapsedText(at now: Date) -> String {
        guard let secs = menuBarTimerElapsedSeconds(at: now) else { return "" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    var statusText: String {
        switch status {
        case .checking:    return "確認中…"
        case .reachable:   return "到達可能"
        case .unreachable: return "到達できません"
        }
    }

    var statusColor: Color {
        switch status {
        case .checking:    return .secondary
        case .reachable:   return .green
        case .unreachable: return .red
        }
    }

    /// ポップオーバーに表示するリンク種別のラベル。
    var linkTypeText: String {
        switch link.interfaceType {
        case .wifi:          return "Wi-Fi"
        case .wiredEthernet: return "Ethernet"
        case .cellular:      return "セルラー"
        case .loopback:      return "ループバック"
        case .other:         return "その他"
        case .none:          return "不明"
        @unknown default:    return "不明"
        }
    }

    /// 使用中のリンクが Wi-Fi かどうか。Ethernet 等の場合は SSID 表示が無意味なので、
    /// ポップオーバー側でこれを見て Wi-Fi 関連の行を出し分ける。
    var isLinkWiFi: Bool {
        link.interfaceType == .wifi
    }
}
