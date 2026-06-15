import AppKit
import ApplicationServices

/// Inserts text into whatever app currently has focus by placing it on the
/// pasteboard and synthesizing a ⌘V. Requires Accessibility permission to post
/// the keystroke; without it we leave the text on the clipboard instead.
enum TextInserter {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Returns true if it auto-pasted, false if it could only copy to clipboard.
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard isTrusted else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // 'V'
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore the user's previous clipboard once the paste has landed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pasteboard.clearContents()
            if let previous { pasteboard.setString(previous, forType: .string) }
        }
        return true
    }

    /// Triggers the system prompt to grant Accessibility access.
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
