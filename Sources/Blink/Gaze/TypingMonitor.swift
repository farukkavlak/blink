import AppKit
import BlinkCore

/// Tells which screen the user is typing into right now, from the time since the last
/// key press and the focused window's position. Neither needs a permission prompt.
final class TypingMonitor {
    /// A key press within this many seconds counts as "typing".
    private let typingWindow: TimeInterval = 1
    /// Window lookups are comparatively expensive; motion samples arrive at ~25 Hz.
    private let lookupInterval: TimeInterval = 0.5

    private var cachedScreen: ScreenID?
    private var lastLookup: TimeInterval = -.infinity

    func typingScreen(at time: TimeInterval) -> ScreenID? {
        guard SystemActions.secondsSinceKeyPress() < typingWindow else {
            cachedScreen = nil
            return nil
        }
        if cachedScreen == nil || time - lastLookup > lookupInterval {
            cachedScreen = Self.focusedWindowScreen()?.screenID
            lastLookup = time
        }
        return cachedScreen
    }

    private static func focusedWindowScreen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        // The list is ordered front to back.
        let frontmost = windows.first {
            $0[kCGWindowOwnerPID as String] as? pid_t == pid && $0[kCGWindowLayer as String] as? Int == 0
        }
        guard let boundsDict = frontmost?[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else { return nil }
        // Window bounds are in global display coordinates (top-left origin), like CGDisplayBounds.
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return NSScreen.screens.first { CGDisplayBounds($0.displayID).contains(center) }
    }
}
