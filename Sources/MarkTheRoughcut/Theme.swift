import MarkerCore
import SwiftUI

/// Same typography and colours as MediaFiles Ferry and Mountpoint. Dark by default (grading rooms).
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
    var playhead: Color { c(0xf85149, 0xc62828) }
    var warning: Color { c(0xf0883e, 0xe16f24) }
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
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(12, semibold: primary))
            .foregroundColor(!enabled ? theme.faint : primary ? theme.onPrimary : theme.text)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(primary && enabled ? theme.primary.opacity(configuration.isPressed ? 0.85 : 1)
                                                             : theme.text.opacity(configuration.isPressed ? 0.12 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(primary && enabled ? theme.primary : theme.line, lineWidth: 1))
            .contentShape(Rectangle())
            .fixedSize()
    }
}
