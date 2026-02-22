import NetworkExtension
import WireGuardKit
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "WireGuard")
                .log(level: logLevel.osLogLevel, "\(message)")
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
            .info("Starting tunnel with options: \(String(describing: options))")

        guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration["wgQuickConfig"] as? String else {
            Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
                .error("Missing WireGuard configuration")
            completionHandler(NSError(domain: "com.zeroteir.vpn.tunnel",
                                     code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "Missing WireGuard configuration"]))
            return
        }

        do {
            let tunnelConfiguration = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig)

            adapter.start(tunnelConfiguration: tunnelConfiguration) { error in
                if let error = error {
                    Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
                        .error("Failed to start tunnel: \(error.localizedDescription)")
                    completionHandler(error)
                } else {
                    Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
                        .info("Tunnel started successfully")
                    completionHandler(nil)
                }
            }
        } catch {
            Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
                .error("Failed to parse WireGuard config: \(error.localizedDescription)")
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
            .info("Stopping tunnel, reason: \(reason.rawValue)")

        adapter.stop { error in
            if let error = error {
                Logger(subsystem: "com.zeroteir.vpn.tunnel", category: "Tunnel")
                    .error("Error stopping tunnel: \(error.localizedDescription)")
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        if message == "getTransferData" {
            adapter.getRuntimeConfiguration { settings in
                guard let settings = settings else {
                    completionHandler?(nil)
                    return
                }

                let rxBytes = settings.peers.first?.rxBytes ?? 0
                let txBytes = settings.peers.first?.txBytes ?? 0
                let lastHandshakeEpoch = settings.peers.first?.lastHandshakeTime?.timeIntervalSince1970 ?? 0

                let stats = TunnelStats(
                    rxBytes: rxBytes,
                    txBytes: txBytes,
                    lastHandshakeEpoch: UInt64(lastHandshakeEpoch)
                )

                if let responseData = try? JSONEncoder().encode(stats) {
                    completionHandler?(responseData)
                } else {
                    completionHandler?(nil)
                }
            }
        } else {
            completionHandler?(nil)
        }
    }
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
