import Foundation

enum Constants {
    static let bundleIdentifier = "com.secrettunnel.vpn"
    static let tunnelBundleIdentifier = "com.secrettunnel.vpn.tunnel"
    static let appGroupIdentifier = "group.com.secrettunnel.vpn"
    static let appName = "Secret Tunnel"
    static let configDirectory = ".secrettunnel"
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
        static let service = "com.secrettunnel.vpn"
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

    enum Pricing {
        static let elasticIPMonthly = 3.65
        static let ebsPerGBMonthly = 0.08
        static let defaultVolumeGB = 8.0

        static let hourlyRates: [String: Double] = [
            "t3.micro":  0.0104,
            "t3.small":  0.0208,
            "t3.medium": 0.0416,
            "t3a.micro": 0.0094,
            "t3a.small": 0.0188,
            "t4g.micro": 0.0084,
            "t4g.small": 0.0168,
        ]

        static func hourlyRate(for instanceType: String) -> Double {
            hourlyRates[instanceType] ?? 0.0104
        }

        static var persistentMonthlyCost: Double {
            elasticIPMonthly + (ebsPerGBMonthly * defaultVolumeGB)
        }

        static func estimatedMonthlyCost(instanceType: String, hoursPerDay: Double) -> Double {
            let compute = hourlyRate(for: instanceType) * hoursPerDay * 30.0
            return persistentMonthlyCost + compute
        }

        static func formatCost(_ cost: Double) -> String {
            String(format: "$%.2f", cost)
        }

        static func formatRate(_ rate: Double) -> String {
            String(format: "$%.4f/hr", rate)
        }
    }
}
