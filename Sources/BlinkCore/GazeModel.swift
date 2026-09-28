import Foundation

/// Decides which screen the user faces from head yaw.
///
/// `targets` hold each screen's yaw in an arbitrary frame (from calibration or learning).
/// The AirPods yaw origin is arbitrary too and resets on every reconnect, so `offset`
/// maps the live frame onto the target frame. It is set by anchoring ("the user faces
/// this screen now") and then kept aligned by typing evidence and by slow drift
/// correction whenever the head rests near a target.
public final class GazeModel {
    /// Degrees the head must pass beyond the midpoint between two screens before switching.
    public var hysteresis = 4.0
    /// Seconds the new screen must stay nearest before switching.
    public var dwell = 0.25

    /// Replacing targets invalidates the current decision; anchor again afterwards.
    public var targets: [ScreenID: Double] = [:] {
        didSet { active = nil }
    }
    public private(set) var active: ScreenID?
    public var isAnchored: Bool { offset != nil }

    private var offset: Double?
    private var candidate: ScreenID?
    private var candidateSince: TimeInterval = 0
    private var typingMismatches = 0

    /// Raw yaw over the last `stillWindow` seconds, to tell a resting head from a moving one.
    private var recent: [(time: TimeInterval, yaw: Double)] = []
    private let stillWindow = 1.5
    private let stillSpread = 3.0
    private let driftCaptureRange = 12.0
    private let driftRate = 0.01

    /// Typing evidence within this many degrees corrects the offset; beyond it counts as a mismatch.
    private let typingTrustRange = 15.0
    private let typingMismatchesToReanchor = 2

    public init() {}

    /// Forgets the live-frame alignment, e.g. after the AirPods reconnect.
    public func resetAnchor() {
        offset = nil
        active = nil
        candidate = nil
        recent = []
        typingMismatches = 0
    }

    /// Declares that the user is facing `screen` right now.
    public func anchor(to screen: ScreenID, rawYaw: Double) {
        guard let target = targets[screen] else { return }
        offset = target - rawYaw
        active = screen
        candidate = nil
    }

    /// Typing into `screen` while the head rested at `rawYaw` is strong evidence the user
    /// faces it: correct the offset firmly, and re-anchor if it disagrees repeatedly.
    public func observeTyping(screen: ScreenID, rawYaw: Double) {
        guard let target = targets[screen] else { return }
        guard let offset else {
            anchor(to: screen, rawYaw: rawYaw)
            return
        }
        let error = target - (rawYaw + offset)
        if abs(error) < typingTrustRange {
            self.offset = offset + error * 0.5
            typingMismatches = 0
        } else {
            typingMismatches += 1
            if typingMismatches >= typingMismatchesToReanchor {
                anchor(to: screen, rawYaw: rawYaw)
                typingMismatches = 0
            }
        }
    }

    /// Processes one yaw sample and returns the screen the user faces, if anchored.
    @discardableResult
    public func update(rawYaw: Double, time: TimeInterval) -> ScreenID? {
        guard let offset, let nearest = nearestScreen(to: rawYaw + offset) else { return nil }
        let yaw = rawYaw + offset
        let current = active ?? nearest
        active = current

        if nearest != current, let a = targets[current], let b = targets[nearest],
           abs(a - yaw) - abs(b - yaw) > 2 * hysteresis {
            if candidate != nearest {
                candidate = nearest
                candidateSince = time
            } else if time - candidateSince >= dwell {
                active = nearest
                candidate = nil
            }
        } else {
            candidate = nil
        }

        correctDrift(rawYaw: rawYaw, offset: offset, time: time)
        return active
    }

    private func nearestScreen(to yaw: Double) -> ScreenID? {
        targets.min { abs($0.value - yaw) < abs($1.value - yaw) }?.key
    }

    /// When the head has rested for a moment close to the active screen's target, nudge
    /// the offset so that resting pose maps onto the target. Stillness is judged by the
    /// spread over a window, not sample-to-sample speed, which sensor jitter inflates.
    private func correctDrift(rawYaw: Double, offset: Double, time: TimeInterval) {
        recent.append((time, rawYaw))
        recent.removeAll { time - $0.time > stillWindow }
        guard let first = recent.first, time - first.time > stillWindow * 0.9,
              let low = recent.map(\.yaw).min(), let high = recent.map(\.yaw).max(), high - low < stillSpread,
              let active, let target = targets[active]
        else { return }
        let error = target - (rawYaw + offset)
        guard abs(error) < driftCaptureRange else { return }
        self.offset = offset + error * driftRate
    }
}
