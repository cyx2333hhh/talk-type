import AppKit
import SwiftUI

/// Manages a single AppKit-hosted settings window. Using AppKit (instead of a
/// SwiftUI `Window` scene) keeps the app a pure menu-bar accessory with no
/// window appearing at launch.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            let host = NSHostingController(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            let w = NSWindow(contentViewController: host)
            w.title = "Talk-type 设置"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 720, height: 580))
            w.minSize = NSSize(width: 680, height: 540)
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        let currentWindow = window
        DispatchQueue.main.async {
            currentWindow?.makeFirstResponder(nil)
        }
    }
}
