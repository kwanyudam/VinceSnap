# WindowSnap

A minimal macOS window manager — resize and position windows with keyboard
shortcuts, Rectangle-style. Lives in the menu bar, no Dock icon.

## How it works

- Uses the **Accessibility API** (`AXUIElement`) to read and set the position
  and size of the focused window of the frontmost app.
- Global hotkeys are registered through Carbon's `RegisterEventHotKey` (the
  only system-wide hotkey API on macOS).
- Window frames are computed in Cocoa coordinates (bottom-left origin) against
  the screen's `visibleFrame` (excludes menu bar and Dock), then flipped to
  AX coordinates (top-left origin).

## Build & run

```sh
make run      # builds, wraps in WindowSnap.app, signs ad-hoc, launches
```

On first launch macOS will prompt for **Accessibility** permission:
System Settings → Privacy & Security → Accessibility → enable WindowSnap.
(Re-launch after granting.)

The Makefile compiles with `swiftc` directly. A `Package.swift` is also
included for `swift build` / Xcode, but note: some Command Line Tools
installs ship a mismatched PackageDescription dylib that breaks SPM manifest
loading — the swiftc path always works.

## Shortcuts (defaults, Rectangle-compatible)

| Action       | Shortcut       |
| ------------ | -------------- |
| Left Half    | ⌃⌥ ←           |
| Right Half   | ⌃⌥ →           |
| Top Half     | ⌃⌥ ↑           |
| Bottom Half  | ⌃⌥ ↓           |
| Top Left     | ⌃⌥ U           |
| Top Right    | ⌃⌥ I           |
| Bottom Left  | ⌃⌥ J           |
| Bottom Right | ⌃⌥ K           |
| Maximize     | ⌃⌥ Return      |
| Center       | ⌃⌥ C           |

## Project layout

```
Sources/WindowSnap/
  main.swift          app entry point (accessory activation policy)
  AppDelegate.swift   status bar menu, permission prompt, hotkey wiring
  WindowAction.swift  the action enum + target-frame math
  WindowManager.swift AX focused-window lookup, frame get/set, screen detection
  HotKeyCenter.swift  Carbon RegisterEventHotKey wrapper
Resources/Info.plist  bundle metadata (LSUIElement = menu bar only)
Makefile              build → .app bundle → ad-hoc sign
```

## Ideas / next steps

- [ ] Thirds / two-thirds layouts and "repeated press cycles sizes"
- [ ] Move window to next display
- [ ] Restore previous frame (undo)
- [ ] Drag-to-edge snapping (mouse event monitoring + overlay footprint)
- [ ] User-configurable shortcuts (persist in UserDefaults)
- [ ] Launch at login

Inspired by [Rectangle](https://github.com/rxhanson/rectangle).
