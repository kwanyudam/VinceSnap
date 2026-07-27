# VinceSnap — guide for Claude sessions

A menu-bar macOS window manager (resize/position the focused window via
keyboard shortcuts, Rectangle-style). No Dock icon. ~800 lines of Swift,
no third-party dependencies.

## Build & run — read this first

**Do not use `swift build`.** This machine's Command Line Tools ship a
mismatched `PackageDescription` dylib, so SPM manifest loading fails with a
linker error (`Undefined symbols ... PackageDescription.Package`). That error
is environmental, not your code. `Package.swift` is kept only for a future
fixed toolchain.

Use the Makefile (it calls `swiftc` directly):

```sh
make build    # compile to build/VinceSnap (fast — use this to check it compiles)
make bundle   # wrap in VinceSnap.app + ad-hoc codesign
make run      # bundle + open the app
make clean
```

After editing any `Sources/VinceSnap/*.swift`, run `make build` to confirm it
compiles. To actually exercise behavior you must `make run` and try the
hotkeys on a real window — there are no unit tests and the logic is almost all
AppKit / Accessibility / Carbon side effects that can't be tested headlessly.

### Accessibility permission (the #1 friction point)

The app moves *other* apps' windows via the Accessibility API, so macOS
requires it under System Settings → Privacy & Security → Accessibility.

- Grant is keyed to the **code signature + bundle path**. The Makefile
  ad-hoc-signs (`codesign --force --sign -`) on every `bundle` so the grant
  stays stable across rebuilds — keep it that way.
- If hotkeys silently do nothing (or just beep), suspect a revoked/missing
  grant first. Toggle VinceSnap off/on in the Accessibility list, or remove
  and re-add it, then relaunch.
- A stale running copy is common: `pkill VinceSnap` before `make run` if a
  previous build is still resident.

## Architecture (one file = one responsibility)

```
main.swift          entry point; .accessory activation policy (no Dock icon)
AppDelegate.swift   status-bar menu, AX permission prompt, login-item toggle
WindowAction.swift  the action enum + all target-frame MATH  ← most edits here
WindowManager.swift AX focused-window lookup, frame get/set, screen detection
HotKeyCenter.swift  Carbon RegisterEventHotKey wrapper (singleton)
ShortcutManager.swift  action→shortcut mapping, UserDefaults persistence
Shortcut.swift      Shortcut struct + keyCode↔name/menu tables
Dashboard.swift     SwiftUI settings window + live shortcut recorder
```

Data flow for a keypress: Carbon hotkey fires → `HotKeyCenter` handler →
`WindowManager.perform(action)` → `WindowAction.targetFrame(...)` computes the
rect → `WindowManager.setFrame` writes it via AX.

## Things that will bite you

**Two coordinate systems.** Cocoa/`NSScreen` has origin bottom-left, y-up. The
Accessibility API has origin top-left, y-down. *All* frame math in
`WindowAction` is done in Cocoa coordinates against `screen.visibleFrame`
(which already excludes the menu bar and Dock). `WindowManager.flip()` converts
on the way in and out — it's its own inverse. If a window lands vertically
mirrored or offset by the menu-bar height, you're missing a flip or used
`frame` instead of `visibleFrame`.

**The size→position→size dance.** `WindowManager.setFrame` sets size, then
position, then size *again* on purpose. macOS clamps a window's size to the
display it currently sits on, so a single resize is wrong when moving across
displays. Don't "simplify" this to one set call.

**Carbon callback can't capture state.** `HotKeyCenter`'s `InstallEventHandler`
callback is a C function pointer — it reaches back through the
`HotKeyCenter.shared` singleton to find handlers. Hotkeys are keyed by an
incrementing `UInt32` id, signature `"WSNP"`.

**Hotkeys are global and exclusive.** Only one app can own a given
combo system-wide. Rectangle uses the same ⌃⌥ bindings — if it's running, the
two fight. The Dashboard recorder calls `pauseForRecording()` /
`resumeAfterRecording()` so VinceSnap's own hotkeys don't swallow the combo
being recorded.

## Adding or changing a window action

Everything is driven off the `WindowAction` enum, so the menu and dashboard
update automatically. To add an action, edit `WindowAction.swift` in five
places (the compiler's exhaustiveness checks will remind you of most):

1. add the `case` to the enum
2. add it to a group in `static let sections` (drives menu + dashboard order)
3. `title` switch — display name
4. `defaultShortcut` switch — default key (everything is ⌃⌥;
   `controlKey | optionKey`)
5. `targetFrame` switch — the geometry

Use the `cell(row:of:col:of:colSpan:in:)` helper for any grid-aligned frame; it
rounds boundaries proportionally so adjacent cells tile with no gaps/overlaps.
Rows count from the **top**. Examples already in the file:
- quarters = 2×2 grid (`row 0/1 of 2`, `col 0/1 of 2`)
- 2×4 grid = `of 2` rows × `of 4` cols
- halves/thirds/fourths = single row, N columns

The eight 2×4 grid keys don't use `targetFrame` at runtime — `WindowManager`
sees `gridCycle` is non-nil and steps the window through it on repeated
presses: full cell → left half → right half → left half → … (the halves are
2×8 cells). `nextInCycle` matches the *current* frame against the cycle, so
there's no timer or press counter; wrapping goes to index 1, not 0, which is
why the full cell is only reachable by pressing the key from somewhere else.
`targetFrame` still returns the full cell for these actions as the fallback.

Shortcut key codes come from `Carbon.HIToolbox` (`kVK_ANSI_T`, `kVK_LeftArrow`,
…). If you use a key code that isn't in `Shortcut.swift`'s `KeyCode.names` /
`menuKeyEquivalent` tables, the dashboard/menu will show "Key NN" — add it
there too.

Actions with no fixed frame (display moves) set `isDisplayMove` and are handled
specially in `WindowManager.perform`; their `targetFrame` just returns
`currentFrame`.

## Shortcut persistence (UserDefaults, per action)

Key `shortcut.<rawValue>`:
- **missing** → use `action.defaultShortcut`
- **empty dict** → explicitly unbound
- `{keyCode, modifiers}` → custom

So a brand-new action gets its default automatically (no migration needed), and
"Restore Defaults" just removes the keys. Reassigning a combo already in use
unbinds the previous owner (last-write-wins, in `ShortcutManager.set`).

## Conventions

- Match the existing terse, explanatory comment style — comments say *why*
  (the gotcha), not *what*.
- Pure AppKit/SwiftUI/Carbon, no dependencies. Keep it that way unless asked.
- `NSSound.beep()` is the standard "couldn't do it" feedback (no focused
  window, single display for a display-move, etc.).
- App is `LSUIElement` (menu-bar only); user-facing UI is the status menu and
  the SwiftUI Dashboard.
