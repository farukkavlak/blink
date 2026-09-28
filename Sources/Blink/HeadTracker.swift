import BlinkCore
import CoreMotion

/// One motion reading from the AirPods, reduced to what the features need.
struct HeadSample {
    let time: TimeInterval
    /// Smoothed head yaw in degrees. Its origin is arbitrary and resets on every reconnect,
    /// so only relative angles are meaningful.
    let yaw: Double
    /// User acceleration along gravity (up is positive), in g.
    let verticalAcceleration: Double
    /// Magnitude of the rotation rate, in rad/s.
    let rotationRate: Double
}

/// Streams head motion from AirPods via CMHeadphoneMotionManager (supported models: see README).
final class HeadTracker: NSObject, CMHeadphoneMotionManagerDelegate {
    var onSample: ((HeadSample) -> Void)?
    var onConnectionChange: ((_ connected: Bool) -> Void)?
    private(set) var isConnected = false

    private let manager = CMHeadphoneMotionManager()
    private let yawFilter = OneEuroFilter()

    func start() {
        manager.delegate = self
        guard manager.isDeviceMotionAvailable else {
            Log.app.error("Headphone motion is not available on this Mac")
            return
        }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error { Log.app.error("Headphone motion error: \(error.localizedDescription)") }
            guard let self, let motion else { return }
            self.setConnected(true)
            self.onSample?(self.sample(from: motion))
        }
    }

    private func sample(from motion: CMDeviceMotion) -> HeadSample {
        let a = motion.userAcceleration, g = motion.gravity, r = motion.rotationRate
        // Gravity is ~1 g long and points down, so the negated dot product is the upward component.
        let vertical = -(a.x * g.x + a.y * g.y + a.z * g.z)
        return HeadSample(
            time: motion.timestamp,
            yaw: yawFilter.filter(motion.attitude.yaw * 180 / .pi, time: motion.timestamp),
            verticalAcceleration: vertical,
            rotationRate: (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
        )
    }

    private func setConnected(_ connected: Bool) {
        guard connected != isConnected else { return }
        isConnected = connected
        yawFilter.reset()
        onConnectionChange?(connected)
    }

    // Delegate callbacks arrive on an arbitrary queue.

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.setConnected(true) }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async { self.setConnected(false) }
    }
}
