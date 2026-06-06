import AppKit
import Carbon.HIToolbox

/// A key combination: Carbon key code + Carbon modifier flags.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// Builds a shortcut from a keyDown event; returns nil if no
    /// Ctrl/Opt/Cmd-style modifier is held (bare keys make bad hotkeys).
    init?(event: NSEvent) {
        var carbon: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon != 0, carbon != UInt32(shiftKey) else { return nil }
        self.keyCode = UInt32(event.keyCode)
        self.modifiers = carbon
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// e.g. "⌃⌥U", for display in the dashboard.
    var displayString: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + KeyCode.name(for: keyCode)
    }

    /// Cocoa modifier mask for NSMenuItem key equivalents.
    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// Key-equivalent string for NSMenuItem (cosmetic menu display).
    var menuKeyEquivalent: String { KeyCode.menuKeyEquivalent(for: keyCode) }
}

/// Key code → human-readable name / menu key equivalent.
enum KeyCode {
    /// ANSI (US) layout names for the printable keys, plus symbols for
    /// the common special keys.
    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦",
        118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    static func menuKeyEquivalent(for keyCode: UInt32) -> String {
        func fn(_ key: Int) -> String { String(UnicodeScalar(key)!) }
        switch Int(keyCode) {
        case kVK_LeftArrow: return fn(NSLeftArrowFunctionKey)
        case kVK_RightArrow: return fn(NSRightArrowFunctionKey)
        case kVK_UpArrow: return fn(NSUpArrowFunctionKey)
        case kVK_DownArrow: return fn(NSDownArrowFunctionKey)
        case kVK_PageUp: return fn(NSPageUpFunctionKey)
        case kVK_PageDown: return fn(NSPageDownFunctionKey)
        case kVK_Home: return fn(NSHomeFunctionKey)
        case kVK_End: return fn(NSEndFunctionKey)
        case kVK_ForwardDelete: return fn(NSDeleteFunctionKey)
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Space: return " "
        default:
            let name = names[keyCode] ?? ""
            return name.count == 1 ? name.lowercased() : ""
        }
    }
}
