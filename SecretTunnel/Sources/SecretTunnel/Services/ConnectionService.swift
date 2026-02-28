import Foundation
import CryptoKit

@MainActor
class ConnectionService: ObservableObject {
    private let appState: AppState
    private let tunnelManager: TunnelManager
    private let networkMonitor: NetworkMonitor

    private var monitoringTask: Task<Void, Never>?
    private var autoDisconnectTask: Task<Void, Never>?
    private var connectionStartTime: Date?
    private var reconnectAttempts = 0
    private var stealthBridge: StealthBridge?

    init(appState: AppState) {
        self.appState = appState
        self.tunnelManager = TunnelManager()
        self.networkMonitor = NetworkMonitor()

        networkMonitor.onNetworkChanged = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleNetworkRecovery()
            }
        }

        networkMonitor.onUntrustedWiFiJoined = { [weak self] ssid in
            guard let self else { return }
            Task { @MainActor in
                await self.handleUntrustedWiFi(ssid: ssid)
            }
        }
    }

    private func handleUntrustedWiFi(ssid: String) async {
        guard appState.settings.autoConnectUntrustedWiFi else { return }
        guard !appState.connectionState.isConnected && !appState.connectionState.isConnecting else { return }

        let trustedList = appState.settings.trustedWiFiNetworks
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        if trustedList.contains(ssid.lowercased()) {
            Log.connection.info("WiFi '\(ssid)' is trusted, skipping auto-connect")
            return
        }

        Log.connection.info("Untrusted WiFi '\(ssid)' detected, auto-connecting VPN...")
        await connect()
    }

    private func handleNetworkRecovery() async {
        guard appState.connectionState.isConnected else { return }
        Log.connection.info("Network changed while connected, checking tunnel health...")

        do {
            let stats = try await tunnelManager.getStats()
            if let lastHandshake = stats.lastHandshake,
               Date().timeIntervalSince(lastHandshake) > Constants.Polling.handshakeStaleThreshold {
                Log.connection.info("Tunnel stale after network change, reconnecting...")
                await disconnect()
                try await Task.sleep(nanoseconds: 1_000_000_000)
                await connect()
            } else {
                Log.connection.info("Tunnel still healthy after network change")
            }
        } catch {
            Log.connection.warning("Failed to check tunnel after network change: \(error.localizedDescription)")
        }
    }

    func connect() async {
        Log.connection.info("Starting connection flow...")
        appState.clearError()

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.performConnect()
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: 120_000_000_000) // 120s
                    throw AppError.timeout
                }

                // Whichever finishes first wins; cancel the other
                try await group.next()
                group.cancelAll()
            }
        } catch let error as AppError {
            Log.connection.error("Connection failed: \(error.localizedDescription)")
            await rollback()
            appState.updateState(.error(error))
        } catch is CancellationError {
            Log.connection.info("Connection cancelled")
        } catch {
            Log.connection.error("Connection failed with unexpected error: \(error.localizedDescription)")
            await rollback()
            appState.updateState(.error(.unknownError(error.localizedDescription)))
        }
    }

    private func performConnect() async throws {
        // Use selected region config if available, fall back to flat settings
        let region = appState.settings.selectedRegion
        let apiEndpoint = region?.apiEndpoint ?? appState.settings.lambdaApiEndpoint
        let hsURL = region?.headscaleURL ?? appState.settings.headscaleURL

        let apiKey = try appState.settings.getLambdaApiKey()
        let headscaleApiKey = try appState.settings.getHeadscaleApiKey()

        guard let lambdaURL = URL(string: apiEndpoint) else {
            throw AppError.configurationMissing("Invalid Lambda API endpoint")
        }

        guard let headscaleURL = URL(string: hsURL) else {
            throw AppError.configurationMissing("Invalid Headscale URL")
        }

        await appState.updateState(.startingInstance)
        let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: apiKey)
        let instanceInfo = try await instanceManager.start(instanceType: appState.settings.instanceType)

        guard let publicIP = instanceInfo.publicIp else {
            throw AppError.instanceStartFailed("No public IP returned")
        }

        await appState.updateState(.waitingForHeadscale)
        let headscaleClient = HeadscaleClient(serverURL: headscaleURL, apiKey: headscaleApiKey)
        try await waitForHeadscale(client: headscaleClient)

        // Ensure this machine is registered with Headscale
        try await ensureRegistered(headscaleClient: headscaleClient)

        await appState.updateState(.connectingTunnel)

        // Start stealth bridge if enabled (wraps WireGuard UDP in TLS TCP)
        var effectiveEndpoint = publicIP
        if appState.settings.stealthModeEnabled {
            let bridge = StealthBridge(
                localPort: Constants.Stealth.localBridgePort,
                remoteHost: publicIP,
                remotePort: UInt16(appState.settings.stealthPort)
            )
            try await bridge.start()
            self.stealthBridge = bridge
            effectiveEndpoint = "127.0.0.1"
            Log.connection.info("Stealth mode active: WireGuard via TLS TCP \(publicIP):\(self.appState.settings.stealthPort)")
        }

        let config = try await getWireGuardConfig(headscaleClient: headscaleClient, endpoint: effectiveEndpoint)
        try await tunnelManager.connect(config: config, killSwitch: appState.settings.killSwitchEnabled)

        try await verifyConnection(expectedIP: publicIP)

        await MainActor.run {
            connectionStartTime = Date()
            reconnectAttempts = 0
            appState.updateState(.connected)
            startMonitoring()
        }

        Log.connection.info("Connection flow completed successfully")
    }

    func disconnect() async {
        Log.connection.info("Starting disconnect flow...")
        stopMonitoring()

        appState.updateState(.disconnecting)

        // Stop stealth bridge if active
        stealthBridge?.stop()
        stealthBridge = nil

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

        let s = appState.settings

        // Fetch the server's public key from Headscale
        let serverPublicKey = try await fetchServerPublicKey(headscaleClient: headscaleClient)

        // Determine the WireGuard port — in stealth mode, use the local bridge port
        let wgPort = s.stealthModeEnabled ? Int(Constants.Stealth.localBridgePort) : s.wireGuardPort

        // AWS peer - routes all internet traffic
        var awsAllowedIPs = s.wireGuardAllowedIPs

        // Apply VPN exclusions if configured
        if !s.vpnExcludedRoutes.isEmpty {
            let exclusions = parseExcludedRoutes(s.vpnExcludedRoutes)
            if !exclusions.isEmpty {
                awsAllowedIPs = RouteCalculator.allowedIPsExcluding(exclusions)
            }
        }

        if s.homeLANEnabled && !s.homeNASPublicKey.isEmpty {
            // When split tunnel is on, AWS gets everything except home subnet
            awsAllowedIPs = "0.0.0.0/1, 128.0.0.0/1"
        }

        var peers = [
            WireGuardPeer(
                publicKey: serverPublicKey,
                endpoint: "\(endpoint):\(wgPort)",
                allowedIPs: awsAllowedIPs,
                persistentKeepalive: s.wireGuardPersistentKeepalive
            )
        ]

        // Home NAS peer - routes home LAN traffic
        if s.homeLANEnabled && !s.homeNASPublicKey.isEmpty {
            let homeEndpoint = s.homeNASEndpoint.isEmpty ? nil : s.homeNASEndpoint
            peers.append(
                WireGuardPeer(
                    publicKey: s.homeNASPublicKey,
                    endpoint: homeEndpoint,
                    allowedIPs: s.homeSubnet,
                    persistentKeepalive: s.wireGuardPersistentKeepalive
                )
            )
        }

        let dns = s.homeLANEnabled ? Constants.HomeNetwork.defaultDNS : s.wireGuardDNS

        let config = WireGuardConfig(
            privateKey: privateKey,
            address: "100.64.0.1/32",
            dns: dns,
            peers: peers
        )

        return config
    }

    private func fetchServerPublicKey(headscaleClient: HeadscaleClient) async throws -> String {
        Log.connection.info("Fetching server public key from Headscale...")
        let machines = try await headscaleClient.listMachines()

        // Find the AWS exit node — it's typically the first machine or the one with a public IP
        guard let server = machines.first else {
            throw AppError.headscaleTimeout
        }

        guard let nodeKey = server.nodeKey, !nodeKey.isEmpty else {
            throw AppError.tunnelFailed("Server node has no public key")
        }

        Log.connection.info("Got server public key from node: \(server.name)")
        return nodeKey
    }

    private func ensureRegistered(headscaleClient: HeadscaleClient) async throws {
        let machines = try await headscaleClient.listMachines()
        let privateKey = try getOrCreateWireGuardKey()
        let publicKey = try derivePublicKey(from: privateKey)

        // Check if this machine is already registered
        if machines.contains(where: { $0.nodeKey == publicKey }) {
            Log.connection.info("Machine already registered with Headscale")
            return
        }

        Log.connection.info("Machine not registered, creating pre-auth key...")
        let namespace = appState.settings.headscaleNamespace
        let preAuthKey = try await headscaleClient.createPreAuthKey(user: namespace, reusable: false)

        // Store the pre-auth key — the tunnel extension uses it during WireGuard handshake
        // Delete any old pre-auth key first to avoid accumulation
        try? KeychainService.shared.delete(key: Constants.Keychain.headscalePreAuthKeyAccount)
        try KeychainService.shared.save(key: Constants.Keychain.headscalePreAuthKeyAccount, value: preAuthKey.key)
        Log.connection.info("Machine registered with Headscale, pre-auth key stored")
    }

    private func derivePublicKey(from base64PrivateKey: String) throws -> String {
        guard let keyData = Data(base64Encoded: base64PrivateKey) else {
            throw AppError.tunnelFailed("Invalid base64 private key")
        }
        let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: keyData)
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
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
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return privateKey.rawRepresentation.base64EncodedString()
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

        stealthBridge?.stop()
        stealthBridge = nil

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

        startAutoDisconnectTimer()
    }

    private func startAutoDisconnectTimer() {
        autoDisconnectTask?.cancel()
        autoDisconnectTask = nil

        let timeout = appState.settings.autoDisconnectTimeout
        guard timeout > 0 else { return }

        let timeoutSeconds = timeout * 60  // Setting is in minutes
        Log.connection.info("Auto-disconnect timer started: \(Int(timeout)) minutes")

        autoDisconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled && appState.connectionState.isConnected else { return }
            Log.connection.info("Auto-disconnect timeout reached, disconnecting...")
            await disconnect()
        }
    }

    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        autoDisconnectTask?.cancel()
        autoDisconnectTask = nil
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

    private func parseExcludedRoutes(_ routes: String) -> [String] {
        return routes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { entry -> String? in
                // If it looks like a CIDR or IP, return as-is
                if entry.contains("/") || entry.contains(".") {
                    return entry.contains("/") ? entry : "\(entry)/32"
                }
                // Domain name — resolve to IP at connect time
                return resolveDomain(entry)
            }
    }

    private func resolveDomain(_ domain: String) -> String? {
        let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()
        var resolved = DarwinBoolean(false)
        CFHostStartInfoResolution(host, .addresses, nil)
        guard let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as NSArray?,
              let firstAddr = addresses.firstObject as? Data else {
            Log.connection.warning("Failed to resolve domain: \(domain)")
            return nil
        }
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        firstAddr.withUnsafeBytes { ptr in
            let sockaddr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            getnameinfo(sockaddr, socklen_t(firstAddr.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
        }
        let ip = String(cString: hostname)
        Log.connection.info("Resolved \(domain) → \(ip)")
        return "\(ip)/32"
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
