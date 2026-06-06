import Foundation
import AppKit

extension Notification.Name {
    /// Posted whenever any key mapping changes (menu and dashboard refresh).
    static let shortcutsChanged = Notification.Name("WindowSnap.shortcutsChanged")
}

/// Owns the action → shortcut mapping: persistence in UserDefaults,
/// registration with HotKeyCenter, and pausing while the dashboard
/// records a new combination.
///
/// UserDefaults format (per action, key "shortcut.<action>"):
///   missing       → use the action's default shortcut
///   empty dict    → explicitly unbound
///   {keyCode, modifiers} → custom shortcut
/// (Same idea as Rectangle's plist format.)
final class ShortcutManager {
    static let shared = ShortcutManager()

    private let defaults = UserDefaults.standard
    private var pausedForRecording = false

    private init() {}

    private func key(_ action: WindowAction) -> String { "shortcut.\(action.rawValue)" }

    // MARK: - Lookup / mutation

    func shortcut(for action: WindowAction) -> Shortcut? {
        guard let dict = defaults.dictionary(forKey: key(action)) else {
            return action.defaultShortcut
        }
        guard let keyCode = dict["keyCode"] as? Int,
              let modifiers = dict["modifiers"] as? Int
        else { return nil } // empty dict = unbound
        return Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
    }

    /// Assigns a shortcut (nil = unbind). If another action already uses
    /// the same combination, that action is unbound — last write wins.
    func set(_ shortcut: Shortcut?, for action: WindowAction) {
        if let shortcut {
            for other in WindowAction.allCases
            where other != action && self.shortcut(for: other) == shortcut {
                defaults.set([String: Int](), forKey: key(other))
            }
            defaults.set(["keyCode": Int(shortcut.keyCode),
                          "modifiers": Int(shortcut.modifiers)],
                         forKey: key(action))
        } else {
            defaults.set([String: Int](), forKey: key(action))
        }
        registerAll()
        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
    }

    func restoreDefaults() {
        for action in WindowAction.allCases {
            defaults.removeObject(forKey: key(action))
        }
        registerAll()
        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
    }

    // MARK: - Hotkey registration

    func registerAll() {
        HotKeyCenter.shared.unregisterAll()
        guard !pausedForRecording else { return }
        for action in WindowAction.allCases {
            guard let shortcut = shortcut(for: action) else { continue }
            HotKeyCenter.shared.register(keyCode: shortcut.keyCode,
                                         modifiers: shortcut.modifiers) {
                WindowManager.perform(action)
            }
        }
    }

    /// While recording, our own hotkeys must not swallow the keypress
    /// the user is trying to assign.
    func pauseForRecording() {
        pausedForRecording = true
        HotKeyCenter.shared.unregisterAll()
    }

    func resumeAfterRecording() {
        pausedForRecording = false
        registerAll()
    }
}
