// Scenario tests for BlinkCore against simulated AirPods data (no hardware needed).
// Run with `swift run BlinkSimulation`. Randomness is seeded, so results are reproducible;
// noisy scenarios run over many seeds and must pass on nearly all of them.

import BlinkCore
import Foundation

// MARK: - Harness

/// Small, fast, seedable PRNG (SplitMix64) so every run sees the same noise.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

var rng = SeededRandom(seed: 1)
func noise(_ amplitude: Double) -> Double { .random(in: -amplitude...amplitude, using: &rng) }
func chance(_ p: Double) -> Bool { .random(in: 0..<1, using: &rng) < p }

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "✅" : "❌", name, detail.isEmpty ? "" : "— \(detail)")
    if !ok { failures += 1 }
}

/// Runs `body` once per seed and requires it to succeed on at least `required` of them.
func checkAcrossSeeds(_ name: String, seeds: Int = 20, required: Double = 0.95, _ body: () -> Bool) {
    var passed = 0
    for seed in 1...seeds {
        rng = SeededRandom(seed: UInt64(seed))
        if body() { passed += 1 }
    }
    check(name, Double(passed) / Double(seeds) >= required, "\(passed)/\(seeds) seeds")
}

let sampleInterval = 1.0 / 25 // AirPods deliver ~25 Hz

// MARK: - Gaze

// Real world: laptop straight ahead (0°), monitor 40° to the right (−40° yaw).
// The AirPods frame is offset by an arbitrary 73° from the real one.
let laptop = "laptop", monitor = "monitor"
let realYaw = [laptop: 0.0, monitor: -40.0]
let frameOffset = 73.0
let calibrated = [laptop: frameOffset, monitor: -40 + frameOffset]

final class GazeSimulation {
    let model = GazeModel()
    let learner = AutoCalibrator()
    let filter = OneEuroFilter()
    var time = 0.0
    var drift = 0.0
    var driftPerSecond = 0.0
    var lastBurst: AutoCalibrator.Burst?

    init(targets: [ScreenID: Double]) { model.targets = targets }

    func raw(_ yaw: Double) -> Double { yaw + frameOffset + drift }

    /// Holds the head at `yaw` for `seconds`, optionally typing into `typing`.
    /// Returns the fraction of samples (after a 1 s settle) where the active screen was `expect`.
    @discardableResult
    func hold(_ yaw: Double, for seconds: Double, expect: ScreenID? = nil, typing: ScreenID? = nil,
              jitter: Double = 1) -> Double {
        var hits = 0, total = 0
        for i in 0..<Int(seconds / sampleInterval) {
            time += sampleInterval
            drift += driftPerSecond * sampleInterval
            let sample = filter.filter(raw(yaw) + noise(jitter), time: time)
            if let burst = learner.feed(rawYaw: sample, typingScreen: typing, time: time) {
                model.observeTyping(screen: burst.screen, rawYaw: burst.yaw)
                lastBurst = burst
            }
            let active = model.update(rawYaw: sample, time: time)
            if i >= 25, let expect {
                total += 1
                if active == expect { hits += 1 }
            }
        }
        return total == 0 ? 1 : Double(hits) / Double(total)
    }
}

print("Gaze")

checkAcrossSeeds("turning the head selects the faced screen") {
    let sim = GazeSimulation(targets: calibrated)
    sim.model.anchor(to: laptop, rawYaw: sim.raw(0))
    return sim.hold(realYaw[laptop]!, for: 3, expect: laptop) > 0.99
        && sim.hold(realYaw[monitor]!, for: 3, expect: monitor) > 0.95
        && sim.hold(realYaw[laptop]!, for: 3, expect: laptop) > 0.95
}

checkAcrossSeeds("no flicker while hovering near the midpoint") {
    let sim = GazeSimulation(targets: calibrated)
    sim.model.anchor(to: laptop, rawYaw: sim.raw(0))
    var switches = 0
    var last = sim.model.active
    for _ in 0..<250 {
        sim.hold(-18 + noise(3), for: sampleInterval, jitter: 2)
        if sim.model.active != last { switches += 1; last = sim.model.active }
    }
    return switches <= 1
}

checkAcrossSeeds("30°/hour sensor drift is corrected") {
    let sim = GazeSimulation(targets: calibrated)
    sim.model.anchor(to: laptop, rawYaw: sim.raw(0))
    sim.driftPerSecond = 30.0 / 3600
    var worst = 1.0
    for _ in 0..<60 {
        worst = min(worst, sim.hold(realYaw[laptop]!, for: 30, expect: laptop))
        worst = min(worst, sim.hold(realYaw[monitor]!, for: 30, expect: monitor))
    }
    return worst > 0.9
}

checkAcrossSeeds("a wrong initial anchor is fixed by typing") {
    let sim = GazeSimulation(targets: calibrated)
    sim.model.anchor(to: laptop, rawYaw: sim.raw(realYaw[monitor]!)) // cursor on laptop, eyes on monitor
    for _ in 0..<3 {
        sim.hold(realYaw[monitor]!, for: 3, typing: monitor)
        sim.hold(realYaw[monitor]!, for: 1.5)
    }
    return sim.hold(realYaw[monitor]!, for: 3, expect: monitor) > 0.95
        && sim.hold(realYaw[laptop]!, for: 3, expect: laptop) > 0.95
}

// MARK: - Learning from typing

print("\nLearning from typing")

/// Types a few bursts into each screen; `mistakes` bursts go to the laptop while facing the monitor.
func typeIntoBoth(_ sim: GazeSimulation, rounds: Int = 3, mistakes: Int = 0) {
    for round in 0..<rounds {
        let facing = round < mistakes ? realYaw[monitor]! : realYaw[laptop]!
        sim.hold(facing, for: 4, typing: laptop)
        sim.hold(facing, for: 1.5)
        sim.hold(realYaw[monitor]!, for: 4, typing: monitor)
        sim.hold(realYaw[monitor]!, for: 1.5)
    }
}

func learnedSeparation(_ sim: GazeSimulation) -> Double? {
    sim.learner.learnedTargets(screens: [laptop, monitor]).map { $0[monitor]! - $0[laptop]! }
}

checkAcrossSeeds("learns the angle between screens (−40°)") {
    let sim = GazeSimulation(targets: [laptop: 0, monitor: -35])
    typeIntoBoth(sim)
    return learnedSeparation(sim).map { abs($0 - -40) < 2 } ?? false
}

checkAcrossSeeds("one burst typed while looking elsewhere doesn't spoil it") {
    let sim = GazeSimulation(targets: [laptop: 0, monitor: -35])
    typeIntoBoth(sim, rounds: 4, mistakes: 1)
    return learnedSeparation(sim).map { abs($0 - -40) < 2 } ?? false
}

checkAcrossSeeds("typing while the head moves around is ignored") {
    let sim = GazeSimulation(targets: [laptop: 0, monitor: -35])
    for _ in 0..<5 {
        for k in 0..<100 { sim.hold(-20 + 20 * sin(Double(k) / 8), for: sampleInterval, typing: laptop) }
        sim.hold(0, for: 1.5)
    }
    return sim.lastBurst == nil
}

do {
    let sim = GazeSimulation(targets: [laptop: 0, monitor: -35])
    typeIntoBoth(sim)
    let screens = [laptop, monitor]
    let fresh = sim.learner.proposedTargets(screens: screens, current: [laptop: 0, monitor: -35], isCalibrated: false)
    check("uncalibrated: adopts learned angles", fresh.map { abs($0[monitor]! - -40) < 2 } ?? false)

    let refined = sim.learner.proposedTargets(screens: screens, current: [laptop: 0, monitor: -30], isCalibrated: true)
    check("calibrated: moves 30% toward learned angles",
          refined.map { abs($0[monitor]! - -33) < 1 } ?? false, refined.map { "\($0[monitor]!)" } ?? "nil")

    let contradicting = sim.learner.proposedTargets(screens: screens, current: [laptop: 0, monitor: 10],
                                                    isCalibrated: true)
    check("calibrated: ignores data that contradicts it", contradicting == nil)
}

// MARK: - Walking

print("\nWalking")

/// Feeds `seconds` of motion into a fresh detector; returns when walking was detected.
func detectWalking(within seconds: Double, _ motion: (Double) -> (vertical: Double, rotation: Double)) -> Double? {
    let detector = WalkDetector()
    var time = 0.0
    while time < seconds {
        let m = motion(time)
        if detector.feed(verticalAcceleration: m.vertical, rotationRate: m.rotation, time: time) { return time }
        time += sampleInterval
    }
    return nil
}

/// Walking at `stepsPerSecond` with a vertical bounce of `bounce` g and a mostly steady head.
func walking(stepsPerSecond: Double, bounce: Double) -> (Double) -> (vertical: Double, rotation: Double) {
    var phase = 0.0
    return { _ in
        phase += sampleInterval * stepsPerSecond * (1 + noise(0.1)) * 2 * .pi
        return (bounce * sin(phase) + noise(bounce / 5), 0.3 + noise(0.2))
    }
}

checkAcrossSeeds("normal walk is detected within 6 s") {
    detectWalking(within: 6, walking(stepsPerSecond: 1.8, bounce: 0.2)) != nil
}

checkAcrossSeeds("slow walk is detected within 8 s") {
    detectWalking(within: 8, walking(stepsPerSecond: 1.2, bounce: 0.12)) != nil
}

checkAcrossSeeds("sitting for 10 minutes never triggers", required: 1) {
    detectWalking(within: 600) { _ in (noise(0.03) + (chance(0.01) ? noise(0.25) : 0), abs(noise(0.3))) } == nil
}

checkAcrossSeeds("standing up and sitting back down doesn't trigger", required: 1) {
    detectWalking(within: 10) { t in
        (t > 2 && t < 2.8 ? 0.35 * sin((t - 2) / 0.8 * .pi) : noise(0.02), 0.5 + noise(0.2))
    } == nil
}

// Head bobbing: rotation θ = A·sin(ωt) about the neck (0.15 m). Its vertical acceleration
// peaks at the turning points, exactly where the rotation rate is ~0.
for (amplitude, bpm) in [(0.07, 100.0), (0.08, 128.0), (0.15, 120.0), (0.3, 100.0)] {
    let label = String(format: "bobbing to music (±%.0f°, %.0f bpm) doesn't trigger", amplitude * 180 / .pi, bpm)
    checkAcrossSeeds(label, required: 1) {
        let w = bpm / 60 * 2 * .pi
        return detectWalking(within: 120) { t in
            (amplitude * w * w * 0.15 * sin(w * t) / 9.81 + noise(0.03),
             abs(amplitude * w * cos(w * t)) + abs(noise(0.1)))
        } == nil
    }
}

print(failures == 0 ? "\nAll scenarios passed." : "\n\(failures) scenario(s) failed.")
exit(failures == 0 ? 0 : 1)
