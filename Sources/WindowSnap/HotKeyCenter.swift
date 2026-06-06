import Carbon.HIToolbox

/// Minimal wrapper around Carbon's RegisterEventHotKey — still the only
/// supported API for system-wide hotkeys on macOS (Cocoa never got one).
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    /// "WSNP" as a FourCharCode, identifies our hotkeys system-wide.
    private static let signature: OSType = {
        var code: OSType = 0
        for char in "WSNP".utf16 { code = (code << 8) + OSType(char) }
        return code
    }()

    /// Registers a global hotkey. `keyCode`/`modifiers` are Carbon values
    /// (e.g. kVK_LeftArrow, controlKey | optionKey).
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            NSLog("WindowSnap: failed to register hotkey (keyCode \(keyCode)), status \(status)")
            return
        }
        handlers[nextID] = handler
        hotKeyRefs.append(hotKeyRef)
        nextID += 1
    }

    private func installEventHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        // The callback is a C function pointer, so it cannot capture state;
        // it reaches back in through the singleton.
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return status }
            HotKeyCenter.shared.handlers[hotKeyID.id]?()
            return noErr
        }, 1, &eventType, nil, nil)
        handlerInstalled = true
    }
}
