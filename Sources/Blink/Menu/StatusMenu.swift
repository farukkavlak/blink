import AppKit

final class StatusMenu: NSObject {
    private let gaze: GazeBlurController
    private let walkAway: WalkAwayLock
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var enabledItem: NSMenuItem!
    private var calibrateItem: NSMenuItem!
    private var learnItem: NSMenuItem!
    private var walkAwayItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!

    init(gaze: GazeBlurController, walkAway: WalkAwayLock) {
        self.gaze = gaze
        self.walkAway = walkAway
        super.init()
        statusItem.menu = buildMenu()
        refresh()
    }

    func refresh() {
        let active = gaze.isEnabled && gaze.isConnected
        statusItem.button?.image = NSImage(systemSymbolName: active ? "eye" : "eye.slash",
                                           accessibilityDescription: "Blink")
        statusLine.title = statusText
        enabledItem.state = gaze.isEnabled ? .on : .off
        calibrateItem.isEnabled = gaze.isConnected && !gaze.isCalibrating
        learnItem.state = Settings.learnWhileTyping ? .on : .off
        walkAwayItem.state = Settings.lockWhenWalkingAway ? .on : .off
        launchAtLoginItem.state = Settings.launchAtLogin ? .on : .off
    }

    private var statusText: String {
        let base: String
        switch gaze.status {
        case .disconnected: return String(localized: "AirPods not connected")
        case .waiting: base = String(localized: "Waiting…")
        case .facing(let screen): base = String(localized: "Looking at: \(screen.localizedName)")
        }
        guard !gaze.isCertain else { return base }
        return Settings.learnWhileTyping
            ? String(localized: "\(base) · learning, type a bit")
            : String(localized: "\(base) · light blur")
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        enabledItem = addItem(to: menu, String(localized: "On (⌃⌥⌘B)"), #selector(toggleEnabled))
        addItem(to: menu, String(localized: "Recenter (⌃⌥⌘R)"), #selector(recenter))
        calibrateItem = addItem(to: menu, String(localized: "Calibrate…"), #selector(calibrate))
        learnItem = addItem(to: menu, String(localized: "Learn while typing"), #selector(toggleLearning))
        walkAwayItem = addItem(to: menu, String(localized: "Lock when I walk away"), #selector(toggleWalkAway))
        menu.addItem(.separator())

        menu.addItem(SliderMenuItem(value: Settings.blurRadius, range: 5...60,
                                    format: { String(localized: "Blur strength: \(Int($0))") }) { [gaze] value in
            Settings.blurRadius = value
            gaze.blurRadiusChanged()
        })
        menu.addItem(SliderMenuItem(value: Settings.dwell, range: 0.1...1,
                                    format: { String(localized: "Reaction time: \(String(format: "%.2f", $0)) s") }) {
            [gaze] value in
            Settings.dwell = value
            gaze.dwellChanged()
        })
        menu.addItem(.separator())

        launchAtLoginItem = addItem(to: menu, String(localized: "Launch at login"), #selector(toggleLaunchAtLogin))
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        // Validate items by their isEnabled property rather than by responder chain.
        menu.autoenablesItems = false
        return menu
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: - Actions

    @objc func toggleEnabled() {
        gaze.isEnabled.toggle()
    }

    @objc func recenter() {
        gaze.recenter()
    }

    @objc private func calibrate() {
        gaze.calibrate()
    }

    @objc private func toggleLearning() {
        Settings.learnWhileTyping.toggle()
        refresh()
    }

    @objc private func toggleWalkAway() {
        Settings.lockWhenWalkingAway.toggle()
        walkAway.reset()
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try Settings.setLaunchAtLogin(!Settings.launchAtLogin)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Couldn't change launch at login")
            alert.informativeText = String(
                localized: "\(error.localizedDescription)\n\nInstall the app with `scripts/build-app.sh --install` and try again.")
            alert.runModal()
        }
        refresh()
    }
}
