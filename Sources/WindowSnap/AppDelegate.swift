import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var launchAtLoginItem: NSMenuItem!

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

    private static let menuSections: [(title: String, actions: [WindowAction])] = [
        ("2×4 Grid — Top", [.gridTop1, .gridTop2, .gridTop3, .gridTop4]),
        ("2×4 Grid — Bottom", [.gridBottom1, .gridBottom2, .gridBottom3, .gridBottom4]),
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Thirds", [.firstThird, .centerThird, .lastThird]),
        ("Fourths", [.firstFourth, .secondFourth, .thirdFourth, .lastFourth, .lastThreeFourths]),
        ("Window", [.maximize, .center]),
        ("Display", [.previousDisplay, .nextDisplay]),
    ]

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1",
                                           accessibilityDescription: "WindowSnap")

        let menu = NSMenu()
        menu.delegate = self
        for (index, section) in Self.menuSections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            let header = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for action in section.actions {
                let item = NSMenuItem(title: action.title,
                                      action: #selector(menuActionFired(_:)),
                                      keyEquivalent: action.menuKeyEquivalent)
                item.keyEquivalentModifierMask = [.control, .option]
                item.target = self
                item.representedObject = action
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        launchAtLoginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(NSMenuItem(title: "Quit WindowSnap",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func menuActionFired(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? WindowAction else { return }
        WindowManager.perform(action)
    }

    // MARK: - Launch at login

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("WindowSnap: launch-at-login toggle failed: \(error)")
        }
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
