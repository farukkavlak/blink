import CoreGraphics
import Foundation

/// System-wide actions and input timing. Locking and media control use private
/// frameworks, looked up at runtime so a missing symbol degrades instead of crashing.
enum SystemActions {
    private static let lockScreenSymbol = symbol(
        "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", "SACLockScreenImmediate")
    private static let sendMediaCommandSymbol = symbol(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", "MRMediaRemoteSendCommand")

    /// Seconds since the last keyboard or mouse event of any kind. Needs no permission.
    static func secondsSinceAnyInput() -> TimeInterval {
        let anyInput = CGEventType(rawValue: ~0)! // kCGAnyInputEventType
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    static func secondsSinceKeyPress() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    static func lockScreen() {
        guard let lockScreenSymbol else {
            // Sleeping the display locks when "require password immediately" is set.
            Log.app.error("SACLockScreenImmediate unavailable, falling back to display sleep")
            let pmset = Process()
            pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            pmset.arguments = ["displaysleepnow"]
            try? pmset.run()
            return
        }
        typealias LockScreen = @convention(c) () -> Int32
        _ = unsafeBitCast(lockScreenSymbol, to: LockScreen.self)()
    }

    /// Sends "pause" rather than "toggle", so nothing starts playing if it was already paused.
    static func pauseMedia() {
        guard let sendMediaCommandSymbol else {
            Log.app.error("MRMediaRemoteSendCommand unavailable, media not paused")
            return
        }
        typealias SendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool
        let pause: UInt32 = 1 // MRMediaRemoteCommand.pause
        _ = unsafeBitCast(sendMediaCommandSymbol, to: SendCommand.self)(pause, nil)
    }

    private static func symbol(_ path: String, _ name: String) -> UnsafeMutableRawPointer? {
        dlopen(path, RTLD_NOW).flatMap { dlsym($0, name) }
    }
}
