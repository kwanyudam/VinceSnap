import AppKit
import ApplicationServices
#if compiler(>=5.7)
import ServiceManagement
#endif

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    #if compiler(>=5.7)
    private var launchAtLoginItem: NSMenuItem!
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityIfNeeded()
        #if compiler(>=5.7)
        enableLaunchAtLoginOnce()
        #endif
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
        #if compiler(>=5.7)
        launchAtLoginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        #endif
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

    // MARK: - Launch at login
    //
    // SMAppService needs the macOS 13 SDK (Xcode 14 / Swift 5.7+); older
    // toolchains don't declare it at all, so this whole feature is compiled
    // out rather than gated with `@available`, which only affects runtime
    // checks, not symbol resolution at compile time.
    #if compiler(>=5.7)

    /// Registers as a login item on first launch only, so turning it off
    /// later via the menu toggle sticks across launches.
    private func enableLaunchAtLoginOnce() {
        let key = "didConfigureLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        do {
            try SMAppService.mainApp.register()
            NSLog("VinceSnap: registered as login item")
        } catch {
            NSLog("VinceSnap: login item registration failed: \(error)")
        }
    }

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
            NSLog("VinceSnap: launch-at-login toggle failed: \(error)")
        }
    }
    #endif
}
