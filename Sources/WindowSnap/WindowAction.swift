import AppKit
import Carbon.HIToolbox

/// A window management action, plus the math to compute its target frame.
/// All frames here are in Cocoa coordinates (origin at bottom-left of the
/// primary screen, y goes up) — conversion to AX coordinates happens in
/// `WindowManager`.
///
/// The action set and shortcuts mirror the user's Rectangle configuration
/// (~/Library/Preferences/com.knollsoft.Rectangle.plist), with one change:
/// the U/I/J/K quarters are replaced by a 2-row × 4-column grid on
/// U,I,O,P (top row) and J,K,L,; (bottom row).
enum WindowAction: String, CaseIterable {
    // 2×4 grid — the reason this app exists.
    case gridTop1, gridTop2, gridTop3, gridTop4
    case gridBottom1, gridBottom2, gridBottom3, gridBottom4
    // Halves
    case leftHalf, rightHalf, topHalf, bottomHalf
    // Column thirds
    case firstThird, centerThird, lastThird
    // Column fourths
    case firstFourth, secondFourth, thirdFourth, lastFourth
    case lastThreeFourths
    // Misc
    case maximize, center
    // Display moves (no fixed target frame — handled in WindowManager)
    case previousDisplay, nextDisplay

    /// Grouping shared by the status bar menu and the dashboard.
    static let sections: [(title: String, actions: [WindowAction])] = [
        ("2×4 Grid — Top", [.gridTop1, .gridTop2, .gridTop3, .gridTop4]),
        ("2×4 Grid — Bottom", [.gridBottom1, .gridBottom2, .gridBottom3, .gridBottom4]),
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Thirds", [.firstThird, .centerThird, .lastThird]),
        ("Fourths", [.firstFourth, .secondFourth, .thirdFourth, .lastFourth, .lastThreeFourths]),
        ("Window", [.maximize, .center]),
        ("Display", [.previousDisplay, .nextDisplay]),
    ]

    var title: String {
        switch self {
        case .gridTop1: return "Grid Top 1"
        case .gridTop2: return "Grid Top 2"
        case .gridTop3: return "Grid Top 3"
        case .gridTop4: return "Grid Top 4"
        case .gridBottom1: return "Grid Bottom 1"
        case .gridBottom2: return "Grid Bottom 2"
        case .gridBottom3: return "Grid Bottom 3"
        case .gridBottom4: return "Grid Bottom 4"
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .firstThird: return "First Third"
        case .centerThird: return "Center Third"
        case .lastThird: return "Last Third"
        case .firstFourth: return "First Fourth"
        case .secondFourth: return "Second Fourth"
        case .thirdFourth: return "Third Fourth"
        case .lastFourth: return "Last Fourth"
        case .lastThreeFourths: return "Last Three Fourths"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .previousDisplay: return "Previous Display"
        case .nextDisplay: return "Next Display"
        }
    }

    /// Default global shortcut. Everything is Ctrl+Opt, matching the
    /// Rectangle config.
    var defaultShortcut: Shortcut {
        let ctrlOpt = UInt32(controlKey | optionKey)
        let key: Int
        switch self {
        case .gridTop1: key = kVK_ANSI_U
        case .gridTop2: key = kVK_ANSI_I
        case .gridTop3: key = kVK_ANSI_O
        case .gridTop4: key = kVK_ANSI_P
        case .gridBottom1: key = kVK_ANSI_J
        case .gridBottom2: key = kVK_ANSI_K
        case .gridBottom3: key = kVK_ANSI_L
        case .gridBottom4: key = kVK_ANSI_Semicolon
        case .leftHalf: key = kVK_LeftArrow
        case .rightHalf: key = kVK_RightArrow
        case .topHalf: key = kVK_UpArrow
        case .bottomHalf: key = kVK_DownArrow
        case .firstThird: key = kVK_ANSI_A
        case .centerThird: key = kVK_ANSI_S
        case .lastThird: key = kVK_ANSI_D
        case .firstFourth: key = kVK_ANSI_Q
        case .secondFourth: key = kVK_ANSI_W
        case .thirdFourth: key = kVK_ANSI_E
        case .lastFourth: key = kVK_ANSI_R
        case .lastThreeFourths: key = kVK_ANSI_F
        case .maximize: key = kVK_Return
        case .center: key = kVK_ANSI_C
        case .previousDisplay: key = kVK_PageUp
        case .nextDisplay: key = kVK_PageDown
        }
        return Shortcut(keyCode: UInt32(key), modifiers: ctrlOpt)
    }

    /// Actions that move the window to another display rather than to a
    /// frame on the current one.
    var isDisplayMove: Bool {
        self == .previousDisplay || self == .nextDisplay
    }

    /// Computes the destination frame within a screen's visible frame
    /// (the area excluding the menu bar and the Dock).
    func targetFrame(visibleFrame v: CGRect, currentFrame: CGRect) -> CGRect {
        switch self {
        // 2×4 grid: rows counted from the top, columns from the left.
        case .gridTop1: return Self.cell(row: 0, of: 2, col: 0, of: 4, in: v)
        case .gridTop2: return Self.cell(row: 0, of: 2, col: 1, of: 4, in: v)
        case .gridTop3: return Self.cell(row: 0, of: 2, col: 2, of: 4, in: v)
        case .gridTop4: return Self.cell(row: 0, of: 2, col: 3, of: 4, in: v)
        case .gridBottom1: return Self.cell(row: 1, of: 2, col: 0, of: 4, in: v)
        case .gridBottom2: return Self.cell(row: 1, of: 2, col: 1, of: 4, in: v)
        case .gridBottom3: return Self.cell(row: 1, of: 2, col: 2, of: 4, in: v)
        case .gridBottom4: return Self.cell(row: 1, of: 2, col: 3, of: 4, in: v)

        case .leftHalf: return Self.cell(row: 0, of: 1, col: 0, of: 2, in: v)
        case .rightHalf: return Self.cell(row: 0, of: 1, col: 1, of: 2, in: v)
        case .topHalf: return Self.cell(row: 0, of: 2, col: 0, of: 1, in: v)
        case .bottomHalf: return Self.cell(row: 1, of: 2, col: 0, of: 1, in: v)

        case .firstThird: return Self.cell(row: 0, of: 1, col: 0, of: 3, in: v)
        case .centerThird: return Self.cell(row: 0, of: 1, col: 1, of: 3, in: v)
        case .lastThird: return Self.cell(row: 0, of: 1, col: 2, of: 3, in: v)

        case .firstFourth: return Self.cell(row: 0, of: 1, col: 0, of: 4, in: v)
        case .secondFourth: return Self.cell(row: 0, of: 1, col: 1, of: 4, in: v)
        case .thirdFourth: return Self.cell(row: 0, of: 1, col: 2, of: 4, in: v)
        case .lastFourth: return Self.cell(row: 0, of: 1, col: 3, of: 4, in: v)
        case .lastThreeFourths: return Self.cell(row: 0, of: 1, col: 1, of: 4, colSpan: 3, in: v)

        case .maximize:
            return v
        case .center:
            // Keep the window's size, just center it on the screen.
            let size = CGSize(width: min(currentFrame.width, v.width),
                              height: min(currentFrame.height, v.height))
            return CGRect(x: v.midX - size.width / 2,
                          y: v.midY - size.height / 2,
                          width: size.width,
                          height: size.height)
        case .previousDisplay, .nextDisplay:
            return currentFrame // handled by WindowManager
        }
    }

    /// Frame of a grid cell. Boundaries are computed proportionally and
    /// rounded so adjacent cells tile without gaps or overlaps even when
    /// the screen size doesn't divide evenly.
    private static func cell(row: Int, of rowCount: Int,
                             col: Int, of colCount: Int,
                             colSpan: Int = 1,
                             in v: CGRect) -> CGRect {
        let x0 = v.minX + (v.width * CGFloat(col) / CGFloat(colCount)).rounded()
        let x1 = v.minX + (v.width * CGFloat(col + colSpan) / CGFloat(colCount)).rounded()
        // Rows count from the top; Cocoa y goes up.
        let yTop = v.maxY - (v.height * CGFloat(row) / CGFloat(rowCount)).rounded()
        let yBottom = v.maxY - (v.height * CGFloat(row + 1) / CGFloat(rowCount)).rounded()
        return CGRect(x: x0, y: yBottom, width: x1 - x0, height: yTop - yBottom)
    }
}
