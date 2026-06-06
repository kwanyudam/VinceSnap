import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        setUpStatusItem()
        registerHotKeys()
    }

    // MARK: - Accessibility permission

    private func requestAccessibilityIfNeeded() {
        // Shows the system prompt pointing the user at
        // System Settings → Privacy & Security → Accessibility.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog("WindowSnap: waiting for Accessibility permission")
        }
    }

    // MARK: - Status bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1",
                                           accessibilityDescription: "WindowSnap")

        let menu = NSMenu()
        for action in WindowAction.allCases {
            let item = NSMenuItem(title: action.title,
                                  action: #selector(menuActionFired(_:)),
                                  keyEquivalent: action.menuKeyEquivalent)
            item.keyEquivalentModifierMask = [.control, .option]
            item.target = self
            item.representedObject = action
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WindowSnap",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func menuActionFired(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        WindowManager.perform(action)
    }

    // MARK: - Hotkeys

    private func registerHotKeys() {
        for action in WindowAction.allCases {
            let shortcut = action.defaultShortcut
            HotKeyCenter.shared.register(keyCode: shortcut.keyCode,
                                         modifiers: shortcut.modifiers) {
                WindowManager.perform(action)
            }
        }
    }
}
