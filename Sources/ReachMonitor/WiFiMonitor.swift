import Foundation
import CoreWLAN
import CoreLocation

/// Snapshot of the current Wi-Fi association.
struct WiFiInfo {
    var ssid: String?
    var bssid: String?
    /// Whether Location authorization is granted (required for SSID/BSSID on
    /// macOS 14+). When `false`, `ssid`/`bssid` will be `nil`.
    var locationAuthorized: Bool
    /// Whether a Wi-Fi interface exists and reports a hardware/power-on state.
    var hasWiFiInterface: Bool
}

/// Tracks the current Wi-Fi AP via CoreWLAN, using Location authorization so the
/// BSSID/SSID are readable.
final class WiFiMonitor: NSObject, CWEventDelegate, CLLocationManagerDelegate {
    private let client = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private var pollTimer: DispatchSourceTimer?

    /// Called on the main queue whenever the Wi-Fi info changes.
    var onUpdate: ((WiFiInfo) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        client.delegate = self
    }

    func start() {
        // Request Location permission; SSID/BSSID are gated behind it.
        locationManager.requestWhenInUseAuthorization()

        // Subscribe to AP-change events, plus a polling fallback for reliability.
        try? client.startMonitoringEvent(with: .bssidDidChange)
        try? client.startMonitoringEvent(with: .ssidDidChange)
        try? client.startMonitoringEvent(with: .linkDidChange)

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: MonitorConfig.wifiPollInterval)
        t.setEventHandler { [weak self] in self?.refresh() }
        pollTimer = t
        t.resume()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        try? client.stopMonitoringAllEvents()
    }

    /// Read the current association and emit an update.
    func refresh() {
        let interface = client.interface()
        let bssid = interface?.bssid()
        let ssid = interface?.ssid()

        let info = WiFiInfo(
            ssid: ssid,
            bssid: bssid,
            locationAuthorized: isLocationAuthorized,
            hasWiFiInterface: interface != nil && interface?.powerOn() == true
        )
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(info) }
    }

    private var isLocationAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorized:
            return true
        default:
            return false
        }
    }

    // MARK: - CWEventDelegate

    func bssidDidChangeForWiFiInterface(withName interfaceName: String) {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Once authorized, SSID/BSSID become readable — re-read immediately.
        refresh()
    }
}
