import Foundation
import ServiceManagement

enum Settings {
    private static let defaults = UserDefaults.standard

    /// Gaussian blur radius in points.
    static var blurRadius: Double {
        get { defaults.object(forKey: "blurRadius") as? Double ?? 30 }
        set { defaults.set(newValue, forKey: "blurRadius") }
    }

    /// Seconds the head must stay on another screen before the blur moves.
    static var dwell: Double {
        get { defaults.object(forKey: "dwell") as? Double ?? 0.25 }
        set { defaults.set(newValue, forKey: "dwell") }
    }

    static var learnWhileTyping: Bool {
        get { defaults.object(forKey: "learnWhileTyping") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "learnWhileTyping") }
    }

    /// Lock the Mac and pause media when walking away with AirPods on.
    static var lockWhenWalkingAway: Bool {
        get { defaults.object(forKey: "lockWhenWalkingAway") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "lockWhenWalkingAway") }
    }

    static var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
