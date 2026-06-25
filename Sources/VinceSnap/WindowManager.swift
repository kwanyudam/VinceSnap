import AppKit
import ApplicationServices

/// Moves and resizes windows of other applications via the Accessibility API.
///
/// Coordinate systems:
/// - Cocoa (NSScreen): origin at the bottom-left of the primary screen, y up.
/// - Accessibility (AX): origin at the top-left of the primary screen, y down.
/// Frames are computed in Cocoa coordinates and converted on the way in/out.
enum WindowManager {

    /// Applies an action to the currently focused window of the frontmost app.
    static func perform(_ action: WindowAction) {
        guard let window = focusedWindow() else {
            NSSound.beep()
            return
        }
        guard let currentFrame = frame(of: window) else {
            NSSound.beep()
            return
        }
        let screen = screenContaining(currentFrame) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        if action.isDisplayMove {
            moveToAdjacentDisplay(window: window,
                                  currentFrame: currentFrame,
                                  currentScreen: screen,
                                  forward: action == .nextDisplay)
            return
        }

        let target = action.targetFrame(visibleFrame: visible, currentFrame: currentFrame)

        // Edge traversal: if a half action is pressed while the window already
        // fills that half, hop to the adjacent display (landing on the opposite
        // half there) instead of re-snapping to the same place — Rectangle-style.
        if let crossing = action.edgeCrossing,
           approxEqual(currentFrame, target),
           let screen,
           let dest = crossingScreen(from: screen, edge: crossing.toward) {
            let landing = crossing.landingHalf.targetFrame(visibleFrame: dest.visibleFrame,
                                                           currentFrame: currentFrame)
            setFrame(landing, of: window)
            return
        }

        setFrame(target, of: window)
    }

    /// Whether two frames coincide within a small tolerance. The window's
    /// stored frame can differ from the computed target by sub-pixel rounding
    /// (and AX rounds to integers), so an exact compare would miss matches.
    private static func approxEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    /// The display a window should hop to when traversing `edge`: the physically
    /// adjacent one if it exists, otherwise the display at the far opposite end
    /// so the screens rotate (pressing → off the rightmost wraps to the leftmost,
    /// and ← off the leftmost wraps to the rightmost). Returns nil only when
    /// there is no other display.
    private static func crossingScreen(from screen: NSScreen, edge: ScreenEdge) -> NSScreen? {
        if let adjacent = adjacentScreen(to: screen, edge: edge) { return adjacent }
        let others = NSScreen.screens.filter { $0 != screen }
        switch edge {
        case .left:  return others.max { $0.frame.maxX < $1.frame.maxX } // rightmost
        case .right: return others.min { $0.frame.minX < $1.frame.minX } // leftmost
        case .up:    return others.min { $0.frame.minY < $1.frame.minY } // bottom-most
        case .down:  return others.max { $0.frame.maxY < $1.frame.maxY } // top-most
        }
    }

    /// The display physically adjacent to `screen` in the given direction, or
    /// nil if there is none. Candidates must overlap on the perpendicular axis
    /// (so a screen diagonally offset doesn't count); the closest one wins.
    /// Frames are in Cocoa coordinates, so y increases upward.
    private static func adjacentScreen(to screen: NSScreen, edge: ScreenEdge) -> NSScreen? {
        let cur = screen.frame
        let others = NSScreen.screens.filter { $0 != screen }
        func vOverlap(_ f: CGRect) -> Bool { min(f.maxY, cur.maxY) - max(f.minY, cur.minY) > 0 }
        func hOverlap(_ f: CGRect) -> Bool { min(f.maxX, cur.maxX) - max(f.minX, cur.minX) > 0 }
        switch edge {
        case .left:
            return others.filter { $0.frame.maxX <= cur.minX + 1 && vOverlap($0.frame) }
                         .max { $0.frame.maxX < $1.frame.maxX }
        case .right:
            return others.filter { $0.frame.minX >= cur.maxX - 1 && vOverlap($0.frame) }
                         .min { $0.frame.minX < $1.frame.minX }
        case .up:
            return others.filter { $0.frame.minY >= cur.maxY - 1 && hOverlap($0.frame) }
                         .min { $0.frame.minY < $1.frame.minY }
        case .down:
            return others.filter { $0.frame.maxY <= cur.minY + 1 && hOverlap($0.frame) }
                         .max { $0.frame.maxY < $1.frame.maxY }
        }
    }

    /// Moves the window to the next/previous display, mapping its frame
    /// proportionally into the destination screen's visible area.
    private static func moveToAdjacentDisplay(window: AXUIElement,
                                              currentFrame: CGRect,
                                              currentScreen: NSScreen?,
                                              forward: Bool) {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let currentScreen,
              let index = screens.firstIndex(of: currentScreen)
        else {
            NSSound.beep()
            return
        }
        let offset = forward ? 1 : screens.count - 1
        let dest = screens[(index + offset) % screens.count].visibleFrame
        let src = currentScreen.visibleFrame

        let scaleX = dest.width / src.width
        let scaleY = dest.height / src.height
        let target = CGRect(x: dest.minX + (currentFrame.minX - src.minX) * scaleX,
                            y: dest.minY + (currentFrame.minY - src.minY) * scaleY,
                            width: currentFrame.width * scaleX,
                            height: currentFrame.height * scaleY)
        setFrame(target, of: window)
    }

    // MARK: - Focused window

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return (value as! AXUIElement)
    }

    // MARK: - Frame get/set

    /// Returns the window frame in Cocoa coordinates.
    private static func frame(of window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else { return nil }

        return axToCocoa(CGRect(origin: position, size: size))
    }

    /// Sets the window frame (given in Cocoa coordinates).
    private static func setFrame(_ cocoaFrame: CGRect, of window: AXUIElement) {
        let axFrame = cocoaToAX(cocoaFrame)
        var position = axFrame.origin
        var size = axFrame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }

        // Size → position → size: macOS clamps a window's size to the display
        // it is currently on, so when moving across displays the first resize
        // can be wrong until the window has been repositioned.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    // MARK: - Screen detection

    /// The screen with the largest overlap with the given frame.
    private static func screenContaining(_ cocoaFrame: CGRect) -> NSScreen? {
        NSScreen.screens
            .map { ($0, $0.frame.intersection(cocoaFrame)) }
            .filter { !$1.isNull }
            .max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }?
            .0
    }

    // MARK: - Coordinate conversion

    /// Height of the primary screen, used as the flipping axis.
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    /// The conversion is its own inverse: y' = primaryHeight - y - height.
    private static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    private static func axToCocoa(_ rect: CGRect) -> CGRect { flip(rect) }
    private static func cocoaToAX(_ rect: CGRect) -> CGRect { flip(rect) }
}
