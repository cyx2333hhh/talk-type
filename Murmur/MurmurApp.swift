import SwiftUI

@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            HomeView()
                .environmentObject(app)
        } label: {
            Image(app.menuBarImageName)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app: shows a Dock icon and a centered main window, so it's
        // reachable even when the menu-bar icon is hidden (e.g. behind the notch).
        NSApp.setActivationPolicy(.regular)
        AppState.shared.bootstrap()
        MainWindowController.shared.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainWindowController.shared.show() }
        return true
    }
}
