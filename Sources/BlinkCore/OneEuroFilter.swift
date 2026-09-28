import Foundation

/// 1€ filter (Casiez et al. 2012) for an angle in degrees: smooths jitter when the head
/// is still while staying responsive when it turns. Unwraps ±180° crossings so the
/// output is continuous.
public final class OneEuroFilter {
    private let minCutoff: Double
    private let beta: Double
    private let derivativeCutoff = 1.0

    private var lastValue: Double?
    private var lastDerivative = 0.0
    private var lastTime: TimeInterval?
    private var lastRaw: Double?
    private var unwrapOffset = 0.0

    /// - Parameters:
    ///   - minCutoff: Hz; lower smooths more at rest.
    ///   - beta: how quickly smoothing relaxes as speed rises.
    public init(minCutoff: Double = 1.0, beta: Double = 0.02) {
        self.minCutoff = minCutoff
        self.beta = beta
    }

    public func reset() {
        lastValue = nil
        lastDerivative = 0
        lastTime = nil
        lastRaw = nil
        unwrapOffset = 0
    }

    public func filter(_ angle: Double, time: TimeInterval) -> Double {
        if let lastRaw {
            let jump = angle - lastRaw
            if jump > 180 { unwrapOffset -= 360 } else if jump < -180 { unwrapOffset += 360 }
        }
        lastRaw = angle
        let x = angle + unwrapOffset

        guard let previous = lastValue, let previousTime = lastTime, time > previousTime else {
            lastValue = x
            lastTime = time
            return x
        }
        let dt = time - previousTime
        let derivative = lastDerivative + alpha(cutoff: derivativeCutoff, dt: dt) * ((x - previous) / dt - lastDerivative)
        let cutoff = minCutoff + beta * abs(derivative)
        let value = previous + alpha(cutoff: cutoff, dt: dt) * (x - previous)

        lastValue = value
        lastDerivative = derivative
        lastTime = time
        return value
    }

    private func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * .pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}
