import AppKit
import SwiftUI

/// A borderless, non-activating floating panel that hosts the recording overlay.
/// It is intentionally a FIXED size: the SwiftUI content lays out and animates
/// inside it, but the window itself never resizes. (Auto-sizing the window via
/// `NSHostingController.preferredContentSize` + animation recurses through
/// `updateAnimatedWindowSize` and overflows the stack.)
@MainActor
final class PanelController {
    private var panel: NSPanel?
    private let content: AnyView
    private let size: CGSize

    init(content: AnyView, size: CGSize) {
        self.content = content
        self.size = size
    }

    func show() {
        if panel == nil { build() }
        guard let panel else { return }
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func build() {
        let frame = NSRect(origin: .zero, size: size)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = frame

        let p = NSPanel(contentRect: frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = false
        p.contentView = hosting
        panel = p
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                     y: visible.minY + 120))
    }
}
