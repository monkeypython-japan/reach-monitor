import Foundation
import SwiftUI

/// Central observable state. Owns the monitors, funnels their callbacks onto the
/// main actor, and exposes published values for the SwiftUI menu.
@MainActor
final class AppState: ObservableObject {
    @Published var status: ReachStatus = .checking
    @Published var results: [TargetResult] = []
    @Published var wifi: WiFiInfo = WiFiInfo(
        ssid: nil, bssid: nil, connectedSince: nil,
        locationAuthorized: false, hasWiFiInterface: false
    )

    /// Drives the live elapsed-time displays (menu bar label + popover).
    @Published var currentTime = Date()

    private let reachability = ReachabilityMonitor(targets: DefaultTargets.all)
    private let wifiMonitor = WiFiMonitor()
    private let notifications = NotificationManager()
    private var clockTimer: Timer?

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
    }

    func start() {
        notifications.requestAuthorization()
        reachability.start()
        wifiMonitor.start()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.currentTime = Date() }
        }
    }

    func checkNow() {
        status = .checking
        reachability.checkNow()
    }

    private func apply(results: [TargetResult], status: ReachStatus) {
        self.results = results
        self.status = status
        let failed = results.filter { $0.reachable != true }.map(\.target)
        notifications.handle(status: status, failedTargets: failed)
    }

    // MARK: - Derived presentation values

    /// Color of the circle shown in the menu bar.
    /// - Reachable   → red   (赤丸)
    /// - Unreachable → primary (黒/白: adapts to menu bar appearance)
    /// - Checking    → secondary (gray)
    var menuBarCircleColor: Color {
        switch status {
        case .checking:    return .secondary
        case .reachable:   return .red
        case .unreachable: return .primary
        }
    }

    /// "h:mm" elapsed string for the menu bar label (no seconds).
    var menuBarElapsedText: String {
        guard let since = wifi.connectedSince else { return "" }
        let secs = max(0, Int(currentTime.timeIntervalSince(since)))
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
}
