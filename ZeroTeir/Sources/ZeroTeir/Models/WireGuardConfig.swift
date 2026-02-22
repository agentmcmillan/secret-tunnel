import Foundation

struct WireGuardConfig: Equatable {
    let privateKey: String
    let address: String
    let dns: String?
    let serverPublicKey: String
    let endpoint: String
    let allowedIPs: String
    let persistentKeepalive: Int

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
        self.serverPublicKey = serverPublicKey
        self.endpoint = endpoint
        self.allowedIPs = allowedIPs
        self.persistentKeepalive = persistentKeepalive
    }

    func toConfigFile() -> String {
        var config = """
        [Interface]
        PrivateKey = \(privateKey)
        Address = \(address)
        """

        if let dns = dns {
            config += "\nDNS = \(dns)"
        }

        config += """

        [Peer]
        PublicKey = \(serverPublicKey)
        Endpoint = \(endpoint):\(Constants.WireGuard.port)
        AllowedIPs = \(allowedIPs)
        PersistentKeepalive = \(persistentKeepalive)
        """

        return config
    }
}
