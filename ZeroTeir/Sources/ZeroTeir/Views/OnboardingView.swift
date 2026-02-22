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

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to ZeroTeir")
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

            Text("ZeroTeir provides on-demand VPN access through AWS EC2 and Headscale.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "bolt.fill", title: "On-Demand", description: "Start and stop your VPN server as needed")
                featureRow(icon: "lock.shield.fill", title: "Secure", description: "WireGuard protocol with Headscale")
                featureRow(icon: "gauge.high", title: "Fast", description: "Direct connection to your EC2 instance")
            }
            .padding()
        }
    }

    private var lambdaConfigStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lambda API Configuration")
                .font(.title2)

            Text("Enter your Lambda API endpoint and API key. This is used to control your EC2 instance.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Endpoint")
                    .font(.caption)
                TextField("https://api.example.com", text: $lambdaApiEndpoint)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                SecureField("Enter your API key", text: $lambdaApiKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }

    private var headscaleConfigStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Headscale Configuration")
                .font(.title2)

            Text("Enter your Headscale server URL and API key.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Headscale URL")
                    .font(.caption)
                TextField("https://headscale.example.com", text: $headscaleURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                SecureField("Enter your API key", text: $headscaleApiKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }

    private var completionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title2)

            Text("You're all set to connect to your VPN. Click 'Get Started' to begin.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
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
