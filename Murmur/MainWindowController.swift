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
                rootView: HomeView(presentation: .mainWindow)
                    .environmentObject(AppState.shared)
            )
            let w = NSWindow(contentViewController: host)
            w.title = "Talk-type"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 620, height: 600))
            w.minSize = NSSize(width: 560, height: 540)
            w.isReleasedWhenClosed = false
            window = w
        }
        if let window {
            centerOnMainScreen(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        let currentWindow = window
        DispatchQueue.main.async {
            currentWindow?.makeFirstResponder(nil)
        }
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
