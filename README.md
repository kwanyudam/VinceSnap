# VinceSnap

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
make run      # builds, wraps in VinceSnap.app, signs ad-hoc, launches
```

On first launch macOS will prompt for **Accessibility** permission:
System Settings → Privacy & Security → Accessibility → enable VinceSnap.
(Re-launch after granting.)

The Makefile compiles with `swiftc` directly. A `Package.swift` is also
included for `swift build` / Xcode, but note: some Command Line Tools
installs ship a mismatched PackageDescription dylib that breaks SPM manifest
loading — the swiftc path always works.

## Shortcuts (all ⌃⌥, mirroring the user's Rectangle config)

### 2×4 grid (2 rows × 4 columns — the headline feature)

```
┌─────┬─────┬─────┬─────┐
│  U  │  I  │  O  │  P  │   top row
├─────┼─────┼─────┼─────┤
│  J  │  K  │  L  │  ;  │   bottom row
└─────┴─────┴─────┴─────┘
```

Each cell is ¼ screen width × ½ screen height. Cell boundaries are computed
proportionally and rounded so adjacent cells tile exactly.

### Carried over from Rectangle

| Action             | Shortcut    |
| ------------------ | ----------- |
| Left / Right Half  | ⌃⌥ ← / →    |
| Top / Bottom Half  | ⌃⌥ ↑ / ↓    |
| First/Center/Last Third (columns)  | ⌃⌥ A / S / D |
| First…Last Fourth (columns)        | ⌃⌥ Q / W / E / R |
| Last Three Fourths | ⌃⌥ F        |
| Maximize           | ⌃⌥ Return   |
| Center             | ⌃⌥ C        |
| Previous / Next Display | ⌃⌥ PageUp / PageDown |

Launch at Login is available as a menu bar toggle (Rectangle had
`launchOnLogin = 1`).

> **Note:** Rectangle binds ⌃⌥ U/I/J/K (quarters) and all of the above —
> quit Rectangle (or clear its shortcuts) before running VinceSnap, or the
> two apps will fight over the same hotkeys.

## Project layout

```
Sources/VinceSnap/
  main.swift          app entry point (accessory activation policy)
  AppDelegate.swift   status bar menu, permission prompt, hotkey wiring
  WindowAction.swift  the action enum + target-frame math
  WindowManager.swift AX focused-window lookup, frame get/set, screen detection
  HotKeyCenter.swift  Carbon RegisterEventHotKey wrapper
Resources/Info.plist  bundle metadata (LSUIElement = menu bar only)
Makefile              build → .app bundle → ad-hoc sign
```

## Ideas / next steps

- [ ] Repeated press cycles sizes (Rectangle's `subsequentExecutionMode = 1`)
- [ ] Hide menu bar icon option (Rectangle had `hideMenubarIcon = 1`)
- [ ] Restore previous frame (undo)
- [ ] Drag-to-edge snapping (mouse event monitoring + overlay footprint)
- [ ] User-configurable shortcuts (persist in UserDefaults)

Inspired by [Rectangle](https://github.com/rxhanson/rectangle).
