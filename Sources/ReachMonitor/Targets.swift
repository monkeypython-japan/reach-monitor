import Foundation

/// A destination whose reachability we monitor via a TCP (or TCP+TLS)
/// connection attempt.
struct Target: Identifiable, Hashable {
    let name: String
    let host: String
    let port: UInt16
    /// Whether to require a full TLS handshake (with certificate validation)
    /// rather than a bare TCP handshake. A captive portal that transparently
    /// intercepts port 443 can complete a TCP handshake without actually
    /// reaching the real destination, but it cannot present a certificate
    /// that validates for that destination's hostname/IP — so TLS is a much
    /// stronger reachability signal for HTTPS-capable targets (see ADR-0013).
    let usesTLS: Bool

    var id: String { "\(host):\(port)" }
    var displayHostPort: String { "\(host):\(port)" }
}

enum DefaultTargets {
    /// Fixed set of destinations. A successful handshake to any one of them
    /// means the network can reach the outside world; hostnames additionally
    /// exercise DNS resolution.
    static let all: [Target] = [
        Target(name: "Cloudflare", host: "1.1.1.1", port: 443, usesTLS: true),
        Target(name: "Google DNS", host: "8.8.8.8", port: 53, usesTLS: false),
        Target(name: "Apple",      host: "apple.com", port: 443, usesTLS: true),
    ]
}

/// Tuning constants for the reachability checks.
enum MonitorConfig {
    /// How often to run a full sweep of all targets.
    static let checkInterval: TimeInterval = 10
    /// Per-target TCP connection timeout.
    static let connectionTimeout: TimeInterval = 5
    /// How often to poll the Wi-Fi BSSID as a fallback to event notifications.
    static let wifiPollInterval: TimeInterval = 5
}
