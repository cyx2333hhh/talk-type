import Carbon.HIToolbox

/// Registers a single global hotkey using Carbon's RegisterEventHotKey. This
/// works system-wide without Accessibility permission, which makes it the most
/// reliable way to trigger dictation from any app.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x4D524D52 /* 'MRMR' */, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRef = ref }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, _ -> OSStatus in
            HotKeyManager.shared.onTrigger?()
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handlerRef)
    }
}
