import Foundation
import Network
import CoreWLAN
import SystemConfiguration.CaptiveNetwork

@Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.secrettunnel.networkmonitor")

    var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType?
    var currentSSID: String?
    var onNetworkChanged: (() -> Void)?
    var onUntrustedWiFiJoined: ((String) -> Void)?

    private var previouslyConnected: Bool = true
    private var previousSSID: String?

    init() {
        currentSSID = getCurrentSSID()
        previousSSID = currentSSID

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.previouslyConnected ?? true
                let nowConnected = path.status == .satisfied
                self?.isConnected = nowConnected
                self?.connectionType = path.availableInterfaces.first?.type
                self?.previouslyConnected = nowConnected
                Log.api.info("Network status changed: \(nowConnected ? "connected" : "disconnected")")

                // Detect SSID changes
                let newSSID = self?.getCurrentSSID()
                let oldSSID = self?.previousSSID
                self?.currentSSID = newSSID
                self?.previousSSID = newSSID

                // Trigger reconnect when network recovers after a drop
                if !wasConnected && nowConnected {
                    Log.api.info("Network recovered, triggering reconnect callback")
                    self?.onNetworkChanged?()
                }

                // Trigger auto-connect when joining a new WiFi network
                if nowConnected, let ssid = newSSID, ssid != oldSSID, path.usesInterfaceType(.wifi) {
                    Log.api.info("Joined WiFi network: \(ssid)")
                    self?.onUntrustedWiFiJoined?(ssid)
                }
            }
        }
        monitor.start(queue: queue)
    }

    func getCurrentSSID() -> String? {
        guard let wifiClient = CWWiFiClient.shared().interface() else { return nil }
        return wifiClient.ssid()
    }

    deinit {
        monitor.cancel()
    }

    func measureLatency(to host: String) async -> TimeInterval? {
        let start = Date()

        guard let url = URL(string: "https://\(host)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            _ = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(start)
            return latency
        } catch {
            Log.api.debug("Latency measurement failed: \(error.localizedDescription)")
            return nil
        }
    }
}
