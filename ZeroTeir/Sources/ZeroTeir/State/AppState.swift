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
        } catch {
            Log.keychain.error("Failed to load settings from keychain: \(error.localizedDescription)")
        }
    }

    func saveToKeychain() throws {
        try KeychainService.shared.save(key: "lambdaApiEndpoint", value: lambdaApiEndpoint)
        try KeychainService.shared.save(key: "headscaleURL", value: headscaleURL)
        try KeychainService.shared.save(key: "awsRegion", value: awsRegion)
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
