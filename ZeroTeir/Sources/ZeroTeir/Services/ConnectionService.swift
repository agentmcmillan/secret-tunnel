import Foundation

@MainActor
class ConnectionService: ObservableObject {
    private let appState: AppState
    private let tunnelManager: TunnelManager
    private let networkMonitor: NetworkMonitor

    private var monitoringTask: Task<Void, Never>?
    private var connectionStartTime: Date?
    private var reconnectAttempts = 0

    init(appState: AppState) {
        self.appState = appState
        self.tunnelManager = TunnelManager()
        self.networkMonitor = NetworkMonitor()
    }

    func connect() async {
        Log.connection.info("Starting connection flow...")
        appState.clearError()

        do {
            let apiKey = try appState.settings.getLambdaApiKey()
            let headscaleApiKey = try appState.settings.getHeadscaleApiKey()

            guard let lambdaURL = URL(string: appState.settings.lambdaApiEndpoint) else {
                throw AppError.configurationMissing("Invalid Lambda API endpoint")
            }

            guard let headscaleURL = URL(string: appState.settings.headscaleURL) else {
                throw AppError.configurationMissing("Invalid Headscale URL")
            }

            appState.updateState(.startingInstance)
            let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: apiKey)
            let instanceInfo = try await instanceManager.start()

            guard let publicIP = instanceInfo.publicIp else {
                throw AppError.instanceStartFailed("No public IP returned")
            }

            appState.updateState(.waitingForHeadscale)
            let headscaleClient = HeadscaleClient(serverURL: headscaleURL, apiKey: headscaleApiKey)
            try await waitForHeadscale(client: headscaleClient)

            appState.updateState(.connectingTunnel)
            let config = try await getWireGuardConfig(headscaleClient: headscaleClient, endpoint: publicIP)
            try await tunnelManager.connect(config: config)

            try await verifyConnection(expectedIP: publicIP)

            connectionStartTime = Date()
            reconnectAttempts = 0
            appState.updateState(.connected)
            startMonitoring()

            Log.connection.info("Connection flow completed successfully")

        } catch let error as AppError {
            Log.connection.error("Connection failed: \(error.localizedDescription)")
            await rollback()
            appState.updateState(.error(error))
        } catch {
            Log.connection.error("Connection failed with unexpected error: \(error.localizedDescription)")
            await rollback()
            appState.updateState(.error(.unknownError(error.localizedDescription)))
        }
    }

    func disconnect() async {
        Log.connection.info("Starting disconnect flow...")
        stopMonitoring()

        appState.updateState(.disconnecting)

        do {
            try await tunnelManager.disconnect()
        } catch {
            Log.connection.warning("Tunnel disconnect failed: \(error.localizedDescription)")
        }

        Task.detached {
            do {
                let apiKey = try self.appState.settings.getLambdaApiKey()
                guard let lambdaURL = URL(string: self.appState.settings.lambdaApiEndpoint) else {
                    return
                }
                let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: apiKey)
                try await instanceManager.stop()
                Log.connection.info("Instance stopped")
            } catch {
                Log.connection.warning("Instance stop failed: \(error.localizedDescription)")
            }
        }

        connectionStartTime = nil
        await appState.updateState(.disconnected)
        await appState.updateStatus(nil)

        Log.connection.info("Disconnect flow completed")
    }

    private func waitForHeadscale(client: HeadscaleClient) async throws {
        let timeout = Date().addingTimeInterval(Constants.Timeouts.headscaleHealth)
        let pollInterval = Constants.Polling.headscaleHealthInterval

        while Date() < timeout {
            if try await client.checkHealth() {
                Log.connection.info("Headscale is healthy")
                return
            }

            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        throw AppError.headscaleTimeout
    }

    private func getWireGuardConfig(headscaleClient: HeadscaleClient, endpoint: String) async throws -> WireGuardConfig {
        let privateKey = try getOrCreateWireGuardKey()

        let config = WireGuardConfig(
            privateKey: privateKey,
            address: "100.64.0.1/32",
            dns: "1.1.1.1",
            serverPublicKey: "SERVER_PUBLIC_KEY_PLACEHOLDER",
            endpoint: endpoint
        )

        return config
    }

    private func getOrCreateWireGuardKey() throws -> String {
        if let existingKey = try KeychainService.shared.load(key: Constants.Keychain.wireguardPrivateKeyAccount) {
            return existingKey
        }

        let newKey = generateWireGuardPrivateKey()
        try KeychainService.shared.save(key: Constants.Keychain.wireguardPrivateKeyAccount, value: newKey)
        return newKey
    }

    private func generateWireGuardPrivateKey() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/wg")
        process.arguments = ["genkey"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return key.isEmpty ? "GENERATED_PRIVATE_KEY_PLACEHOLDER" : key
    }

    private func verifyConnection(expectedIP: String) async throws {
        guard let url = URL(string: "https://api.ipify.org?format=json") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let ip = json["ip"] {
                Log.connection.info("Public IP verified: \(ip)")
            }
        } catch {
            Log.connection.warning("Failed to verify public IP: \(error.localizedDescription)")
        }
    }

    private func rollback() async {
        Log.connection.info("Rolling back connection attempt...")

        do {
            try await tunnelManager.disconnect()
        } catch {
            Log.connection.warning("Rollback: tunnel disconnect failed: \(error.localizedDescription)")
        }

        Task.detached {
            do {
                let apiKey = try self.appState.settings.getLambdaApiKey()
                guard let lambdaURL = URL(string: self.appState.settings.lambdaApiEndpoint) else {
                    return
                }
                let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: apiKey)
                try await instanceManager.stop()
                Log.connection.info("Rollback: instance stopped")
            } catch {
                Log.connection.warning("Rollback: instance stop failed: \(error.localizedDescription)")
            }
        }
    }

    private func startMonitoring() {
        monitoringTask = Task { @MainActor in
            while !Task.isCancelled && appState.connectionState.isConnected {
                await updateConnectionStatus()
                try? await Task.sleep(nanoseconds: UInt64(Constants.Polling.connectionMonitorInterval * 1_000_000_000))
            }
        }
    }

    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func updateConnectionStatus() async {
        do {
            let stats = try await tunnelManager.getStats()

            guard let startTime = connectionStartTime else {
                return
            }

            let uptime = Date().timeIntervalSince(startTime)

            var latency: TimeInterval?
            if let endpoint = stats.endpoint {
                let host = endpoint.components(separatedBy: ":").first ?? endpoint
                latency = await networkMonitor.measureLatency(to: host)
            }

            let status = ConnectionStatus(
                connectedIP: stats.endpoint ?? "Unknown",
                latency: latency,
                bytesSent: stats.bytesSent,
                bytesReceived: stats.bytesReceived,
                uptime: uptime,
                lastHandshake: stats.lastHandshake
            )

            appState.updateStatus(status)

            if status.isHandshakeStale {
                Log.connection.warning("Handshake is stale, attempting reconnect...")
                await handleStaleConnection()
            }

        } catch {
            Log.connection.warning("Failed to update connection status: \(error.localizedDescription)")
        }
    }

    private func handleStaleConnection() async {
        reconnectAttempts += 1

        if reconnectAttempts >= Constants.Polling.maxReconnectAttempts {
            Log.connection.error("Max reconnect attempts reached, disconnecting")
            await disconnect()
            appState.updateState(.error(.tunnelFailed("Connection lost")))
            reconnectAttempts = 0
        } else {
            Log.connection.info("Reconnect attempt \(self.reconnectAttempts)/\(Constants.Polling.maxReconnectAttempts)")
        }
    }
}
