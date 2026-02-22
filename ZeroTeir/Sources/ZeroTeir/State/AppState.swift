import Foundation

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

@Observable
class AppSettings {
    var lambdaApiEndpoint: String = ""
    var headscaleURL: String = ""
    var awsRegion: String = "us-east-1"
    var launchAtLogin: Bool = false
    var autoDisconnectTimeout: TimeInterval = 0

    // Home network / split tunnel
    var homeLANEnabled: Bool = false
    var homeNASEndpoint: String = ""
    var homeNASPublicKey: String = ""
    var homeSubnet: String = Constants.HomeNetwork.defaultSubnet

    // UniFi travel router
    var unifiEnabled: Bool = false
    var unifiPeerPublicKey: String = ""

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
        try KeychainService.shared.save(key: "homeLANEnabled", value: homeLANEnabled ? "true" : "false")
        try KeychainService.shared.save(key: "homeNASEndpoint", value: homeNASEndpoint)
        try KeychainService.shared.save(key: "homeNASPublicKey", value: homeNASPublicKey)
        try KeychainService.shared.save(key: "homeSubnet", value: homeSubnet)
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

    func saveLambdaApiKey(_ key: String) throws {
        try KeychainService.shared.save(key: Constants.Keychain.lambdaApiKeyAccount, value: key)
    }

    func saveHeadscaleApiKey(_ key: String) throws {
        try KeychainService.shared.save(key: Constants.Keychain.headscaleApiKeyAccount, value: key)
    }
}
