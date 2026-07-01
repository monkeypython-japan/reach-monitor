import Foundation
import UserNotifications

/// Posts user notifications on reachability state transitions only (edges), to
/// avoid repeated alerts while a condition persists.
final class NotificationManager {
    private var authorized = false
    private var lastStatus: ReachStatus?

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    /// Feed the latest aggregate status. Fires a notification only when the
    /// status crosses between reachable and unreachable.
    func handle(status: ReachStatus, failedTargets: [Target]) {
        defer { lastStatus = status }
        guard let previous = lastStatus else { return } // skip the very first sample

        if previous != .unreachable && status == .unreachable {
            let names = failedTargets.map(\.name).joined(separator: ", ")
            notify(
                title: "目的アドレスに到達できません",
                body: names.isEmpty ? "すべての監視先に到達できませんでした。" : "到達不能: \(names)"
            )
        } else if previous == .unreachable && status == .reachable {
            notify(title: "接続が復旧しました", body: "目的アドレスへの到達を確認しました。")
        }
    }

    private func notify(title: String, body: String) {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
