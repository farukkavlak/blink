import AppKit
import BlinkCore

/// The blur feature: turns head yaw into "which screen is faced", keeps screen positions
/// learned and aligned, and blurs every other screen.
///
/// Until the layout is known (calibrated or learned) *and* the alignment is confirmed
/// (by typing, recentering or calibrating), blur stays a light haze: a wrong guess must
/// never hide the screen the user is actually looking at.
final class GazeBlurController {
    enum Status {
        case disconnected
        case waiting
        case facing(NSScreen)
    }

    /// Called whenever something shown in the menu changes.
    var onChange: (() -> Void)?

    var isEnabled = true {
        didSet {
            applyBlur()
            onChange?()
        }
    }

    private(set) var isConnected = false
    private(set) var isCalibrated = false
    private(set) var isConfirmed = false
    var isCalibrating: Bool { walkthrough != nil }
    /// Full-strength blur is in effect (vs. the light haze while unsure).
    var isCertain: Bool { isCalibrated && isConfirmed }

    var status: Status {
        guard isConnected else { return .disconnected }
        guard let active = model.active, let screen = NSScreen.withID(active) else { return .waiting }
        return .facing(screen)
    }

    private let hazeRadius = 4.0

    private let model = GazeModel()
    private let learner = AutoCalibrator()
    private let overlay = BlurOverlay()
    private let typing = TypingMonitor()
    private var walkthrough: CalibrationWalkthrough?
    private var lastYaw: Double?

    init() {
        model.dwell = Settings.dwell
        reloadScreens()
    }

    // MARK: - Inputs

    func handle(_ sample: HeadSample) {
        lastYaw = sample.yaw
        if let walkthrough {
            walkthrough.feed(yaw: sample.yaw)
            return
        }

        let typingScreen = typing.typingScreen(at: sample.time)
        if let burst = learner.feed(rawYaw: sample.yaw, typingScreen: typingScreen, time: sample.time) {
            model.observeTyping(screen: burst.screen, rawYaw: burst.yaw)
            isConfirmed = true
            if Settings.learnWhileTyping { learn(from: burst) }
            onChange?()
        }

        if !model.isAnchored, let screen = NSScreen.containingMouse() ?? NSScreen.main {
            // Best available guess; blur stays light until confirmed.
            model.anchor(to: screen.screenID, rawYaw: sample.yaw)
        }
        let previous = model.active
        model.update(rawYaw: sample.yaw, time: sample.time)
        applyBlur()
        if model.active != previous { onChange?() }
    }

    func connectionChanged(_ connected: Bool) {
        isConnected = connected
        resetAlignment() // the AirPods yaw origin resets on reconnect
        applyBlur()
        onChange?()
    }

    /// Call when displays are added, removed or rearranged.
    func reloadScreens() {
        walkthrough?.cancel()
        overlay.rebuild()
        if let saved = CalibrationStore.load() {
            model.targets = saved
            isCalibrated = true
        } else {
            model.targets = CalibrationStore.guess()
            isCalibrated = false
        }
        resetAlignment()
        onChange?()
    }

    func dwellChanged() {
        model.dwell = Settings.dwell
    }

    func blurRadiusChanged() {
        applyBlur()
    }

    // MARK: - Actions

    /// "I'm looking at the screen with the mouse pointer."
    func recenter() {
        guard let lastYaw, let screen = NSScreen.containingMouse() else { return }
        model.anchor(to: screen.screenID, rawYaw: lastYaw)
        isConfirmed = true
        onChange?()
    }

    func calibrate() {
        guard isConnected, walkthrough == nil else { return }
        overlay.clear()
        walkthrough = CalibrationWalkthrough { [weak self] targets in
            self?.finishCalibration(targets)
        }
        walkthrough?.start()
        onChange?()
    }

    // MARK: - Private

    private func finishCalibration(_ targets: [ScreenID: Double]?) {
        walkthrough = nil
        if let targets, targets.count == NSScreen.screens.count,
           let first = NSScreen.sortedLeftToRight.first?.screenID, let firstYaw = targets[first] {
            CalibrationStore.save(targets)
            model.targets = targets
            // Targets are in the current AirPods frame, so anchoring on any of them is exact.
            model.anchor(to: first, rawYaw: firstYaw)
            learner.reset()
            isCalibrated = true
            isConfirmed = true
        }
        applyBlur()
        onChange?()
    }

    private func learn(from burst: AutoCalibrator.Burst) {
        let screens = NSScreen.sortedLeftToRight.map(\.screenID)
        guard let targets = learner.proposedTargets(screens: screens, current: model.targets,
                                                    isCalibrated: isCalibrated)
        else { return }
        CalibrationStore.save(targets)
        model.targets = targets
        model.anchor(to: burst.screen, rawYaw: burst.yaw)
        isCalibrated = true
    }

    private func resetAlignment() {
        model.resetAnchor()
        learner.reset()
        lastYaw = nil
        isConfirmed = false
    }

    private func applyBlur() {
        guard isEnabled, isConnected, !isCalibrating, NSScreen.screens.count > 1, let active = model.active else {
            overlay.clear()
            return
        }
        overlay.blur(allExcept: active, radius: isCertain ? Settings.blurRadius : min(hazeRadius, Settings.blurRadius))
    }
}
