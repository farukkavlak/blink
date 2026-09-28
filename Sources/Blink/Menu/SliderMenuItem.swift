import AppKit

/// A menu row with a caption above a slider; `onChange` fires continuously while dragging.
final class SliderMenuItem: NSMenuItem {
    private let slider: NSSlider
    private let caption: NSTextField
    private let format: (Double) -> String
    private let onChange: (Double) -> Void

    init(value: Double, range: ClosedRange<Double>, format: @escaping (Double) -> String,
         onChange: @escaping (Double) -> Void) {
        self.format = format
        self.onChange = onChange
        slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil, action: nil)
        caption = NSTextField(labelWithString: format(value))
        super.init(title: "", action: nil, keyEquivalent: "")

        caption.font = .menuFont(ofSize: 0)
        caption.textColor = .secondaryLabelColor
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 46))
        caption.frame = NSRect(x: 20, y: 24, width: 210, height: 16)
        slider.frame = NSRect(x: 18, y: 2, width: 210, height: 20)
        container.addSubview(caption)
        container.addSubview(slider)
        view = container
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func sliderMoved() {
        caption.stringValue = format(slider.doubleValue)
        onChange(slider.doubleValue)
    }
}
