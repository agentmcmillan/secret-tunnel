import Foundation
import NetworkExtension

class TunnelManager {
    enum TunnelError: Error {
        case configurationLoadFailed
        case configurationSaveFailed
        case connectionFailed(String)
        case disconnectionFailed(String)
        case invalidStats
        case noManager
        case ipcFailed
    }

    private var manager: NETunnelProviderManager?
    private var statusObserver: Any?

    init() {
        setupStatusObserver()
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadOrCreateManager() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let existingManager = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Constants.tunnelBundleIdentifier }) {
            self.manager = existingManager
            Log.tunnel.info("Loaded existing VPN configuration")
        } else {
            let newManager = NETunnelProviderManager()
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = Constants.tunnelBundleIdentifier
            protocolConfiguration.serverAddress = "ZeroTeir VPN"
            newManager.protocolConfiguration = protocolConfiguration
            newManager.localizedDescription = "ZeroTeir VPN"
            newManager.isEnabled = true

            try await newManager.saveToPreferences()
            try await newManager.loadFromPreferences()

            self.manager = newManager
            Log.tunnel.info("Created new VPN configuration")
        }
    }

    func connect(config: WireGuardConfig) async throws {
        Log.tunnel.info("Connecting NetworkExtension tunnel...")

        if manager == nil {
            try await loadOrCreateManager()
        }

        guard let manager = manager else {
            throw TunnelError.noManager
        }

        let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol ?? NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = Constants.tunnelBundleIdentifier
        protocolConfiguration.serverAddress = config.serverEndpoint

        let wgQuickConfig = config.toWgQuickConfig()
        protocolConfiguration.providerConfiguration = ["wgQuickConfig": wgQuickConfig as NSString]

        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        do {
            try manager.connection.startVPNTunnel()
            Log.tunnel.info("NetworkExtension tunnel started successfully")
        } catch {
            Log.tunnel.error("Failed to start tunnel: \(error.localizedDescription)")
            throw TunnelError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async throws {
        Log.tunnel.info("Disconnecting NetworkExtension tunnel...")

        guard let manager = manager else {
            throw TunnelError.noManager
        }

        manager.connection.stopVPNTunnel()
        Log.tunnel.info("NetworkExtension tunnel disconnected successfully")
    }

    func getStats() async throws -> WireGuardStats {
        guard let manager = manager,
              let session = manager.connection as? NETunnelProviderSession else {
            throw TunnelError.noManager
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                let message = "getTransferData".data(using: .utf8)!
                try session.sendProviderMessage(message) { responseData in
                    guard let data = responseData,
                          let stats = try? JSONDecoder().decode(TunnelStats.self, from: data) else {
                        continuation.resume(throwing: TunnelError.invalidStats)
                        return
                    }

                    let lastHandshake: Date?
                    if stats.lastHandshakeEpoch > 0 {
                        lastHandshake = Date(timeIntervalSince1970: TimeInterval(stats.lastHandshakeEpoch))
                    } else {
                        lastHandshake = nil
                    }

                    let wireGuardStats = WireGuardStats(
                        bytesSent: stats.txBytes,
                        bytesReceived: stats.rxBytes,
                        lastHandshake: lastHandshake,
                        endpoint: nil
                    )

                    continuation.resume(returning: wireGuardStats)
                }
            } catch {
                continuation.resume(throwing: TunnelError.ipcFailed)
            }
        }
    }

    func getCurrentStatus() -> NEVPNStatus {
        return manager?.connection.status ?? .invalid
    }

    private func setupStatusObserver() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else {
                return
            }

            let status = connection.status
            Log.tunnel.info("VPN status changed: \(self?.statusString(status) ?? "unknown")")
        }
    }

    private func statusString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
}
