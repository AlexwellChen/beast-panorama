import AppKit

final class PlayerPanel: NSVisualEffectView {
    init() {
        super.init(frame: .zero)
        material = .hudWindow; blendingMode = .withinWindow; state = .active
        wantsLayer = true; layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }
}

func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = secondary ? .secondaryLabelColor : .labelColor
    field.lineBreakMode = .byTruncatingTail
    return field
}
func row(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
    let stack = NSStackView(views: views); stack.orientation = .horizontal
    stack.alignment = .centerY; stack.spacing = spacing; return stack
}
func spacer() -> NSView {
    let v = NSView(); v.setContentHuggingPriority(.defaultLow, for: .horizontal); return v
}
func pin(_ child: NSView, to parent: NSView, inset: CGFloat = 0) {
    parent.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
        child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
        child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
        child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
    ])
}
func timeText(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let s = Int(seconds)
    if s >= 3600 { return String(format: "%d:%02d:%02d", s/3600, s/60%60, s%60) }
    return String(format: "%d:%02d", s/60, s%60)
}

/// Overlay panels must never negotiate the size of the video canvas/window.
final class PlayerCanvas: NSView {
    let renderer: NSView
    let header: NSView, controls: NSView, welcome: NSView
    init(renderer: NSView, header: NSView, controls: NSView, welcome: NSView) {
        self.renderer=renderer; self.header=header; self.controls=controls; self.welcome=welcome
        super.init(frame:.zero)
        autoresizingMask=[.width,.height]
        for child in [renderer,header,controls,welcome] { addSubview(child) }
    }
    required init?(coder:NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        renderer.frame=bounds
        let topWidth=min(1200,max(0,bounds.width-48))
        let bottomWidth=min(1120,max(0,bounds.width-48))
        header.frame=NSRect(x:(bounds.width-topWidth)/2,y:bounds.height-118,width:topWidth,height:76)
        controls.frame=NSRect(x:(bounds.width-bottomWidth)/2,y:24,width:bottomWidth,height:138)
        welcome.frame=NSRect(x:(bounds.width-500)/2,y:(bounds.height-220)/2,width:500,height:220)
    }
}
