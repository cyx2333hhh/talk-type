import AppKit
import ApplicationServices

struct FocusedTextContext {
    static let empty = FocusedTextContext(beforeCursor: "", afterCursor: "")

    let beforeCursor: String
    let afterCursor: String

    var isEmpty: Bool {
        beforeCursor.isEmpty && afterCursor.isEmpty
    }
}

/// Inserts text into whatever app currently has focus by placing it on the
/// pasteboard and synthesizing a ⌘V. Requires Accessibility permission to post
/// the keystroke; without it we leave the text on the clipboard instead.
enum TextInserter {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Reads a small window around the current insertion point. Secure fields
    /// are deliberately ignored, and the returned value is never persisted.
    static func focusedTextContext(maxCharacters: Int = 800) -> FocusedTextContext {
        guard isTrusted, maxCharacters > 0 else { return .empty }

        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system,
                                            kAXFocusedUIElementAttribute as CFString,
                                            &focusedValue) == .success,
              let focusedValue else { return .empty }
        let element = focusedValue as! AXUIElement

        if stringAttribute(kAXSubroleAttribute, of: element) == "AXSecureTextField" {
            return .empty
        }

        guard let value = stringAttribute(kAXValueAttribute, of: element),
              !value.isEmpty else { return .empty }

        let source = value as NSString
        guard let selectedRange = selectedTextRange(of: element),
              selectedRange.location >= 0,
              selectedRange.location <= source.length,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= source.length else {
            return FocusedTextContext(beforeCursor: String(value.suffix(maxCharacters)),
                                      afterCursor: "")
        }

        let beforeBudget = maxCharacters * 3 / 4
        let afterBudget = maxCharacters - beforeBudget
        let beforeStart = max(0, selectedRange.location - beforeBudget)
        let afterStart = selectedRange.location + selectedRange.length
        let afterLength = min(afterBudget, source.length - afterStart)

        let before = source.substring(with: NSRange(location: beforeStart,
                                                    length: selectedRange.location - beforeStart))
        let after = source.substring(with: NSRange(location: afterStart,
                                                   length: afterLength))
        return FocusedTextContext(beforeCursor: before, afterCursor: after)
    }

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

    private static func stringAttribute(_ attribute: String,
                                        of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private static func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,
                                            kAXSelectedTextRangeAttribute as CFString,
                                            &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
}
