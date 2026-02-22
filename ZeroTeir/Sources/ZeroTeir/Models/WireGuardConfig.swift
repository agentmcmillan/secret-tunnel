import Foundation

struct WireGuardPeer: Equatable {
    let publicKey: String
    let endpoint: String?
    let allowedIPs: String
    let persistentKeepalive: Int

    func toWgQuickConfig() -> String {
        var config = "[Peer]\n"
        config += "PublicKey = \(publicKey)\n"
        if let endpoint = endpoint {
            config += "Endpoint = \(endpoint)\n"
        }
        config += "AllowedIPs = \(allowedIPs)\n"
        config += "PersistentKeepalive = \(persistentKeepalive)\n"
        return config
    }
}

struct WireGuardConfig: Equatable {
    let privateKey: String
    let address: String
    let dns: String?
    let peers: [WireGuardPeer]

    init(
        privateKey: String,
        address: String,
        dns: String? = "1.1.1.1",
        serverPublicKey: String,
        endpoint: String,
        allowedIPs: String = "0.0.0.0/0",
        persistentKeepalive: Int = Constants.WireGuard.persistentKeepalive
    ) {
        self.privateKey = privateKey
        self.address = address
        self.dns = dns
        self.peers = [
            WireGuardPeer(
                publicKey: serverPublicKey,
                endpoint: "\(endpoint):\(Constants.WireGuard.port)",
                allowedIPs: allowedIPs,
                persistentKeepalive: persistentKeepalive
            )
        ]
    }

    init(
        privateKey: String,
        address: String,
        dns: String? = "1.1.1.1",
        peers: [WireGuardPeer]
    ) {
        self.privateKey = privateKey
        self.address = address
        self.dns = dns
        self.peers = peers
    }

    var serverEndpoint: String {
        return peers.first?.endpoint ?? ""
    }

    func toWgQuickConfig() -> String {
        var config = "[Interface]\n"
        config += "PrivateKey = \(privateKey)\n"
        config += "Address = \(address)\n"

        if let dns = dns {
            config += "DNS = \(dns)\n"
        }

        for peer in peers {
            config += "\n"
            config += peer.toWgQuickConfig()
        }

        return config
    }
}
