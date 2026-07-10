import Foundation
import Network

/// 現在のデフォルト経路が使っているインターフェースの種別。
struct LinkInfo {
    var interfaceType: NWInterface.InterfaceType?
}

/// NWPathMonitor でシステムの現在の経路を監視し、実際にトラフィックが流れている
/// インターフェース種別（Wi-Fi / Ethernet / その他）を報告する。
final class LinkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mamoru.reachmonitor.linkmonitor")

    /// メインキューで呼ばれる更新コールバック。
    var onUpdate: ((LinkInfo) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            // availableInterfaces は優先順（実際に使われている経路が先頭）で
            // 返るため、先頭のインターフェースを「現在使用中のリンク」とみなす。
            let info = LinkInfo(interfaceType: path.availableInterfaces.first?.type)
            DispatchQueue.main.async { self?.onUpdate?(info) }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
