import AppKit
import BlinkCore

/// One click-through blur window per screen, shown on every Space and over full-screen apps.
final class BlurOverlay {
    private var windows: [ScreenID: NSWindow] = [:]
    private var blurViews: [ScreenID: BlurView] = [:]
    private var blurred: Set<ScreenID> = []
    private var radius: Double = 0

    func rebuild() {
        windows.values.forEach { $0.orderOut(nil) }
        windows = [:]
        blurViews = [:]
        blurred = []
        radius = 0
        for screen in NSScreen.screens {
            let view = BlurView(frame: NSRect(origin: .zero, size: screen.frame.size))
            windows[screen.screenID] = makeWindow(for: screen, content: view)
            blurViews[screen.screenID] = view
        }
    }

    /// Blurs every screen except `unblurred` with a gaussian of `radius` points.
    func blur(allExcept unblurred: ScreenID, radius: Double) {
        if radius != self.radius {
            self.radius = radius
            blurViews.values.forEach { $0.radius = radius }
        }
        setBlurred(Set(windows.keys).subtracting([unblurred]))
    }

    func clear() {
        setBlurred([])
    }

    private func setBlurred(_ screens: Set<ScreenID>) {
        guard screens != blurred else { return }
        blurred = screens
        for (id, window) in windows {
            let visible = screens.contains(id)
            if visible { window.orderFrontRegardless() }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = visible ? 1 : 0
            } completionHandler: {
                // Skip if it was shown again while fading out.
                if !visible, window.alphaValue == 0 { window.orderOut(nil) }
            }
        }
    }

    private func makeWindow(for screen: NSScreen, content: NSView) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.alphaValue = 0
        content.autoresizingMask = [.width, .height]
        window.contentView = content
        return window
    }
}

/// Gaussian blur of whatever is behind the window, with an adjustable radius.
///
/// Uses the private `CABackdropLayer` and `CAFilter`, as macOS itself does for menus and
/// the Dock. Public `NSVisualEffectView` can't set a radius, so it is only the fallback
/// if those classes ever disappear.
final class BlurView: NSView {
    private var backdrop: CALayer?

    var radius: Double = 0 {
        didSet { applyRadius() }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type,
           BlurView.gaussianBlur(radius: 0) != nil {
            let layer = backdropClass.init()
            layer.frame = bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.setValue(true, forKey: "windowServerAware") // sample other apps' windows too
            self.layer?.addSublayer(layer)
            backdrop = layer
        } else {
            Log.app.error("CABackdropLayer unavailable, using NSVisualEffectView")
            let fallback = NSVisualEffectView(frame: bounds)
            fallback.autoresizingMask = [.width, .height]
            fallback.material = .fullScreenUI
            fallback.blendingMode = .behindWindow
            fallback.state = .active
            addSubview(fallback)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyRadius() {
        guard let backdrop, let filter = BlurView.gaussianBlur(radius: radius) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.filters = [filter]
        CATransaction.commit()
    }

    private static func gaussianBlur(radius: Double) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let make = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: make),
              let filter = filterClass.perform(make, with: "gaussianBlur")?.takeUnretainedValue() as? NSObject
        else { return nil }
        filter.setValue(radius, forKey: "inputRadius")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        return filter
    }
}
