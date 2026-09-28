import AppKit

/// A short on-screen warning before locking. Any keyboard or mouse input cancels it, so a
/// false walk detection while at the desk costs no more than a flick of the mouse.
final class LockCountdown {
    private let hud = HUDWindow(size: NSSize(width: 480, height: 110), fontSize: 22)
    private let started = Date()
    private var timer: Timer?

    /// `completion(cancelled)` runs once, when the countdown ends or is cancelled.
    init(seconds: Int, completion: @escaping (_ cancelled: Bool) -> Void) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(self.started)
            let cancelled = SystemActions.secondsSinceAnyInput() < elapsed
            guard !cancelled, elapsed < Double(seconds) else {
                timer.invalidate()
                self.hud.hide()
                completion(cancelled)
                return
            }
            if let screen {
                let left = Int((Double(seconds) - elapsed).rounded(.up))
                self.hud.show(String(localized: "Walked away, locking in \(left) s\nMove the mouse to cancel"),
                              on: screen)
            }
        }
        timer?.fire()
    }
}
