import Foundation
import Network

@Observable
class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.zeroteir.networkmonitor")

    var isConnected: Bool = true
    var connectionType: NWInterface.InterfaceType?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
                Log.api.info("Network status changed: \(path.status == .satisfied ? "connected" : "disconnected")")
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
