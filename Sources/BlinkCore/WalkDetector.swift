import Foundation

/// Detects walking from head motion: a run of regular steps (vertical acceleration peaks
/// every 0.3–1.2 s) while the head isn't rotating much.
///
/// Head-bobbing to music is rhythmic too, but it is a rotation about the neck. It is
/// rejected either by its rotation rate or because its bounce is no bigger than that
/// rotation could produce. A single stand-up spike and fidgeting never form a rhythm.
public final class WalkDetector {
    /// Minimum peak height of vertical acceleration, in g.
    public var peakThreshold = 0.08
    /// Consecutive regular peaks needed to call it walking…
    public var stepsNeeded = 7
    /// …of which at most this many may look like nods, so one odd peak doesn't restart the count.
    public var nodsAllowed = 2
    /// Any rotation faster than this (rad/s) around a peak means the head is nodding or turning.
    public var maxRotation = 1.0

    private let minStepInterval: TimeInterval = 0.3
    private let maxStepInterval: TimeInterval = 1.2
    /// Step intervals' standard deviation over mean; walking is regular.
    private let maxIrregularity = 0.35
    /// A nod's acceleration peaks at its turning point, exactly where rotation is ~0,
    /// so rotation is judged over a window around the peak.
    private let rotationWindow: TimeInterval = 0.6
    /// Distance from the neck pivot to the AirPods, in metres (generous, to favour "nod").
    private let neckRadius = 0.2
    private let smoothing = 0.4

    private var smoothed = 0.0
    private var previous = 0.0
    private var rising = false
    private var steps: [(time: TimeInterval, nodLike: Bool)] = []
    private var rotations: [(time: TimeInterval, rate: Double)] = []

    public init() {}

    public func reset() {
        smoothed = 0
        previous = 0
        rising = false
        steps = []
        rotations = []
    }

    /// - Parameters:
    ///   - verticalAcceleration: user acceleration along gravity, in g.
    ///   - rotationRate: magnitude of the head's rotation rate, in rad/s.
    /// - Returns: true when walking is detected (then starts counting afresh).
    public func feed(verticalAcceleration: Double, rotationRate: Double, time: TimeInterval) -> Bool {
        smoothed += (verticalAcceleration - smoothed) * smoothing
        rotations.append((time, rotationRate))
        rotations.removeAll { time - $0.time > rotationWindow }
        defer { previous = smoothed }

        // A peak is where the smoothed signal turns from rising to falling.
        let wasRising = rising
        rising = smoothed > previous
        guard wasRising, !rising, previous > peakThreshold else { return false }

        let peakRotation = rotations.map(\.rate).max() ?? 0
        guard peakRotation <= maxRotation else {
            steps = []
            return false
        }

        var nodLike = false
        if let last = steps.last?.time {
            let interval = time - last
            if interval < minStepInterval { return false } // same step, double bump
            if interval > maxStepInterval {
                steps = [] // rhythm broken, start over
            } else {
                nodLike = previous < 1.2 * nodAcceleration(rotationRate: peakRotation, period: interval)
            }
        }
        steps.append((time, nodLike))
        steps = Array(steps.suffix(stepsNeeded))
        guard steps.count == stepsNeeded, steps.filter(\.nodLike).count <= nodsAllowed, isRegular else {
            return false
        }
        steps = []
        return true
    }

    private var isRegular: Bool {
        let intervals = zip(steps, steps.dropFirst()).map { $1.time - $0.time }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
        return variance.squareRoot() / mean < maxIrregularity
    }

    /// Largest vertical acceleration (g) a nod could make: the head swinging about the neck
    /// at `rotationRate` with the given period. Walking moves the whole body, so its bounce
    /// is well above this; a nod's is at or below it.
    private func nodAcceleration(rotationRate: Double, period: TimeInterval) -> Double {
        rotationRate * (2 * .pi / period) * neckRadius / 9.81
    }
}
