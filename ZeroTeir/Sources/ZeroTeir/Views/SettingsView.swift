import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var lambdaApiKey: String = ""
    @State private var headscaleApiKey: String = ""
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var testingConnection: Bool = false
    @State private var testResults: TestResults?

    var body: some View {
        @Bindable var bindableSettings = appState.settings

        TabView {
            connectionTab
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            wireguardTab
                .tabItem {
                    Label("WireGuard", systemImage: "lock.shield")
                }

            awsTab
                .tabItem {
                    Label("AWS", systemImage: "cloud")
                }

            networkTab
                .tabItem {
                    Label("Network", systemImage: "point.3.connected.trianglepath.dotted")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .padding()
        .onAppear {
            loadApiKeys()
        }
    }

    private var connectionTab: some View {
        @Bindable var bindableSettings = appState.settings

        return VStack(alignment: .leading, spacing: 16) {
            Text("API Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Lambda API Endpoint")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://api.example.com", text: $bindableSettings.lambdaApiEndpoint)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Lambda API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Enter API key", text: $lambdaApiKey)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Headscale URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://headscale.example.com", text: $bindableSettings.headscaleURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Headscale API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Enter API key", text: $headscaleApiKey)
                    .textFieldStyle(.roundedBorder)
            }

            if let results = testResults {
                testResultsView(results: results)
            }

            HStack {
                Button("Test Connection") {
                    Task {
                        await testConnection()
                    }
                }
                .disabled(testingConnection || !isFormValid)

                if testingConnection {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Spacer()

                Button("Cancel") {
                    closeWindow()
                }

                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }

            Spacer()
        }
        .alert("Error Saving Settings", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var networkTab: some View {
        @Bindable var bindableSettings = appState.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Home LAN Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Home LAN (Split Tunnel)")
                        .font(.headline)

                    Text("Route home network traffic through your NAS subnet router while internet goes through AWS.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Enable Home LAN Routing", isOn: $bindableSettings.homeLANEnabled)

                    if appState.settings.homeLANEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAS WireGuard Public Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Public key from your NAS", text: $bindableSettings.homeNASPublicKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAS Endpoint (optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g. home.ddns.net:51820", text: $bindableSettings.homeNASEndpoint)
                                .textFieldStyle(.roundedBorder)
                            Text("Leave empty if NAS connects to Headscale (recommended)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Home Subnet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("192.168.1.0/24", text: $bindableSettings.homeSubnet)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Divider()

                // UniFi Travel Router Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("UniFi Travel Router")
                        .font(.headline)

                    Text("Allow your UniFi travel router to connect to the AWS exit node as an additional WireGuard peer.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Enable Travel Router Peer", isOn: $bindableSettings.unifiEnabled)

                    if appState.settings.unifiEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Travel Router Public Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Public key from UniFi device", text: $bindableSettings.unifiPeerPublicKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server-Side Config")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("The AWS instance will automatically accept this peer via Headscale. Configure your UniFi travel router to connect to the AWS instance's Elastic IP on port \(Constants.WireGuard.port).")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var wireguardTab: some View {
        @Bindable var bindableSettings = appState.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WireGuard Configuration")
                    .font(.headline)

                Text("Customize WireGuard tunnel parameters. Changes take effect on next connection.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Port")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("51820", value: $bindableSettings.wireGuardPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("Default: 51820. Change if your network blocks this port.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DNS Servers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("1.1.1.1", text: $bindableSettings.wireGuardDNS)
                        .textFieldStyle(.roundedBorder)
                    Text("Comma-separated. Examples: 1.1.1.1, 8.8.8.8, 9.9.9.9")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Persistent Keepalive (seconds)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("25", value: $bindableSettings.wireGuardPersistentKeepalive, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("Sends keepalive packets to maintain NAT mappings. 25s is standard.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed IPs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0.0.0.0/0", text: $bindableSettings.wireGuardAllowedIPs)
                        .textFieldStyle(.roundedBorder)
                    Text("Controls what traffic routes through the tunnel. 0.0.0.0/0 = all traffic.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Button("Reset to Defaults") {
                        appState.settings.wireGuardPort = Constants.WireGuard.port
                        appState.settings.wireGuardDNS = "1.1.1.1"
                        appState.settings.wireGuardPersistentKeepalive = Constants.WireGuard.persistentKeepalive
                        appState.settings.wireGuardAllowedIPs = "0.0.0.0/0"
                    }
                    Spacer()
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var awsTab: some View {
        @Bindable var bindableSettings = appState.settings

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("AWS & Instance Configuration")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("AWS Region")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("AWS Region", selection: $bindableSettings.awsRegion) {
                        Text("US East (N. Virginia)").tag("us-east-1")
                        Text("US East (Ohio)").tag("us-east-2")
                        Text("US West (Oregon)").tag("us-west-2")
                        Text("US West (N. California)").tag("us-west-1")
                        Text("EU (Ireland)").tag("eu-west-1")
                        Text("EU (London)").tag("eu-west-2")
                        Text("EU (Frankfurt)").tag("eu-central-1")
                        Text("AP (Tokyo)").tag("ap-northeast-1")
                        Text("AP (Seoul)").tag("ap-northeast-2")
                        Text("AP (Singapore)").tag("ap-southeast-1")
                        Text("AP (Sydney)").tag("ap-southeast-2")
                        Text("AP (Mumbai)").tag("ap-south-1")
                        Text("SA (Sao Paulo)").tag("sa-east-1")
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Instance Type", selection: $bindableSettings.instanceType) {
                        Text("t3.micro - 1 vCPU, 1 GB ($0.0104/hr)").tag("t3.micro")
                        Text("t3.small - 2 vCPU, 2 GB ($0.0208/hr)").tag("t3.small")
                        Text("t3.medium - 2 vCPU, 4 GB ($0.0416/hr)").tag("t3.medium")
                        Text("t3a.micro - 1 vCPU, 1 GB ($0.0094/hr) AMD").tag("t3a.micro")
                        Text("t3a.small - 2 vCPU, 2 GB ($0.0188/hr) AMD").tag("t3a.small")
                        Text("t4g.micro - 2 vCPU, 1 GB ($0.0084/hr) Graviton").tag("t4g.micro")
                        Text("t4g.small - 2 vCPU, 2 GB ($0.0168/hr) Graviton").tag("t4g.small")
                    }
                    .pickerStyle(.menu)
                }

                costEstimateSection

                VStack(alignment: .leading, spacing: 8) {
                    Text("Idle Auto-Stop (minutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("60", value: $bindableSettings.idleAutoStopMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("Instance stops automatically after this many minutes of no traffic. 0 = never.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                Text("Headscale")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Namespace / User")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("default", text: $bindableSettings.headscaleNamespace)
                        .textFieldStyle(.roundedBorder)
                    Text("Headscale user namespace for this client. Usually 'default'.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-Disconnect Timeout (minutes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", value: $bindableSettings.autoDisconnectTimeout, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    Text("Automatically disconnect after this many minutes. 0 = never.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Spacer()
                    Button("Save") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var generalTab: some View {
        @Bindable var bindableSettings = appState.settings

        return VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.headline)

            Toggle("Launch at Login", isOn: $bindableSettings.launchAtLogin)

            Spacer()

            HStack {
                Spacer()
                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    closeWindow()
                }
            }
        }
    }

    private func testResultsView(results: TestResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lambda API")
                Spacer()
                if results.lambdaSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            HStack {
                Text("Headscale")
                Spacer()
                if results.headscaleSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            if let error = results.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var costEstimateSection: some View {
        let rate = Constants.Pricing.hourlyRate(for: appState.settings.instanceType)
        let persistent = Constants.Pricing.persistentMonthlyCost
        let at2hrs = Constants.Pricing.estimatedMonthlyCost(instanceType: appState.settings.instanceType, hoursPerDay: 2)
        let at8hrs = Constants.Pricing.estimatedMonthlyCost(instanceType: appState.settings.instanceType, hoursPerDay: 8)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Cost Estimate")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Persistent (EIP + EBS)")
                        .font(.caption2)
                    Spacer()
                    Text(Constants.Pricing.formatCost(persistent) + "/mo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Compute")
                        .font(.caption2)
                    Spacer()
                    Text(Constants.Pricing.formatRate(rate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack {
                    Text("~2 hrs/day")
                        .font(.caption2)
                    Spacer()
                    Text("~" + Constants.Pricing.formatCost(at2hrs) + "/mo")
                        .font(.caption2).bold()
                }
                HStack {
                    Text("~8 hrs/day")
                        .font(.caption2)
                    Spacer()
                    Text("~" + Constants.Pricing.formatCost(at8hrs) + "/mo")
                        .font(.caption2).bold()
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private var isFormValid: Bool {
        !appState.settings.lambdaApiEndpoint.isEmpty &&
        !appState.settings.headscaleURL.isEmpty &&
        !lambdaApiKey.isEmpty &&
        !headscaleApiKey.isEmpty
    }

    private func loadApiKeys() {
        do {
            lambdaApiKey = try appState.settings.getLambdaApiKey()
        } catch {
            lambdaApiKey = ""
        }

        do {
            headscaleApiKey = try appState.settings.getHeadscaleApiKey()
        } catch {
            headscaleApiKey = ""
        }
    }

    private func saveSettings() {
        do {
            try appState.settings.saveToKeychain()
            try appState.settings.saveLambdaApiKey(lambdaApiKey)
            try appState.settings.saveHeadscaleApiKey(headscaleApiKey)
            closeWindow()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }

    private func testConnection() async {
        testingConnection = true
        testResults = nil

        var lambdaSuccess = false
        var headscaleSuccess = false
        var errorMessage: String?

        do {
            guard let lambdaURL = URL(string: appState.settings.lambdaApiEndpoint) else {
                throw AppError.configurationMissing("Invalid Lambda API endpoint")
            }

            let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: lambdaApiKey)
            _ = try await instanceManager.getStatus()
            lambdaSuccess = true
        } catch {
            errorMessage = "Lambda API: \(error.localizedDescription)"
        }

        do {
            guard let headscaleURL = URL(string: appState.settings.headscaleURL) else {
                throw AppError.configurationMissing("Invalid Headscale URL")
            }

            let headscaleClient = HeadscaleClient(serverURL: headscaleURL, apiKey: headscaleApiKey)
            headscaleSuccess = try await headscaleClient.checkHealth()

            if !headscaleSuccess {
                errorMessage = "Headscale: Health check failed"
            }
        } catch {
            let currentError = "Headscale: \(error.localizedDescription)"
            if let existing = errorMessage {
                errorMessage = "\(existing)\n\(currentError)"
            } else {
                errorMessage = currentError
            }
        }

        await MainActor.run {
            testResults = TestResults(
                lambdaSuccess: lambdaSuccess,
                headscaleSuccess: headscaleSuccess,
                errorMessage: errorMessage
            )
            testingConnection = false
        }
    }

    private func closeWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.close()
        }
    }
}

struct TestResults {
    let lambdaSuccess: Bool
    let headscaleSuccess: Bool
    let errorMessage: String?
}
