import AppKit
import SwiftUI

/// Hosts the main app window (HomeView). Because the menu-bar icon can get
/// hidden on notched Macs, the app also runs as a regular Dock app with this
/// window as a reliable way in. Shown when the Dock icon is clicked with no
/// visible windows.
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
            host.view.layoutSubtreeIfNeeded()
            let fittingSize = host.view.fittingSize
            if fittingSize.width > 0, fittingSize.height > 0 {
                w.setContentSize(fittingSize)
            }
            window = w
        }
        if let window {
            centerOnMainScreen(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func centerOnMainScreen(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let frame = window.frame
        window.setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2
        ))
    }
}
