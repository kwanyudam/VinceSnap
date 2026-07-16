import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        setUpStatusItem()
        ShortcutManager.shared.registerAll()

        // Rebuild the menu when mappings change in the dashboard.
        NotificationCenter.default.addObserver(forName: .shortcutsChanged,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    // MARK: - Accessibility permission

    private func requestAccessibilityIfNeeded() {
        // Shows the system prompt pointing the user at
        // System Settings → Privacy & Security → Accessibility.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog("VinceSnap: waiting for Accessibility permission")
        }
    }

    // MARK: - Status bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1",
                                           accessibilityDescription: "VinceSnap")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let dashboardItem = NSMenuItem(title: "Dashboard…",
                                       action: #selector(openDashboard),
                                       keyEquivalent: ",")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        menu.addItem(.separator())

        for (index, section) in WindowAction.sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            let header = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for action in section.actions {
                let item = NSMenuItem(title: action.title,
                                      action: #selector(menuActionFired(_:)),
                                      keyEquivalent: "")
                if let shortcut = ShortcutManager.shared.shortcut(for: action) {
                    item.keyEquivalent = shortcut.menuKeyEquivalent
                    item.keyEquivalentModifierMask = shortcut.cocoaModifiers
                }
                item.target = self
                item.representedObject = action
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit VinceSnap",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func menuActionFired(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        WindowManager.perform(action)
    }

    @objc private func openDashboard() {
        DashboardWindowController.shared.show()
    }

}
