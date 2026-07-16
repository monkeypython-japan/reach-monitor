import Foundation
import Network

/// `LinkMonitor` が検知したリンク種別（Wi-Fi/Ethernet等）の変化を
/// `~/Library/Logs/reachmonitor_history.log` に1行追記する。
///
/// ネットワークのトラブルシュート用の生ログで、UI やアプリの動作には一切影響しない
/// 副作用としてのみ動作する（書き込み失敗は無視する）。
final class LinkHistoryLogger {
    private let logURL: URL
    private let maxSizeBytes: UInt64

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(
        logURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/reachmonitor_history.log"),
        maxSizeBytes: UInt64 = 5 * 1024 * 1024
    ) {
        self.logURL = logURL
        self.maxSizeBytes = maxSizeBytes
    }

    /// リンク種別の変化を1行追記する。`wifi` は変化時点の Wi-Fi 関連情報
    /// （AP 切り替えが原因か、単なる経路再評価かを切り分けるための併記）。
    func logLinkChange(from previous: LinkInfo, to current: LinkInfo, wifi: WiFiInfo) {
        rotateIfNeeded()

        let timestamp = Self.dateFormatter.string(from: Date())
        let line = "\(timestamp) link=\(name(previous.interfaceType)) -> \(name(current.interfaceType))"
            + " ssid=\(wifi.ssid ?? "-") bssid=\(wifi.bssid ?? "-")"
            + " hasWiFiInterface=\(wifi.hasWiFiInterface)\n"

        append(line)
    }

    private func name(_ type: NWInterface.InterfaceType?) -> String {
        switch type {
        case .wifi:          return "wifi"
        case .wiredEthernet: return "wiredEthernet"
        case .cellular:      return "cellular"
        case .loopback:      return "loopback"
        case .other:         return "other"
        case .none:          return "nil"
        @unknown default:    return "unknown"
        }
    }

    private func append(_ line: String) {
        let fm = FileManager.default
        let dir = logURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: logURL.path) {
            fm.createFile(atPath: logURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }

    private func rotateIfNeeded() {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: logURL.path),
              let size = (attrs[.size] as? NSNumber)?.uint64Value,
              size > maxSizeBytes else { return }

        let rotatedURL = logURL.appendingPathExtension("1")
        try? fm.removeItem(at: rotatedURL)
        try? fm.moveItem(at: logURL, to: rotatedURL)
    }
}
