import AppKit

/// A small click-through message panel centered on a screen, above everything
/// including the blur overlay. Used for calibration prompts and the lock countdown.
final class HUDWindow {
    private let window: NSWindow
    private let label = NSTextField(labelWithString: "")

    init(size: NSSize, fontSize: CGFloat) {
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless,
                          backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        label.font = .systemFont(ofSize: fontSize, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -20),
        ])
    }

    func show(_ text: String, on screen: NSScreen) {
        label.stringValue = text
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2))
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}
