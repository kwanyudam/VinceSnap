import AppKit
import Carbon.HIToolbox

/// A window management action, plus the math to compute its target frame.
/// All frames here are in Cocoa coordinates (origin at bottom-left of the
/// primary screen, y goes up) — conversion to AX coordinates happens in
/// `WindowManager`.
enum WindowAction: CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
    case center

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeftQuarter: return "Top Left"
        case .topRightQuarter: return "Top Right"
        case .bottomLeftQuarter: return "Bottom Left"
        case .bottomRightQuarter: return "Bottom Right"
        case .maximize: return "Maximize"
        case .center: return "Center"
        }
    }

    /// Default global shortcut: Carbon key code + Carbon modifier flags.
    /// Defaults mirror Rectangle's (Ctrl+Opt + arrows / U-I-J-K / Return / C).
    var defaultShortcut: (keyCode: UInt32, modifiers: UInt32) {
        let ctrlOpt = UInt32(controlKey | optionKey)
        switch self {
        case .leftHalf: return (UInt32(kVK_LeftArrow), ctrlOpt)
        case .rightHalf: return (UInt32(kVK_RightArrow), ctrlOpt)
        case .topHalf: return (UInt32(kVK_UpArrow), ctrlOpt)
        case .bottomHalf: return (UInt32(kVK_DownArrow), ctrlOpt)
        case .topLeftQuarter: return (UInt32(kVK_ANSI_U), ctrlOpt)
        case .topRightQuarter: return (UInt32(kVK_ANSI_I), ctrlOpt)
        case .bottomLeftQuarter: return (UInt32(kVK_ANSI_J), ctrlOpt)
        case .bottomRightQuarter: return (UInt32(kVK_ANSI_K), ctrlOpt)
        case .maximize: return (UInt32(kVK_Return), ctrlOpt)
        case .center: return (UInt32(kVK_ANSI_C), ctrlOpt)
        }
    }

    /// Cosmetic key equivalent shown in the status bar menu.
    var menuKeyEquivalent: String {
        switch self {
        case .leftHalf: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case .rightHalf: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case .topHalf: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case .bottomHalf: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case .topLeftQuarter: return "u"
        case .topRightQuarter: return "i"
        case .bottomLeftQuarter: return "j"
        case .bottomRightQuarter: return "k"
        case .maximize: return "\r"
        case .center: return "c"
        }
    }

    /// Computes the destination frame within a screen's visible frame
    /// (the area excluding the menu bar and the Dock).
    func targetFrame(visibleFrame v: CGRect, currentFrame: CGRect) -> CGRect {
        let halfW = (v.width / 2).rounded(.down)
        let halfH = (v.height / 2).rounded(.down)
        // Note: Cocoa y goes up, so "top" rows start at v.minY + halfH.
        switch self {
        case .leftHalf:
            return CGRect(x: v.minX, y: v.minY, width: halfW, height: v.height)
        case .rightHalf:
            return CGRect(x: v.minX + halfW, y: v.minY, width: v.width - halfW, height: v.height)
        case .topHalf:
            return CGRect(x: v.minX, y: v.minY + halfH, width: v.width, height: v.height - halfH)
        case .bottomHalf:
            return CGRect(x: v.minX, y: v.minY, width: v.width, height: halfH)
        case .topLeftQuarter:
            return CGRect(x: v.minX, y: v.minY + halfH, width: halfW, height: v.height - halfH)
        case .topRightQuarter:
            return CGRect(x: v.minX + halfW, y: v.minY + halfH, width: v.width - halfW, height: v.height - halfH)
        case .bottomLeftQuarter:
            return CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
        case .bottomRightQuarter:
            return CGRect(x: v.minX + halfW, y: v.minY, width: v.width - halfW, height: halfH)
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
        }
    }
}
