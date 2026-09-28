import AppKit
import BlinkCore

/// Screen yaw targets per desk setup. Home and office have different displays, so each
/// combination of connected displays gets its own entry.
enum CalibrationStore {
    /// Used before anything is calibrated or learned: ~35° between neighbouring screens,
    /// rightward screens at lower yaw (CoreMotion yaw grows counter-clockwise).
    static let guessedSpacing = -35.0

    private static var currentSetupKey: String {
        "calibration." + NSScreen.screens.map(\.screenID).sorted().joined(separator: "+")
    }

    static func load() -> [ScreenID: Double]? {
        guard let saved = UserDefaults.standard.dictionary(forKey: currentSetupKey) as? [ScreenID: Double],
              Set(saved.keys) == Set(NSScreen.screens.map(\.screenID))
        else { return nil }
        return saved
    }

    static func save(_ targets: [ScreenID: Double]) {
        UserDefaults.standard.set(targets, forKey: currentSetupKey)
    }

    static func guess() -> [ScreenID: Double] {
        Dictionary(uniqueKeysWithValues: NSScreen.sortedLeftToRight.enumerated().map { index, screen in
            (screen.screenID, Double(index) * guessedSpacing)
        })
    }
}
