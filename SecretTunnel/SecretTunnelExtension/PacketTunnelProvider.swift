import NetworkExtension
import WireGuardKit
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "WireGuard")
                .log(level: logLevel.osLogLevel, "\(message)")
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
            .info("Starting tunnel with options: \(String(describing: options))")

        guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration,
              let wgQuickConfig = providerConfiguration["wgQuickConfig"] as? String else {
            Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
                .error("Missing WireGuard configuration")
            completionHandler(NSError(domain: "com.secrettunnel.vpn.tunnel",
                                     code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "Missing WireGuard configuration"]))
            return
        }

        guard let tunnelConfiguration = parseWgQuickConfig(wgQuickConfig) else {
            Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
                .error("Failed to parse WireGuard config")
            completionHandler(NSError(domain: "com.secrettunnel.vpn.tunnel",
                                     code: 2,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to parse WireGuard configuration"]))
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfiguration) { error in
            if let error = error {
                Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
                    .error("Failed to start tunnel: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
                    .info("Tunnel started successfully")
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
            .info("Stopping tunnel, reason: \(reason.rawValue)")

        adapter.stop { error in
            if let error = error {
                Logger(subsystem: "com.secrettunnel.vpn.tunnel", category: "Tunnel")
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
            adapter.getRuntimeConfiguration { configString in
                guard let configString = configString else {
                    completionHandler?(nil)
                    return
                }

                let stats = self.parseRuntimeStats(configString)
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

    private func parseWgQuickConfig(_ config: String) -> TunnelConfiguration? {
        let lines = config.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var privateKeyStr: String?
        var addresses: [IPAddressRange] = []
        var dns: [DNSServer] = []
        var peers: [PeerConfiguration] = []

        var currentPeerPublicKey: String?
        var currentPeerEndpoint: String?
        var currentPeerAllowedIPs: [IPAddressRange] = []
        var currentPeerKeepAlive: UInt16?

        var inInterface = false
        var inPeer = false

        for line in lines {
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line == "[Interface]" {
                if inPeer, let pubKeyStr = currentPeerPublicKey, let pubKey = PublicKey(base64Key: pubKeyStr) {
                    var peer = PeerConfiguration(publicKey: pubKey)
                    peer.allowedIPs = currentPeerAllowedIPs
                    if let ep = currentPeerEndpoint, let endpoint = Endpoint(from: ep) {
                        peer.endpoint = endpoint
                    }
                    peer.persistentKeepAlive = currentPeerKeepAlive
                    peers.append(peer)
                }
                inInterface = true
                inPeer = false
                continue
            }

            if line == "[Peer]" {
                if inPeer, let pubKeyStr = currentPeerPublicKey, let pubKey = PublicKey(base64Key: pubKeyStr) {
                    var peer = PeerConfiguration(publicKey: pubKey)
                    peer.allowedIPs = currentPeerAllowedIPs
                    if let ep = currentPeerEndpoint, let endpoint = Endpoint(from: ep) {
                        peer.endpoint = endpoint
                    }
                    peer.persistentKeepAlive = currentPeerKeepAlive
                    peers.append(peer)
                }
                inInterface = false
                inPeer = true
                currentPeerPublicKey = nil
                currentPeerEndpoint = nil
                currentPeerAllowedIPs = []
                currentPeerKeepAlive = nil
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let value = parts[1]

            if inInterface {
                switch key {
                case "PrivateKey":
                    privateKeyStr = value
                case "Address":
                    for addr in value.split(separator: ",") {
                        if let range = IPAddressRange(from: addr.trimmingCharacters(in: .whitespaces)) {
                            addresses.append(range)
                        }
                    }
                case "DNS":
                    for d in value.split(separator: ",") {
                        if let server = DNSServer(from: d.trimmingCharacters(in: .whitespaces)) {
                            dns.append(server)
                        }
                    }
                default:
                    break
                }
            } else if inPeer {
                switch key {
                case "PublicKey":
                    currentPeerPublicKey = value
                case "Endpoint":
                    currentPeerEndpoint = value
                case "AllowedIPs":
                    for ip in value.split(separator: ",") {
                        if let range = IPAddressRange(from: ip.trimmingCharacters(in: .whitespaces)) {
                            currentPeerAllowedIPs.append(range)
                        }
                    }
                case "PersistentKeepalive":
                    currentPeerKeepAlive = UInt16(value)
                default:
                    break
                }
            }
        }

        // Flush last peer
        if inPeer, let pubKeyStr = currentPeerPublicKey, let pubKey = PublicKey(base64Key: pubKeyStr) {
            var peer = PeerConfiguration(publicKey: pubKey)
            peer.allowedIPs = currentPeerAllowedIPs
            if let ep = currentPeerEndpoint, let endpoint = Endpoint(from: ep) {
                peer.endpoint = endpoint
            }
            peer.persistentKeepAlive = currentPeerKeepAlive
            peers.append(peer)
        }

        guard let pkStr = privateKeyStr, let privateKey = PrivateKey(base64Key: pkStr) else {
            return nil
        }

        var interfaceConfig = InterfaceConfiguration(privateKey: privateKey)
        interfaceConfig.addresses = addresses
        interfaceConfig.dns = dns

        return TunnelConfiguration(name: "Secret Tunnel", interface: interfaceConfig, peers: peers)
    }

    private func parseRuntimeStats(_ config: String) -> TunnelStats {
        var rxBytes: UInt64 = 0
        var txBytes: UInt64 = 0
        var lastHandshakeEpoch: UInt64 = 0

        for line in config.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("rx_bytes=") {
                rxBytes = UInt64(trimmed.replacingOccurrences(of: "rx_bytes=", with: "")) ?? 0
            } else if trimmed.hasPrefix("tx_bytes=") {
                txBytes = UInt64(trimmed.replacingOccurrences(of: "tx_bytes=", with: "")) ?? 0
            } else if trimmed.hasPrefix("last_handshake_time_sec=") {
                lastHandshakeEpoch = UInt64(trimmed.replacingOccurrences(of: "last_handshake_time_sec=", with: "")) ?? 0
            }
        }

        return TunnelStats(rxBytes: rxBytes, txBytes: txBytes, lastHandshakeEpoch: lastHandshakeEpoch)
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
