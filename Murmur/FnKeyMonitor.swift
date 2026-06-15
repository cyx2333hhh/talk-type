import AppKit
import Carbon.HIToolbox

/// Detects presses of the physical fn / 🌐 (Globe) key to use it as the trigger.
/// The fn key can't be registered through Carbon's RegisterEventHotKey, so we
/// watch `.flagsChanged` events and match the fn key's own key code (63).
///
/// Note: the global monitor only receives keyboard events when the app is
/// trusted for Accessibility — so the fn trigger needs that permission to work
/// system-wide. (The in-app record button works without it.)
final class FnKeyMonitor {
    static let shared = FnKeyMonitor()

    var onTrigger: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fnDown = false

    private init() {}

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        fnDown = false
    }

    private func handle(_ event: NSEvent) {
        guard Int(event.keyCode) == kVK_Function else { return }
        let isDown = event.modifierFlags.contains(.function)
        if isDown && !fnDown {
            fnDown = true
            onTrigger?()
        } else if !isDown {
            fnDown = false
        }
    }
}
