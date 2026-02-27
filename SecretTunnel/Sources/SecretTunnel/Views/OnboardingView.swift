import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var lambdaApiEndpoint: String = ""
    @State private var lambdaApiKey: String = ""
    @State private var headscaleURL: String = ""
    @State private var headscaleApiKey: String = ""
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var testingConnection: Bool = false
    @State private var testPassed: Bool = false

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Secret Tunnel")
                .font(.largeTitle)
                .fontWeight(.bold)

            TabView(selection: $currentStep) {
                welcomeStep
                    .tag(0)

                lambdaConfigStep
                    .tag(1)

                headscaleConfigStep
                    .tag(2)

                completionStep
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }

                Spacer()

                if currentStep < 3 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 600, height: 500)
        .alert("Configuration Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Secure VPN Access")
                .font(.title2)

            Text("Secret Tunnel provides on-demand VPN access through AWS EC2 and Headscale.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "bolt.fill", title: "On-Demand", description: "Start and stop your VPN server as needed")
                featureRow(icon: "lock.shield.fill", title: "Secure", description: "WireGuard protocol with Headscale")
                featureRow(icon: "gauge.high", title: "Fast", description: "Direct connection to your EC2 instance")
            }
            .padding()

            quickSetupHint
        }
    }

    private var lambdaConfigStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lambda API Configuration")
                .font(.title2)

            Text("The Lambda API controls your EC2 VPN server (start/stop/status).")
                .foregroundColor(.secondary)

            helpBox(steps: [
                "Run ./setup.sh --profile secrettunnel from the project root",
                "Or find these values in your Terraform outputs:",
                "  cd terraform && terraform output",
                "API Endpoint = api_endpoint output",
                "API Key = api_key output (sensitive)"
            ])

            VStack(alignment: .leading, spacing: 8) {
                Text("API Endpoint")
                    .font(.caption)
                TextField("https://abc123.execute-api.us-east-1.amazonaws.com/prod", text: $lambdaApiEndpoint)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                SecureField("Enter your API key", text: $lambdaApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Run: cd terraform && terraform output -raw api_key")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
    }

    private var headscaleConfigStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Headscale Configuration")
                .font(.title2)

            Text("Headscale coordinates the WireGuard VPN tunnel between your Mac and the EC2 server.")
                .foregroundColor(.secondary)

            helpBox(steps: [
                "If you used setup.sh, these values were printed at the end",
                "Headscale URL = https://<your-elastic-ip>",
                "API Key is auto-generated and stored in AWS SSM:",
                "  aws ssm get-parameter --name /secrettunnel/headscale-api-key \\",
                "    --with-decryption --query Parameter.Value --output text"
            ])

            VStack(alignment: .leading, spacing: 8) {
                Text("Headscale URL")
                    .font(.caption)
                TextField("https://13.216.86.47", text: $headscaleURL)
                    .textFieldStyle(.roundedBorder)
                Text("This is https:// followed by your Elastic IP from Terraform")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                SecureField("Enter your API key", text: $headscaleApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Auto-generated on first boot. Stored in AWS SSM Parameter Store.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var completionStep: some View {
        VStack(spacing: 16) {
            if testPassed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Setup Complete!")
                    .font(.title2)

                Text("Your connection was verified. Click 'Get Started' to begin.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("Verify Connection")
                    .font(.title2)

                Text("Test your configuration before getting started.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button(action: {
                    Task { await testOnboardingConnection() }
                }) {
                    HStack {
                        if testingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(testingConnection ? "Testing..." : "Test Connection")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(testingConnection)

                Text("You can also skip this and test later from Settings.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func testOnboardingConnection() async {
        testingConnection = true
        defer { testingConnection = false }

        do {
            guard let lambdaURL = URL(string: lambdaApiEndpoint) else {
                throw AppError.configurationMissing("Invalid Lambda API endpoint")
            }

            let instanceManager = InstanceManager(apiEndpoint: lambdaURL, apiKey: lambdaApiKey)
            _ = try await instanceManager.getStatus()

            guard let headscaleURL = URL(string: headscaleURL) else {
                throw AppError.configurationMissing("Invalid Headscale URL")
            }

            let headscaleClient = HeadscaleClient(serverURL: headscaleURL, apiKey: headscaleApiKey)
            let healthy = try await headscaleClient.checkHealth()

            if healthy {
                testPassed = true
            } else {
                errorMessage = "Headscale health check failed. The EC2 instance may need to be started first."
                showingError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private var quickSetupHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .foregroundColor(.accentColor)
                Text("Quick Setup")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text("Run this from the project root to deploy infrastructure and get all config values automatically:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("./setup.sh --profile secrettunnel")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(8)
    }

    private func helpBox(steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.orange)
                Text("Where to find this")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                if step.hasPrefix("  ") {
                    Text(step)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(step)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(6)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1:
            return !lambdaApiEndpoint.isEmpty && !lambdaApiKey.isEmpty
        case 2:
            return !headscaleURL.isEmpty && !headscaleApiKey.isEmpty
        default:
            return true
        }
    }

    private func completeOnboarding() {
        appState.settings.lambdaApiEndpoint = lambdaApiEndpoint
        appState.settings.headscaleURL = headscaleURL

        do {
            try appState.settings.saveToKeychain()
            try appState.settings.saveLambdaApiKey(lambdaApiKey)
            try appState.settings.saveHeadscaleApiKey(headscaleApiKey)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
