import UIKit

/// Base for every control: each one is its own UIView, so UIKit hands each finger
/// to the control it landed on and several controls can be played at once.
class ControlView: UIView {
    let label: String
    /// The incoming MIDI key this control displays (LED / meter); nil = none.
    var led: () -> UInt16? = { nil }

    init(label: String) {
        self.label = label
        super.init(frame: .zero)
        isOpaque = false
        contentMode = .redraw
        NotificationCenter.default.addObserver(self, selector: #selector(ledChanged(_:)), name: .ledChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func ledChanged(_ n: Notification) {
        if let key = n.object as? UInt16, key != led() { return }
        setNeedsDisplay()
    }

    var ledOn: Bool { led().map { MIDI.shared.value($0) > 0 } ?? false }

    func drawText(_ text: String, in rect: CGRect, size: CGFloat = 11, color: UIColor = .lightGray) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: color, .paragraphStyle: style,
        ]
        let s = text as NSString
        let h = s.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height
        s.draw(with: CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h),
               options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
}

/// Button / pad. Momentary by default; `latching` toggles on each tap.
final class PadView: ControlView {
    private let color: UIColor
    private let latching: Bool
    private let lit: () -> Bool
    private let onChange: (Bool) -> Void
    private var down = false { didSet { setNeedsDisplay() } }
    private var latched = false

    init(_ label: String, color: UIColor, latching: Bool = false, lit: @escaping () -> Bool = { false },
         onChange: @escaping (Bool) -> Void) {
        self.color = color
        self.latching = latching
        self.lit = lit
        self.onChange = onChange
        super.init(label: label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        down = true
        if latching { latched.toggle(); onChange(latched) } else { onChange(true) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }

    private func release() {
        down = false
        if !latching { onChange(false) }
    }

    override func draw(_ rect: CGRect) {
        let on = latched || lit() || ledOn
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = UIBezierPath(roundedRect: r, cornerRadius: 7)
        (on ? color : color.withAlphaComponent(down ? 0.4 : 0.14)).setFill()
        path.fill()
        path.lineWidth = down ? 2.5 : 1
        (down ? UIColor.white : color.withAlphaComponent(0.7)).setStroke()
        path.stroke()
        drawText(label, in: r.insetBy(dx: 3, dy: 2), color: on ? .black : .white)
    }
}

/// Shared drag logic for knobs and faders: relative drag, double tap = centre detent.
class ValueView: ControlView {
    private(set) var value: Double
    private let detent: Double?
    private let onChange: (Double) -> Void
    private var last = CGPoint.zero
    var horizontal: Bool { false }
    /// Points of drag for the full 0...1 range.
    var dragLength: CGFloat { 160 }

    init(_ label: String, value: Double, center: Double? = nil, onChange: @escaping (Double) -> Void) {
        self.value = value
        self.detent = center
        self.onChange = onChange
        super.init(label: label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        last = t.location(in: self)
        if t.tapCount == 2, let detent { set(detent) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        let d = horizontal ? p.x - last.x : last.y - p.y
        last = p
        set(value + Double(d / max(dragLength, 1)))
    }

    private func set(_ v: Double) {
        let v = min(max(v, 0), 1)
        guard v != value else { return }
        value = v
        onChange(v)
        setNeedsDisplay()
    }
}

final class KnobView: ValueView {
    private let color: UIColor

    init(_ label: String, value: Double = 0.5, color: UIColor = .systemOrange, onChange: @escaping (Double) -> Void) {
        self.color = color
        super.init(label, value: value, center: 0.5, onChange: onChange)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ rect: CGRect) {
        let labelH: CGFloat = 13
        let radius = max(min(bounds.width, bounds.height - labelH) / 2 - 4, 4)
        let c = CGPoint(x: bounds.midX, y: (bounds.height - labelH) / 2)
        let start = CGFloat.pi * 0.75, sweep = CGFloat.pi * 1.5
        let angle = start + sweep * CGFloat(value)

        UIColor(white: 0.2, alpha: 1).setFill()
        UIBezierPath(arcCenter: c, radius: radius - 4, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
        let track = UIBezierPath(arcCenter: c, radius: radius, startAngle: start, endAngle: start + sweep, clockwise: true)
        track.lineWidth = 3
        UIColor(white: 0.3, alpha: 1).setStroke()
        track.stroke()
        // Bipolar knobs (EQ, filter...) fill from the top centre.
        let arc = UIBezierPath(arcCenter: c, radius: radius, startAngle: min(angle, .pi * 1.5),
                               endAngle: max(angle, .pi * 1.5), clockwise: true)
        arc.lineWidth = 3
        color.setStroke()
        arc.stroke()
        let pointer = UIBezierPath()
        pointer.move(to: c)
        pointer.addLine(to: CGPoint(x: c.x + cos(angle) * (radius - 4), y: c.y + sin(angle) * (radius - 4)))
        pointer.lineWidth = 2.5
        UIColor.white.setStroke()
        pointer.stroke()
        drawText(label, in: CGRect(x: 0, y: bounds.height - labelH, width: bounds.width, height: labelH), size: 10)
    }
}

final class FaderView: ValueView {
    private let isHorizontal: Bool
    private let thumb: CGFloat = 26
    private var labelH: CGFloat { label.isEmpty ? 0 : 14 }

    init(_ label: String, value: Double, center: Double? = nil, horizontal: Bool = false,
         onChange: @escaping (Double) -> Void) {
        isHorizontal = horizontal
        super.init(label, value: value, center: center, onChange: onChange)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var horizontal: Bool { isHorizontal }
    override var dragLength: CGFloat { (isHorizontal ? bounds.width : bounds.height - labelH) - thumb }

    override func draw(_ rect: CGRect) {
        let area = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - labelH)
        let travel = dragLength, v = CGFloat(value)
        let slot: CGRect, knob: CGRect
        if isHorizontal {
            slot = CGRect(x: thumb / 2, y: area.midY - 2, width: travel, height: 4)
            knob = CGRect(x: v * travel, y: area.minY + 4, width: thumb, height: area.height - 8)
        } else {
            slot = CGRect(x: area.midX - 2, y: thumb / 2, width: 4, height: travel)
            knob = CGRect(x: area.minX + 4, y: (1 - v) * travel, width: area.width - 8, height: thumb)
        }
        UIColor(white: 0.25, alpha: 1).setFill()
        UIBezierPath(roundedRect: slot, cornerRadius: 2).fill()
        UIColor(white: 0.78, alpha: 1).setFill()
        UIBezierPath(roundedRect: knob, cornerRadius: 4).fill()
        UIColor.black.setFill()
        UIBezierPath(rect: isHorizontal ? CGRect(x: knob.midX - 1, y: knob.minY + 3, width: 2, height: knob.height - 6)
                                        : CGRect(x: knob.minX + 3, y: knob.midY - 1, width: knob.width - 6, height: 2)).fill()
        if labelH > 0 {
            drawText(label, in: CGRect(x: 0, y: bounds.height - labelH, width: bounds.width, height: labelH), size: 10)
        }
    }
}

/// Jog wheel: inner platter = touch-sensitive top (scratch), outer ring = side (pitch bend).
final class JogView: ControlView {
    private let deck: Int
    private var active: (cc: UInt8, touchNote: UInt8?)?
    private var lastAngle: CGFloat = 0, remainder: CGFloat = 0, rotation: CGFloat = 0

    init(deck: Int) {
        self.deck = deck
        super.init(label: "\(deck + 1)")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var mid: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    private var radius: CGFloat { min(bounds.width, bounds.height) / 2 - 2 }
    private let platter: CGFloat = 0.74 // inner platter radius, fraction of the wheel

    private func angle(_ p: CGPoint) -> CGFloat { atan2(p.y - mid.y, p.x - mid.x) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        let d = hypot(p.x - mid.x, p.y - mid.y)
        guard d <= radius else { return }
        let shift = decks[deck].shift
        if d < radius * platter {
            let note = shift ? FLX4.jogTouch.shifted : FLX4.jogTouch.note
            active = (shift ? FLX4.jogSearch : FLX4.jogPlatter, note)
            MIDI.shared.note(FLX4.deckNote(deck), note, true)
        } else {
            active = (FLX4.jogSide, nil)
        }
        lastAngle = angle(p)
        remainder = 0
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active, let p = touches.first?.location(in: self) else { return }
        guard hypot(p.x - mid.x, p.y - mid.y) > 12 else { return } // angle is meaningless at the centre
        let a = angle(p)
        var delta = a - lastAngle
        if delta > .pi { delta -= 2 * .pi } else if delta < -.pi { delta += 2 * .pi }
        lastAngle = a
        rotation += delta
        remainder += delta / (2 * .pi) * CGFloat(FLX4.jogTicksPerTurn)
        let ticks = Int(remainder) // clockwise (screen coords) = forward
        remainder -= CGFloat(ticks)
        for v in FLX4.jogValues(ticks) { MIDI.shared.send(FLX4.deckCC(deck), active.cc, v) }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }

    private func release() {
        if let note = active?.touchNote { MIDI.shared.note(FLX4.deckNote(deck), note, false) }
        active = nil
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let c = mid, r = radius
        let ring = UIBezierPath(arcCenter: c, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        UIColor(white: active?.cc == FLX4.jogSide ? 0.32 : 0.16, alpha: 1).setFill()
        ring.fill()
        let top = UIBezierPath(arcCenter: c, radius: r * platter, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        UIColor(white: 0.24, alpha: 1).setFill()
        top.fill()
        top.lineWidth = 3
        (active?.touchNote != nil ? UIColor.systemOrange : UIColor(white: 0.4, alpha: 1)).setStroke()
        top.stroke()
        let a = rotation - .pi / 2
        let marker = UIBezierPath()
        marker.move(to: CGPoint(x: c.x + cos(a) * r * 0.35, y: c.y + sin(a) * r * 0.35))
        marker.addLine(to: CGPoint(x: c.x + cos(a) * r * (platter - 0.03), y: c.y + sin(a) * r * (platter - 0.03)))
        marker.lineWidth = 5
        marker.lineCapStyle = .round
        UIColor.white.setStroke()
        marker.stroke()
        drawText(label, in: CGRect(x: c.x - 30, y: c.y - 20, width: 60, height: 40), size: 28, color: UIColor(white: 0.55, alpha: 1))
    }
}

/// BROWSE encoder: drag vertically to scroll, tap to press.
final class EncoderView: ControlView {
    private let onStep: (Int) -> Void
    private let onPress: () -> Void
    private var last = CGPoint.zero, acc: CGFloat = 0, travelled: CGFloat = 0, phase: CGFloat = 0
    private let stepSize: CGFloat = 16

    init(onStep: @escaping (Int) -> Void, onPress: @escaping () -> Void) {
        self.onStep = onStep
        self.onPress = onPress
        super.init(label: "BROWSE")
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        last = touches.first?.location(in: self) ?? .zero
        acc = 0
        travelled = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        let dy = p.y - last.y
        last = p
        acc += dy
        travelled += abs(dy)
        phase += dy
        while acc >= stepSize { onStep(1); acc -= stepSize }
        while acc <= -stepSize { onStep(-1); acc += stepSize }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if travelled < 6 { onPress() }
    }

    override func draw(_ rect: CGRect) {
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = UIBezierPath(roundedRect: r, cornerRadius: 8)
        UIColor(white: 0.2, alpha: 1).setFill()
        path.fill()
        path.addClip()
        UIColor(white: 0.32, alpha: 1).setFill()
        var y = phase.truncatingRemainder(dividingBy: 8) - 8
        while y < bounds.height { UIBezierPath(rect: CGRect(x: 0, y: y, width: bounds.width, height: 2)).fill(); y += 8 }
        drawText("▲\nBROWSE · tap = PUSH\n▼", in: r, size: 10, color: .white)
    }
}

/// Channel level meter fed by the software (CC 0x02 on the deck channel).
final class MeterView: ControlView {
    override func draw(_ rect: CGRect) {
        let level = CGFloat(led().map { MIDI.shared.value($0) } ?? 0) / 127
        let n = 12, gap: CGFloat = 2
        let h = (bounds.height - gap * CGFloat(n - 1)) / CGFloat(n)
        for i in 0..<n {
            let on = CGFloat(i + 1) / CGFloat(n) <= level + 0.001
            let color: UIColor = i >= n - 2 ? .systemRed : i >= n - 4 ? .systemYellow : .systemGreen
            (on ? color : color.withAlphaComponent(0.15)).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: bounds.height - CGFloat(i + 1) * (h + gap) + gap, width: bounds.width, height: h)).fill()
        }
    }
}
