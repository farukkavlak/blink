import AppKit
import BlinkCore

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    /// The display's UUID: stable across reboots and reconnects, unlike `displayID`.
    var screenID: ScreenID {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return "display-\(displayID)"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    static var sortedLeftToRight: [NSScreen] {
        screens.sorted { $0.frame.midX < $1.frame.midX }
    }

    static func withID(_ id: ScreenID) -> NSScreen? {
        screens.first { $0.screenID == id }
    }

    static func containingMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(location, $0.frame, false) }
    }
}
