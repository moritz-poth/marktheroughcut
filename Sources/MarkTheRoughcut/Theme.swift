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
    var faint: Color { c(0x7c8288, 0x60666c) }
    var line: Color { c(0x3a3f44, 0xc4c8cc) }
    var primary: Color { c(0xe6e7e8, 0x2e3236) }
    var onPrimary: Color { c(0x1f2225, 0xf5f5f3) }
    var playhead: Color { c(0x226e8e, 0x226e8e) } // Avid-like blue (the user's reference)
    var warning: Color { c(0xf0883e, 0xe16f24) }
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
