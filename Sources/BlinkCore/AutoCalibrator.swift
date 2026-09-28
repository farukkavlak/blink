import Foundation

/// Learns where each screen is from typing: while you type into a window you are almost
/// always looking at it. Each uninterrupted stretch of typing with a still head becomes a
/// `Burst` (screen + median yaw). A burst is immediate evidence for drift correction;
/// once every screen has a few, they give the angles between screens.
public final class AutoCalibrator {
    public struct Burst {
        public let screen: ScreenID
        public let yaw: Double
        public let time: TimeInterval
    }

    private let minDuration: TimeInterval = 1
    private let minSamples = 10
    /// Middle 80% of a burst's yaw must fit in this many degrees, or the head was moving.
    private let maxSpread = 10.0
    private let burstsPerScreen = 3
    private let memory: TimeInterval = 15 * 60

    /// Learned angles further than this from an existing calibration are treated as bad data.
    private let maxDisagreement = 25.0
    /// Fraction of the way an existing calibration moves toward learned angles per burst.
    private let refinementRate = 0.3
    /// Screens closer together than this can't be told apart by head yaw.
    private let minSeparation = 10.0

    private var bursts: [Burst] = []
    private var current: (screen: ScreenID, yaws: [Double], start: TimeInterval, end: TimeInterval)?

    public init() {}

    /// Bursts are in the raw AirPods frame, which resets on reconnect; drop them then.
    public func reset() {
        bursts = []
        current = nil
    }

    /// Feed every yaw sample; `typingScreen` is non-nil while the user is typing.
    /// Returns a burst when one completes.
    public func feed(rawYaw: Double, typingScreen: ScreenID?, time: TimeInterval) -> Burst? {
        guard let typingScreen else { return closeBurst() }
        guard current?.screen == typingScreen else {
            let finished = closeBurst()
            current = (typingScreen, [rawYaw], time, time)
            return finished
        }
        current?.yaws.append(rawYaw)
        current?.end = time
        return nil
    }

    private func closeBurst() -> Burst? {
        guard let burst = current else { return nil }
        current = nil
        let sorted = burst.yaws.sorted()
        guard sorted.count >= minSamples, burst.end - burst.start >= minDuration,
              sorted[sorted.count * 9 / 10] - sorted[sorted.count / 10] <= maxSpread
        else { return nil }

        let result = Burst(screen: burst.screen, yaw: sorted[sorted.count / 2], time: burst.end)
        bursts.append(result)
        bursts.removeAll { result.time - $0.time > memory }
        return result
    }

    /// Median yaw per screen relative to the first screen, once every screen has enough bursts.
    public func learnedTargets(screens: [ScreenID]) -> [ScreenID: Double]? {
        var medians: [ScreenID: Double] = [:]
        for screen in screens {
            let yaws = bursts.filter { $0.screen == screen }.map(\.yaw).sorted()
            guard yaws.count >= burstsPerScreen else { return nil }
            medians[screen] = yaws[yaws.count / 2]
        }
        guard let reference = screens.first.flatMap({ medians[$0] }) else { return nil }
        return medians.mapValues { $0 - reference }
    }

    /// New targets for `screens` (ordered left to right) given what typing has taught so far,
    /// or nil to keep `current`. Without a calibration the learned angles are used as is;
    /// with one they refine it gradually, and data that contradicts it is ignored.
    public func proposedTargets(screens: [ScreenID], current: [ScreenID: Double],
                                isCalibrated: Bool) -> [ScreenID: Double]? {
        guard screens.count > 1, let learned = learnedTargets(screens: screens),
              let reference = current[screens[0]] else { return nil }
        let relative = current.mapValues { $0 - reference }

        var proposed = learned
        if isCalibrated {
            guard screens.allSatisfy({ abs(learned[$0]! - (relative[$0] ?? .infinity)) < maxDisagreement })
            else { return nil }
            proposed = relative.merging(learned) { old, new in old + (new - old) * refinementRate }
        }
        let sorted = proposed.values.sorted()
        guard zip(sorted, sorted.dropFirst()).allSatisfy({ $1 - $0 >= minSeparation }) else { return nil }
        return proposed
    }
}
