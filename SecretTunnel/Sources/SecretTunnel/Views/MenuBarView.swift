import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    let connectionService: ConnectionService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusSection
            Divider()
            actionButton

            if appState.connectionState.isConnected, let status = appState.connectionStatus {
                Divider()
                statsSection(status: status)
            }

            if !appState.settings.homeNASPublicKey.isEmpty {
                Divider()
                homeLANToggle
            }

            Divider()
            settingsButton
            quitButton
        }
        .padding(8)
        .frame(width: 280)
    }

    private var statusSection: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.connectionState.displayName)
                    .font(.headline)

                if let status = appState.connectionStatus, appState.connectionState.isConnected {
                    Text(status.connectedIP)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch appState.connectionState {
        case .disconnected:
            Image(systemName: "shield.slash")
                .foregroundColor(.gray)
        case .startingInstance, .waitingForHeadscale, .connectingTunnel, .disconnecting:
            Image(systemName: "shield.lefthalf.filled")
                .foregroundColor(.orange)
        case .connected:
            Image(systemName: "shield.checkered")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }

    private var actionButton: some View {
        Button(action: {
            Task {
                if appState.connectionState.isConnected {
                    await connectionService.disconnect()
                } else if !appState.connectionState.isConnecting {
                    await connectionService.connect()
                }
            }
        }) {
            HStack {
                if appState.connectionState.isConnecting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(appState.connectionState.isConnecting || !appState.settings.isValid)
    }

    private var buttonTitle: String {
        if appState.connectionState.isConnecting {
            return "Connecting..."
        } else if appState.connectionState.isConnected {
            return "Disconnect"
        } else {
            return "Connect"
        }
    }

    private func statsSection(status: ConnectionStatus) -> some View {
        let rate = Constants.Pricing.hourlyRate(for: appState.settings.instanceType)
        let sessionCost = rate * (status.uptime / 3600.0)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Connection Stats")
                .font(.caption)
                .foregroundColor(.secondary)

            statsRow(label: "Latency", value: status.formattedLatency)
            statsRow(label: "Sent", value: status.formattedBytesSent)
            statsRow(label: "Received", value: status.formattedBytesReceived)
            statsRow(label: "Uptime", value: status.formattedUptime)

            Divider()

            statsRow(label: "Rate", value: Constants.Pricing.formatRate(rate))
            statsRow(label: "Session", value: Constants.Pricing.formatCost(sessionCost))
        }
        .font(.caption)
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }

    private var homeLANToggle: some View {
        @Bindable var bindableSettings = appState.settings

        return Toggle(isOn: $bindableSettings.homeLANEnabled) {
            HStack(spacing: 6) {
                Image(systemName: "house.fill")
                    .foregroundColor(appState.settings.homeLANEnabled ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Home LAN")
                        .font(.caption)
                    Text(appState.settings.homeSubnet)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var settingsButton: some View {
        Button("Settings...") {
            openSettings()
        }
    }

    private var quitButton: some View {
        Button("Quit Secret Tunnel") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func openSettings() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            let settingsView = SettingsView()
                .environment(appState)
                .frame(width: 580, height: 520)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.title = "Secret Tunnel Settings"
            window.contentView = NSHostingView(rootView: settingsView)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
