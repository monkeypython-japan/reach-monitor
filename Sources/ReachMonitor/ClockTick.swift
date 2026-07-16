import Foundation

/// 1 秒ごとに現在時刻を発行するだけの軽量な ObservableObject。
///
/// 経過時間の表示（メニューバーのラベル・ポップオーバーの経過時間行）だけがこれを
/// 購読する。以前は `AppState` 自体に 1 秒タイマーの `@Published var currentTime`
/// を持たせていたが、`AppState` は `MenuContent` 全体（ターゲット一覧や
/// ボタンを含む）から購読されているため、毎秒の tick のたびにポップオーバー全体の
/// view body が再評価され、ポップオーバー非表示時も含めて無視できない CPU
/// 負荷になっていた。経過時間専用の Clock を切り出すことで、tick の影響を
/// 実際に時刻を表示している小さな View だけに閉じ込める。
@MainActor
final class ClockTick: ObservableObject {
    @Published private(set) var now = Date()
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.now = Date() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
