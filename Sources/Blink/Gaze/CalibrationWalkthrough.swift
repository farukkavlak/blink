import AppKit
import BlinkCore

/// Asks the user to face each screen in turn (left to right) and records the mean yaw.
/// The result is in the AirPods frame of the moment, so it can be anchored directly.
final class CalibrationWalkthrough {
    /// Seconds shown per screen; yaw is sampled during the final `samplingSeconds`.
    private let secondsPerScreen = 3
    private let samplingSeconds = 1

    private let screens = NSScreen.sortedLeftToRight
    private let hud = HUDWindow(size: NSSize(width: 560, height: 180), fontSize: 40)
    private let completion: ([ScreenID: Double]?) -> Void

    private var screenIndex = 0
    private var remaining = 0
    private var samples: [Double] = []
    private var result: [ScreenID: Double] = [:]
    private var timer: Timer?

    /// `completion` receives one target per screen, or nil if cancelled or no data arrived.
    init(completion: @escaping ([ScreenID: Double]?) -> Void) {
        self.completion = completion
    }

    func start() {
        beginScreen()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func cancel() {
        finish(with: nil)
    }

    func feed(yaw: Double) {
        if remaining <= samplingSeconds { samples.append(yaw) }
    }

    private func beginScreen() {
        remaining = secondsPerScreen
        samples = []
        showPrompt()
    }

    private func tick() {
        remaining -= 1
        guard remaining == 0 else {
            showPrompt()
            return
        }
        guard !samples.isEmpty else {
            Log.app.error("Calibration received no AirPods data")
            finish(with: nil)
            return
        }
        result[screens[screenIndex].screenID] = samples.reduce(0, +) / Double(samples.count)
        screenIndex += 1
        if screenIndex < screens.count { beginScreen() } else { finish(with: result) }
    }

    private func showPrompt() {
        hud.show(String(localized: "Look at the center of this screen\n\(remaining)"), on: screens[screenIndex])
    }

    private func finish(with targets: [ScreenID: Double]?) {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        hud.hide()
        completion(targets)
    }
}
