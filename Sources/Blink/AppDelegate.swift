import AppKit
import Carbon

/// Wires the AirPods stream to the two features and the menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tracker = HeadTracker()
    private let gaze = GazeBlurController()
    private let walkAway = WalkAwayLock()
    private var menu: StatusMenu!
    private var hotKeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu = StatusMenu(gaze: gaze, walkAway: walkAway)
        gaze.onChange = { [weak menu] in menu?.refresh() }
        walkAway.isSuspended = { [gaze] in gaze.isCalibrating }

        tracker.onSample = { [gaze, walkAway] sample in
            gaze.handle(sample)
            walkAway.handle(sample)
        }
        tracker.onConnectionChange = { [gaze, walkAway] connected in
            gaze.connectionChanged(connected)
            walkAway.reset()
        }
        tracker.start()

        let modifiers = controlKey | optionKey | cmdKey
        hotKeys = [
            HotKey(keyCode: kVK_ANSI_B, modifiers: modifiers) { [menu] in menu?.toggleEnabled() },
            HotKey(keyCode: kVK_ANSI_R, modifiers: modifiers) { [menu] in menu?.recenter() },
        ]

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [gaze] _ in gaze.reloadScreens() }
    }
}
