import SwiftUI

@main
struct ZeroTeirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            EmptyView()
        } label: {
            Image(systemName: "shield.slash")
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        NSApp.setActivationPolicy(.accessory)
    }
}
