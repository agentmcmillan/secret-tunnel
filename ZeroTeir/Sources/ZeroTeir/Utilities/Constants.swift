import Foundation

enum Constants {
    static let bundleIdentifier = "com.zeroteir.vpn"
    static let tunnelBundleIdentifier = "com.zeroteir.vpn.tunnel"
    static let appGroupIdentifier = "group.com.zeroteir.vpn"
    static let appName = "ZeroTeir"
    static let configDirectory = ".zeroteir"
    static let wireguardConfigName = "wg0.conf"

    enum Timeouts {
        static let instanceStart: TimeInterval = 60
        static let headscaleHealth: TimeInterval = 30
        static let apiRequest: TimeInterval = 30
    }

    enum Polling {
        static let headscaleHealthInterval: TimeInterval = 2
        static let connectionMonitorInterval: TimeInterval = 5
        static let handshakeStaleThreshold: TimeInterval = 180 // 3 minutes
        static let maxReconnectAttempts = 3
    }

    enum Retry {
        static let maxAttempts = 3
        static let initialDelay: TimeInterval = 1
        static let backoffMultiplier: TimeInterval = 2
    }

    enum Keychain {
        static let service = "com.zeroteir.vpn"
        static let lambdaApiKeyAccount = "lambdaApiKey"
        static let headscaleApiKeyAccount = "headscaleApiKey"
        static let wireguardPrivateKeyAccount = "wireguardPrivateKey"
    }

    enum WireGuard {
        static let port = 51820
        static let persistentKeepalive = 25
        static let interface = "wg0"
    }

    enum HomeNetwork {
        static let defaultSubnet = "192.168.0.0/20"
        static let defaultDNS = "192.168.1.1"
    }

    enum UniFi {
        static let defaultListenPort = 51820
    }
}
