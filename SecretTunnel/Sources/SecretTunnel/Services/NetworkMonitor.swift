import Foundation
import Network

@Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.secrettunnel.networkmonitor")

    var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType?
    var onNetworkChanged: (() -> Void)?

    private var previouslyConnected: Bool = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.previouslyConnected ?? true
                let nowConnected = path.status == .satisfied
                self?.isConnected = nowConnected
                self?.connectionType = path.availableInterfaces.first?.type
                self?.previouslyConnected = nowConnected
                Log.api.info("Network status changed: \(nowConnected ? "connected" : "disconnected")")

                // Trigger reconnect when network recovers after a drop
                if !wasConnected && nowConnected {
                    Log.api.info("Network recovered, triggering reconnect callback")
                    self?.onNetworkChanged?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    func measureLatency(to host: String) async -> TimeInterval? {
        let start = Date()

        let url = URL(string: "http://\(host)")!
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
