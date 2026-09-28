import BlinkCore
import Foundation

/// The walk-away feature: when the user walks off wearing AirPods, pause media and lock
/// the Mac after a short, cancellable countdown.
final class WalkAwayLock {
    /// Return true to ignore motion for now (e.g. during calibration).
    var isSuspended: () -> Bool = { false }

    /// Keyboard or mouse used this recently means the user is at the desk, whatever the motion says.
    private let recentInputWindow: TimeInterval = 3
    private let countdownSeconds = 3
    private let cooldown: TimeInterval = 60

    private let detector = WalkDetector()
    private var countdown: LockCountdown?
    private var lastTrigger: TimeInterval = -.infinity

    func handle(_ sample: HeadSample) {
        guard Settings.lockWhenWalkingAway, !isSuspended() else { return }
        let walking = detector.feed(verticalAcceleration: sample.verticalAcceleration,
                                    rotationRate: sample.rotationRate, time: sample.time)
        guard walking, countdown == nil, sample.time - lastTrigger > cooldown,
              SystemActions.secondsSinceAnyInput() > recentInputWindow
        else { return }

        lastTrigger = sample.time
        Log.app.info("Walking detected, starting lock countdown")
        countdown = LockCountdown(seconds: countdownSeconds) { [weak self] cancelled in
            self?.countdown = nil
            guard !cancelled else { return }
            SystemActions.pauseMedia()
            SystemActions.lockScreen()
        }
    }

    func reset() {
        detector.reset()
    }
}
