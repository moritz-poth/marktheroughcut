import MarkerCore
import SwiftUI

/// Same typography and colours as MediaFiles Ferry and Mountpoint. Dark by default (grading rooms), light optional.
struct Theme {
    var dark = true
    private func c(_ d: UInt32, _ l: UInt32) -> Color {
        let v = dark ? d : l
        return Color(red: Double(v >> 16 & 0xff) / 255, green: Double(v >> 8 & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    var background: Color { c(0x1f2225, 0xf5f5f3) }
    var panel: Color { c(0x181a1c, 0xebebe8) }
    var text: Color { c(0xeceded, 0x17191b) }
    var muted: Color { c(0xa9adb1, 0x3f444a) }
    var faint: Color { c(0x858b91, 0x60666c) }   // dark 4.6:1 (WCAG AA)
    var line: Color { c(0x3a3f44, 0xc4c8cc) }
    var primary: Color { c(0xe6e7e8, 0x2e3236) }
    var onPrimary: Color { c(0x1f2225, 0xf5f5f3) }
    var playhead: Color { c(0x226e8e, 0x226e8e) } // Avid-like blue (the user's reference)
    var warning: Color { c(0xf0883e, 0xb4530f) }   // light 4.6:1 – also text
    var online: Color { c(0x3fb950, 0x1a7f37) }    // light 4.9:1, also text (self-test, toast)
    var error: Color { c(0xf85149, 0xc62828) }
    /// Selected marker row; the comment box (lighter surface, darker outline) stays clearly lighter than it.
    var selection: Color { c(0x24282c, 0xdfe2e5) }
    var field: Color { c(0x30353a, 0xffffff) }
    var fieldLine: Color { c(0x121416, 0xaab0b6) }
    /// Marker lane in the timeline – a grey band like Avid's marker track.
    var lane: Color { c(0x2c3034, 0xd7dadd) }
    var wave: Color { c(0x5a6066, 0xa4a9ae) }
}

extension Font {
    static func mono(_ size: CGFloat = 13, semibold: Bool = false) -> Font {
        .custom(semibold ? "JetBrainsMono-SemiBold" : "JetBrainsMono-Regular", size: size)
    }
}

extension MarkerColor {
    /// Close to the colours Avid shows in its timeline.
    var color: Color {
        switch self {
        case .red: return Color(red: 0.93, green: 0.22, blue: 0.20)
        case .green: return Color(red: 0.25, green: 0.78, blue: 0.30)
        case .blue: return Color(red: 0.25, green: 0.50, blue: 0.98)
        case .cyan: return Color(red: 0.20, green: 0.85, blue: 0.90)
        case .magenta: return Color(red: 0.90, green: 0.25, blue: 0.85)
        case .yellow: return Color(red: 0.98, green: 0.85, blue: 0.20)
        case .black: return Color(white: 0.15)
        case .white: return Color(white: 0.95)
        }
    }

    /// Light marker colours need a dark outline when selected.
    var isLight: Bool { [.green, .cyan, .yellow, .white].contains(self) }

    var label: LocalizedStringKey {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .yellow: return "Yellow"
        case .black: return "Black"
        case .white: return "White"
        }
    }
}

struct FerryButtonStyle: ButtonStyle {
    let theme: Theme
    var primary = false
    var height: CGFloat = 26
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(12, semibold: primary))
            .foregroundColor(!enabled ? theme.faint : primary ? theme.onPrimary : theme.text)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(primary && enabled ? theme.primary.opacity(configuration.isPressed ? 0.85 : 1)
                                                             : theme.text.opacity(configuration.isPressed ? 0.12 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(primary && enabled ? theme.primary : theme.line, lineWidth: 1))
            .contentShape(Rectangle())
            .fixedSize()
    }
}

/// Drop-down that looks like the other buttons (own chevron, system indicator hidden) – lines up flush.
struct Dropdown<Content: View>: View {
    let title: Text
    let theme: Theme
    @ViewBuilder let content: () -> Content
    var body: some View {
        Menu(content: content) {
            HStack(spacing: 6) {
                title
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
        }
        .menuStyle(.button)
        .buttonStyle(FerryButtonStyle(theme: theme))
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// On/off switch in the Ferry look.
struct Switch: View {
    let on: Bool
    let theme: Theme
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? theme.primary : theme.line)
                Circle().fill(on ? theme.onPrimary : (theme.dark ? theme.muted : theme.background)).padding(2)
            }
            .frame(width: 34, height: 20)
            .animation(.easeOut(duration: 0.15), value: on)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityValue(on ? Text("On") : Text("Off"))
    }
}

/// On/off row: label left, `Switch` right; the whole row toggles (as in Mountpoint).
struct SwitchRow: View {
    let title: LocalizedStringKey
    let on: Bool
    let theme: Theme
    let action: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.mono()).foregroundColor(theme.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Switch(on: on, theme: theme, action: action)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(on ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

/// × button with accessibility label and tooltip.
struct CloseButton: View {
    let label: Text
    let theme: Theme
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundColor(theme.muted)
                .frame(width: 18, height: 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey
    let theme: Theme
    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.mono(11, semibold: true))
            .tracking(1)
            .foregroundColor(theme.muted)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// Scroll bar as in Mountpoint and MediaFiles Check: 6 pt, rounded, always visible while there is something to scroll.
final class ThinScroller: NSScroller {
    var dark = true { didSet { needsDisplay = true } }
    override class var isCompatibleWithOverlayScrollers: Bool { false }
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat { 10 }
    override func draw(_ dirtyRect: NSRect) { drawKnob() }
    override func drawKnob() {
        let knob = rect(for: .knob)
        guard knob.height > 0 else { return }
        let thumb = NSRect(x: bounds.maxX - 8, y: knob.minY + 2, width: 6, height: max(knob.height - 4, 20))
        (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: thumb, xRadius: 3, yRadius: 3).fill()
    }
}

extension View {
    /// gives the nearest NSScrollView (ScrollView, TextEditor) the `ThinScroller`
    /// shortcut: takes the first NSScrollView among the ancestors – only where there is exactly one (self-test, report form)
    func thinScroller(dark: Bool) -> some View { background(ThinScrollerHook(dark: dark)) }
}

private struct ThinScrollerHook: NSViewRepresentable {
    let dark: Bool
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let a = ancestor, Self.find(in: a) == nil { ancestor = a.superview }
            guard let s = ancestor.flatMap(Self.find) else { return }
            if !(s.verticalScroller is ThinScroller) { s.verticalScroller = ThinScroller() }
            (s.verticalScroller as? ThinScroller)?.dark = dark
            s.scrollerStyle = .legacy
            s.hasVerticalScroller = true
            s.autohidesScrollers = true
        }
    }
    private static func find(in view: NSView) -> NSScrollView? {
        if let s = view as? NSScrollView { return s }
        for sub in view.subviews { if let s = find(in: sub) { return s } }
        return nil
    }
}

/// Plain slider: a line with a knob to drag (volume).
struct LineSlider: View {
    @Binding var value: Double // 0…1
    let theme: Theme
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, knob: CGFloat = 12
            let x = knob / 2 + CGFloat(value) * (w - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(theme.line).frame(height: 2)
                Capsule().fill(theme.muted).frame(width: x, height: 2)
                Circle().fill(theme.primary).frame(width: knob, height: knob)
                    .overlay(Circle().stroke(theme.line, lineWidth: 1))
                    .offset(x: x - knob / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                value = Double(min(max(0, (v.location.x - knob / 2) / (w - knob)), 1))
            })
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value * 100)) %"))
        .accessibilityAdjustableAction { d in value = min(max(0, value + (d == .increment ? 0.1 : -0.1)), 1) }
    }
}
