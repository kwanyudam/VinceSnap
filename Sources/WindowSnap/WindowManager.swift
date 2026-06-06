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

        let target = action.targetFrame(visibleFrame: visible, currentFrame: currentFrame)
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
