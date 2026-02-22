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

    private var generalTab: some View {
        @Bindable var bindableSettings = appState.settings

        return VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.headline)

            Toggle("Launch at Login", isOn: $bindableSettings.launchAtLogin)

            VStack(alignment: .leading, spacing: 8) {
                Text("AWS Region")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("AWS Region", selection: $bindableSettings.awsRegion) {
                    Text("US East (N. Virginia)").tag("us-east-1")
                    Text("US West (Oregon)").tag("us-west-2")
                    Text("EU (Ireland)").tag("eu-west-1")
                    Text("EU (Frankfurt)").tag("eu-central-1")
                    Text("AP (Tokyo)").tag("ap-northeast-1")
                    Text("AP (Singapore)").tag("ap-southeast-1")
                }
                .pickerStyle(.menu)
            }

            Spacer()

            HStack {
                Spacer()
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
