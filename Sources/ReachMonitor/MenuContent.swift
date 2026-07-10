import SwiftUI

/// The popover shown from the menu bar item.
struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            wifiSection
            Divider()
            targetsSection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.statusColor)
                .frame(width: 10, height: 10)
            Text(state.statusText)
                .font(.headline)
            Spacer()
        }
    }

    private var wifiSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("使用中のリンク")
                    .font(.subheadline).bold()
                Spacer()
                Text(state.linkTypeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if state.isLinkWiFi {
                HStack {
                    Text("Wi-Fi")
                        .font(.subheadline).bold()
                    Spacer()
                    Text(state.wifi.ssid ?? (state.wifi.locationAuthorized ? "未接続" : "位置情報が必要"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("到達確認からの経過時間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(elapsedString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if state.isLinkWiFi && !state.wifi.locationAuthorized {
                Text("SSID の表示には位置情報の許可が必要です。")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("監視対象")
                .font(.subheadline).bold()
            ForEach(state.results) { result in
                HStack(spacing: 8) {
                    Image(systemName: symbol(for: result))
                        .foregroundStyle(color(for: result))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.target.name)
                            .font(.caption)
                        Text(result.target.displayHostPort)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(latencyString(result))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("今すぐ再チェック") { state.checkNow() }
            Spacer()
            Button("終了") { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Helpers

    private var elapsedString: String {
        guard let secs = state.reachElapsedSeconds else { return "—" }
        let h = secs / 3600, m = (secs % 3600) / 60, s = secs % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func symbol(for r: TargetResult) -> String {
        switch r.reachable {
        case .some(true):  return "checkmark.circle.fill"
        case .some(false): return "xmark.circle.fill"
        case .none:        return "circle.dotted"
        }
    }

    private func color(for r: TargetResult) -> Color {
        switch r.reachable {
        case .some(true):  return .green
        case .some(false): return .red
        case .none:        return .secondary
        }
    }

    private func latencyString(_ r: TargetResult) -> String {
        if let l = r.latency { return String(format: "%d ms", Int(l * 1000)) }
        if r.reachable == false { return "不可" }
        return "—"
    }
}
