import Foundation
import ServiceManagement

@Observable
class AppState {
    var connectionState: ConnectionState = .disconnected
    var connectionStatus: ConnectionStatus?
    var error: AppError?
    var settings: AppSettings

    init() {
        self.settings = AppSettings()
    }

    @MainActor
    func updateState(_ newState: ConnectionState) {
        connectionState = newState
        if case .error(let error) = newState {
            self.error = error
        }
    }

    @MainActor
    func updateStatus(_ status: ConnectionStatus?) {
        connectionStatus = status
    }

    @MainActor
    func clearError() {
        error = nil
    }
}

struct RegionConfig: Codable, Identifiable, Equatable {
    var id: String  // e.g. "us-east-1"
    var displayName: String  // e.g. "US East (N. Virginia)"
    var apiEndpoint: String
    var headscaleURL: String
    var apiKey: String = ""  // Stored separately in Keychain
    var headscaleApiKey: String = ""  // Stored separately in Keychain
}

@Observable
class AppSettings {
    var lambdaApiEndpoint: String = ""
    var headscaleURL: String = ""
    var awsRegion: String = "us-east-1"

    // Multi-region
    var regions: [RegionConfig] = []
    var selectedRegionId: String = ""
    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    Log.keychain.info("Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    Log.keychain.info("Launch at login disabled")
                }
            } catch {
                Log.keychain.error("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }
    var autoDisconnectTimeout: TimeInterval = 0

    // WireGuard
    var wireGuardPort: Int = Constants.WireGuard.port
    var wireGuardDNS: String = "1.1.1.1"
    var wireGuardPersistentKeepalive: Int = Constants.WireGuard.persistentKeepalive
    var wireGuardAllowedIPs: String = "0.0.0.0/0"

    // AWS / Instance
    var instanceType: String = "t3.micro"
    var idleAutoStopMinutes: Int = 60

    // Headscale
    var headscaleNamespace: String = "default"

    // Home network / split tunnel
    var homeLANEnabled: Bool = false
    var homeNASEndpoint: String = ""
    var homeNASPublicKey: String = ""
    var homeSubnet: String = Constants.HomeNetwork.defaultSubnet

    // Security
    var killSwitchEnabled: Bool = false
    var autoConnectUntrustedWiFi: Bool = false
    var trustedWiFiNetworks: String = ""  // Comma-separated SSIDs

    // Stealth mode
    var stealthModeEnabled: Bool = false
    var stealthPort: Int = Int(Constants.Stealth.defaultPort)

    // VPN exclusions (domain/IP bypass)
    var vpnExcludedRoutes: String = ""  // Newline-separated IPs/CIDRs/domains

    // UniFi travel router
    var unifiEnabled: Bool = false
    var unifiPeerPublicKey: String = ""

    var selectedRegion: RegionConfig? {
        regions.first(where: { $0.id == selectedRegionId })
    }

    var isValid: Bool {
        !lambdaApiEndpoint.isEmpty && !headscaleURL.isEmpty
    }

    func loadFromKeychain() {
        do {
            if let endpoint = try KeychainService.shared.load(key: "lambdaApiEndpoint") {
                lambdaApiEndpoint = endpoint
            }
            if let headscale = try KeychainService.shared.load(key: "headscaleURL") {
                headscaleURL = headscale
            }
            if let region = try KeychainService.shared.load(key: "awsRegion") {
                awsRegion = region
            }
            // Multi-region
            if let regionsJSON = try KeychainService.shared.load(key: "regions"),
               let data = regionsJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([RegionConfig].self, from: data) {
                regions = decoded
            }
            if let selRegion = try KeychainService.shared.load(key: "selectedRegionId") {
                selectedRegionId = selRegion
            }
            // WireGuard
            if let port = try KeychainService.shared.load(key: "wireGuardPort"), let p = Int(port) {
                wireGuardPort = p
            }
            if let dns = try KeychainService.shared.load(key: "wireGuardDNS") {
                wireGuardDNS = dns
            }
            if let ka = try KeychainService.shared.load(key: "wireGuardPersistentKeepalive"), let k = Int(ka) {
                wireGuardPersistentKeepalive = k
            }
            if let ips = try KeychainService.shared.load(key: "wireGuardAllowedIPs") {
                wireGuardAllowedIPs = ips
            }
            // AWS
            if let iType = try KeychainService.shared.load(key: "instanceType") {
                instanceType = iType
            }
            if let idle = try KeychainService.shared.load(key: "idleAutoStopMinutes"), let m = Int(idle) {
                idleAutoStopMinutes = m
            }
            // Headscale
            if let ns = try KeychainService.shared.load(key: "headscaleNamespace") {
                headscaleNamespace = ns
            }
            // Home LAN
            if let homeEnabled = try KeychainService.shared.load(key: "homeLANEnabled") {
                homeLANEnabled = homeEnabled == "true"
            }
            if let nasEndpoint = try KeychainService.shared.load(key: "homeNASEndpoint") {
                homeNASEndpoint = nasEndpoint
            }
            if let nasPubKey = try KeychainService.shared.load(key: "homeNASPublicKey") {
                homeNASPublicKey = nasPubKey
            }
            if let subnet = try KeychainService.shared.load(key: "homeSubnet") {
                homeSubnet = subnet
            }
            // Security
            if let ks = try KeychainService.shared.load(key: "killSwitchEnabled") {
                killSwitchEnabled = ks == "true"
            }
            if let ac = try KeychainService.shared.load(key: "autoConnectUntrustedWiFi") {
                autoConnectUntrustedWiFi = ac == "true"
            }
            if let tw = try KeychainService.shared.load(key: "trustedWiFiNetworks") {
                trustedWiFiNetworks = tw
            }
            // Stealth
            if let stealth = try KeychainService.shared.load(key: "stealthModeEnabled") {
                stealthModeEnabled = stealth == "true"
            }
            if let sp = try KeychainService.shared.load(key: "stealthPort"), let p = Int(sp) {
                stealthPort = p
            }
            // VPN Exclusions
            if let excluded = try KeychainService.shared.load(key: "vpnExcludedRoutes") {
                vpnExcludedRoutes = excluded
            }
            // UniFi
            if let unifiOn = try KeychainService.shared.load(key: "unifiEnabled") {
                unifiEnabled = unifiOn == "true"
            }
            if let unifiKey = try KeychainService.shared.load(key: "unifiPeerPublicKey") {
                unifiPeerPublicKey = unifiKey
            }
        } catch {
            Log.keychain.error("Failed to load settings from keychain: \(error.localizedDescription)")
        }
    }

    func saveToKeychain() throws {
        try KeychainService.shared.save(key: "lambdaApiEndpoint", value: lambdaApiEndpoint)
        try KeychainService.shared.save(key: "headscaleURL", value: headscaleURL)
        try KeychainService.shared.save(key: "awsRegion", value: awsRegion)
        // Multi-region
        if let regionsData = try? JSONEncoder().encode(regions),
           let regionsJSON = String(data: regionsData, encoding: .utf8) {
            try KeychainService.shared.save(key: "regions", value: regionsJSON)
        }
        try KeychainService.shared.save(key: "selectedRegionId", value: selectedRegionId)
        try KeychainService.shared.save(key: "wireGuardPort", value: String(wireGuardPort))
        try KeychainService.shared.save(key: "wireGuardDNS", value: wireGuardDNS)
        try KeychainService.shared.save(key: "wireGuardPersistentKeepalive", value: String(wireGuardPersistentKeepalive))
        try KeychainService.shared.save(key: "wireGuardAllowedIPs", value: wireGuardAllowedIPs)
        try KeychainService.shared.save(key: "instanceType", value: instanceType)
        try KeychainService.shared.save(key: "idleAutoStopMinutes", value: String(idleAutoStopMinutes))
        try KeychainService.shared.save(key: "headscaleNamespace", value: headscaleNamespace)
        try KeychainService.shared.save(key: "homeLANEnabled", value: homeLANEnabled ? "true" : "false")
        try KeychainService.shared.save(key: "homeNASEndpoint", value: homeNASEndpoint)
        try KeychainService.shared.save(key: "homeNASPublicKey", value: homeNASPublicKey)
        try KeychainService.shared.save(key: "homeSubnet", value: homeSubnet)
        try KeychainService.shared.save(key: "killSwitchEnabled", value: killSwitchEnabled ? "true" : "false")
        try KeychainService.shared.save(key: "autoConnectUntrustedWiFi", value: autoConnectUntrustedWiFi ? "true" : "false")
        try KeychainService.shared.save(key: "trustedWiFiNetworks", value: trustedWiFiNetworks)
        try KeychainService.shared.save(key: "stealthModeEnabled", value: stealthModeEnabled ? "true" : "false")
        try KeychainService.shared.save(key: "stealthPort", value: String(stealthPort))
        try KeychainService.shared.save(key: "vpnExcludedRoutes", value: vpnExcludedRoutes)
        try KeychainService.shared.save(key: "unifiEnabled", value: unifiEnabled ? "true" : "false")
        try KeychainService.shared.save(key: "unifiPeerPublicKey", value: unifiPeerPublicKey)
    }

    func getLambdaApiKey() throws -> String {
        guard let key = try KeychainService.shared.load(key: Constants.Keychain.lambdaApiKeyAccount) else {
            throw AppError.configurationMissing("Lambda API Key")
        }
        return key
    }

    func getHeadscaleApiKey() throws -> String {
        guard let key = try KeychainService.shared.load(key: Constants.Keychain.headscaleApiKeyAccount) else {
            throw AppError.configurationMissing("Headscale API Key")
        }
        return key
    }

    /// Migrate from flat settings to multi-region on first load
    func migrateToRegions() {
        guard regions.isEmpty && !lambdaApiEndpoint.isEmpty else { return }

        let displayNames: [String: String] = [
            "us-east-1": "US East (N. Virginia)", "us-east-2": "US East (Ohio)",
            "us-west-1": "US West (N. California)", "us-west-2": "US West (Oregon)",
            "eu-west-1": "EU (Ireland)", "eu-west-2": "EU (London)",
            "eu-central-1": "EU (Frankfurt)", "ap-northeast-1": "AP (Tokyo)",
            "ap-northeast-2": "AP (Seoul)", "ap-southeast-1": "AP (Singapore)",
            "ap-southeast-2": "AP (Sydney)", "ap-south-1": "AP (Mumbai)",
            "sa-east-1": "SA (Sao Paulo)"
        ]

        let region = RegionConfig(
            id: awsRegion,
            displayName: displayNames[awsRegion] ?? awsRegion,
            apiEndpoint: lambdaApiEndpoint,
            headscaleURL: headscaleURL
        )
        regions = [region]
        selectedRegionId = region.id
        Log.keychain.info("Migrated flat settings to region: \(region.id)")
    }

    func saveLambdaApiKey(_ key: String) throws {
        try KeychainService.shared.save(key: Constants.Keychain.lambdaApiKeyAccount, value: key)
    }

    func saveHeadscaleApiKey(_ key: String) throws {
        try KeychainService.shared.save(key: Constants.Keychain.headscaleApiKeyAccount, value: key)
    }
}
