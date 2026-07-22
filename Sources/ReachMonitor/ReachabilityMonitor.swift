import Foundation
import Network

/// Overall reachability verdict aggregated across all targets.
enum ReachStatus {
    case checking
    case reachable
    case unreachable
}

/// The result of the most recent probe for a single target.
struct TargetResult: Identifiable {
    let target: Target
    var reachable: Bool?
    var lastChecked: Date?
    var latency: TimeInterval?

    var id: String { target.id }
}

/// Periodically probes each target with a TCP connection attempt and reports
/// results back on the main queue via `onUpdate`.
final class ReachabilityMonitor {
    private let targets: [Target]
    private let queue = DispatchQueue(label: "com.mamoru.reachmonitor.probe")
    private var timer: DispatchSourceTimer?

    /// Called on the main queue with per-target results and the aggregate status.
    var onUpdate: (([TargetResult], ReachStatus) -> Void)?

    init(targets: [Target]) {
        self.targets = targets
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: MonitorConfig.checkInterval)
        t.setEventHandler { [weak self] in self?.checkAll() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Trigger an immediate sweep (used by the "check now" button).
    func checkNow() {
        queue.async { [weak self] in self?.checkAll() }
    }

    private func checkAll() {
        let group = DispatchGroup()
        var results: [String: TargetResult] = [:]
        let lock = NSLock()

        for target in targets {
            group.enter()
            probe(target) { reachable, latency in
                lock.lock()
                results[target.id] = TargetResult(
                    target: target,
                    reachable: reachable,
                    lastChecked: Date(),
                    latency: latency
                )
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let ordered = self.targets.map { results[$0.id]
                ?? TargetResult(target: $0, reachable: nil, lastChecked: nil, latency: nil) }
            let anyReachable = ordered.contains { $0.reachable == true }
            let status: ReachStatus = anyReachable ? .reachable : .unreachable
            self.onUpdate?(ordered, status)
        }
    }

    /// Attempt a single TCP (or TCP+TLS, when `target.usesTLS`) connection.
    /// Reports success on `.ready` (which for a TLS target implies a valid,
    /// certificate-verified handshake, not just a TCP accept — see ADR-0013),
    /// failure on `.failed`/`.cancelled` or after `connectionTimeout`.
    private func probe(_ target: Target, completion: @escaping (Bool, TimeInterval?) -> Void) {
        let host = NWEndpoint.Host(target.host)
        guard let port = NWEndpoint.Port(rawValue: target.port) else {
            completion(false, nil)
            return
        }

        let params = target.usesTLS ? NWParameters.tls : NWParameters.tcp
        let connection = NWConnection(host: host, port: port, using: params)
        let started = Date()

        // Ensure completion fires exactly once and the connection is torn down.
        let done = DispatchQueue(label: "com.mamoru.reachmonitor.done.\(target.id)")
        var finished = false
        func finish(_ ok: Bool) {
            done.sync {
                guard !finished else { return }
                finished = true
                let latency = ok ? Date().timeIntervalSince(started) : nil
                connection.stateUpdateHandler = nil
                connection.cancel()
                completion(ok, latency)
            }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed, .cancelled:
                finish(false)
            case .waiting:
                // No route / actively refused at the network layer.
                finish(false)
            default:
                break
            }
        }

        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + MonitorConfig.connectionTimeout) {
            finish(false)
        }
    }
}
