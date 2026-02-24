import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState = AppState()
    private var connectionService: ConnectionService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.settings.loadFromKeychain()
        connectionService = ConnectionService(appState: appState)
        setupMenuBar()

        if !appState.settings.isValid {
            showOnboarding()
        }
    }

    @MainActor private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon(for: .disconnected)
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient

        if let connectionService = connectionService {
            let menuBarView = MenuBarView(connectionService: connectionService)
                .environment(appState)

            popover.contentViewController = NSHostingController(rootView: menuBarView)
        }

        self.popover = popover

        observeStateChanges()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func observeStateChanges() {
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: NSNotification.Name("ConnectionStateChanged")) {
                updateMenuBarIcon(for: appState.connectionState)
            }
        }

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMenuBarIcon(for: self.appState.connectionState)
            }
        }
    }

    @MainActor
    private func updateMenuBarIcon(for state: ConnectionState) {
        guard let button = statusItem?.button else { return }

        let (iconName, tintColor) = iconConfiguration(for: state)

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: state.displayName)?
            .withSymbolConfiguration(config)

        button.image = image

        if let tintColor = tintColor {
            button.contentTintColor = tintColor
        }
    }

    private func iconConfiguration(for state: ConnectionState) -> (String, NSColor?) {
        switch state {
        case .disconnected:
            return ("shield.slash", .systemGray)
        case .startingInstance, .waitingForHeadscale, .connectingTunnel, .disconnecting:
            return ("shield.lefthalf.filled", .systemOrange)
        case .connected:
            return ("shield.checkered", .systemGreen)
        case .error:
            return ("exclamationmark.triangle", .systemRed)
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView {
            self.closeOnboarding()
        }
        .environment(appState)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("onboarding")
        window.title = "Secret Tunnel Setup"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboarding() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            window.close()
        }
    }
}
