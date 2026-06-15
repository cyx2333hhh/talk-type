import AppKit
import SwiftUI

/// Hosts the main app window (HomeView). Because the menu-bar icon can get
/// hidden on notched Macs, the app also runs as a regular Dock app with this
/// window as a reliable way in. Shown at launch and when the Dock icon is
/// clicked with no visible windows.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let host = NSHostingController(
                rootView: HomeView().environmentObject(AppState.shared)
            )
            let w = NSWindow(contentViewController: host)
            w.title = "Murmur"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
