import AppKit
import SwiftUI

let languages: [(code: String, name: String)] = [("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español")]

/// App-wide settings: appearance and language (English by default, not the system language).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var dark = UserDefaults.standard.object(forKey: "dark") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(dark, forKey: "dark")
            apply()
        }
    }
    let language = UserDefaults.standard.string(forKey: "language") ?? "en"

    var theme: Theme { Theme(dark: dark) }

    func apply() {
        NSApp?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }

    /// The language is read at launch (AppleLanguages), so switching restarts the app. Markers are saved already.
    func setLanguage(_ code: String) {
        guard code != language else { return }
        UserDefaults.standard.set(code, forKey: "language")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        guard (try? p.run()) != nil else { return }
        NSApp.terminate(nil)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "MarkTheRoughcutRelease") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// Settings in their own window, like Mountpoint: toolbar tabs (icon over name), 800 × 450 (16:9) that never grows,
/// window title stays "MarkTheRoughcut", minimize and zoom dimmed. "About MarkTheRoughcut" opens the About tab;
/// Settings… (⌘,) opens the last other tab, also after a restart. Pages never scroll, only lists inside them.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()

    enum Pane: Int, CaseIterable {
        case general, updates, support, about
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .updates: return "arrow.triangle.2.circlepath"
            case .support: return "lifepreserver"
            case .about: return "info.circle"
            }
        }
        /// lines the first row up with the rows that start with a button: every tab starts at the same height
        var firstLine: CGFloat {
            switch self {
            case .general: return 3     // switch 20 instead of button 26 high
            case .about: return 1.5     // title 15 pt next to the icon
            case .updates, .support: return 0
            }
        }
        var title: String {
            switch self {
            case .general: return String(localized: "General")
            case .updates: return String(localized: "Updates")
            case .support: return String(localized: "Support")
            case .about: return String(localized: "About")
            }
        }
    }

    private var window: NSWindow?
    private var tabs: SettingsTabs?
    static let size = NSSize(width: 800, height: 450)

    /// `nil` = the last tab used before (never About: that has its own menu item)
    func show(_ pane: Pane? = nil) {
        if window == nil { build() }
        let last = Pane(rawValue: UserDefaults.standard.integer(forKey: "settingsPane")) ?? .general
        tabs?.selectedTabViewItemIndex = (pane ?? (last == .about ? .general : last)).rawValue
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let tabs = SettingsTabs()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = false   // window title stays the app name, not the tab
        for pane in Pane.allCases {
            let host = NSHostingController(rootView: SettingsPane(pane: pane))
            host.sizingOptions = []
            host.title = pane.title
            let item = NSTabViewItem(viewController: host)
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
            tabs.addTabViewItem(item)
        }
        let w = NSWindow(contentViewController: tabs)
        w.styleMask = [.titled, .closable]   // without miniaturizable/resizable: minimize and zoom are dimmed
        w.toolbar?.allowsUserCustomization = false
        w.toolbarStyle = .preference
        w.title = "MarkTheRoughcut"
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.setFrame(NSRect(origin: .zero, size: Self.size), display: false)
        w.center()
        window = w
        self.tabs = tabs
    }
}

/// Remembers the tab (except About) and keeps the window size fixed (16:9), even if a tab has more content.
final class SettingsTabs: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        if selectedTabViewItemIndex != SettingsWindow.Pane.about.rawValue {
            UserDefaults.standard.set(selectedTabViewItemIndex, forKey: "settingsPane")
        }
        if let w = view.window, w.frame.size != SettingsWindow.size {
            w.setFrame(NSRect(origin: w.frame.origin, size: SettingsWindow.size), display: true)
        }
    }
}

/// Content of one tab: Ferry look, column of 560 centred, rows = short text left + control right, hints small below.
struct SettingsPane: View {
    let pane: SettingsWindow.Pane
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var test = SelfTest.shared
    @State private var support = Support.main
    @State private var toast: Toast?
    enum Support { case main, selfTest, problem }

    var body: some View {
        let t = settings.theme
        VStack(alignment: .leading, spacing: 14) {
            content(t).padding(.top, pane.firstLine)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(t.background)
        .toast($toast, theme: t)
        .environment(\.colorScheme, settings.dark ? .dark : .light)
    }

    /// sending done: show the toast, on success back to the Support overview
    private func reported(_ outcome: Reporter.Outcome) {
        toast = Toast(outcome)
        guard case .sent = outcome else { return }
        if support == .selfTest { test.reset() }
        support = .main
    }

    /// explanation below a row – wraps before the column of switches and buttons
    private func hint(_ text: LocalizedStringKey, _ t: Theme) -> some View {
        Text(text).font(.mono(11)).foregroundColor(t.faint).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 390, alignment: .leading)
    }

    private func row<C: View>(_ text: Text, _ t: Theme, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 10) {
            text.font(.mono()).foregroundColor(t.text)
            Spacer()
            control()
        }
    }

    @ViewBuilder private func content(_ t: Theme) -> some View {
        switch pane {
        case .general:
            SwitchRow(title: "Light/Dark", on: settings.dark, theme: t) { settings.dark.toggle() }
            hint("Switches every window between a light and a dark look.", t)
            row(Text("Language"), t) {
                Dropdown(title: Text(verbatim: languages.first { $0.code == settings.language }?.name ?? "English"), theme: t) {
                    ForEach(languages, id: \.code) { l in
                        Button(l.name) { settings.setLanguage(l.code) }.disabled(l.code == settings.language)
                    }
                }
            }
            hint("Changing the language restarts MarkTheRoughcut. Your markers are saved.", t)

        case .updates:
            row(Text("Version \(Updater.current)"), t) {
                if updater.state == .checking { ProgressView().controlSize(.small) }
                Button("Check for updates") { updater.check(manual: true) }
                    .buttonStyle(FerryButtonStyle(theme: t))
                    .disabled(updater.state == .checking || updater.state == .installing)
            }
            switch updater.state {
            case .upToDate:
                Text("MarkTheRoughcut is up to date.").font(.mono(11)).foregroundColor(t.faint)
            case .failed(let message) where updater.available == nil:
                Text(message).font(.mono(11)).foregroundColor(t.warning).fixedSize(horizontal: false, vertical: true)
            default:
                if let r = updater.available {
                    Text("MarkTheRoughcut \(UpdateBanner.version(r)) is available.").font(.mono(11)).foregroundColor(t.text)
                }
            }
            hint("MarkTheRoughcut checks GitHub for new versions on its own and shows a notice.", t)
            SwitchRow(title: "Get test versions", on: updater.betas, theme: t) { updater.betas.toggle() }
            hint("Also offers versions that are still being tested. For testers only – they can contain errors.", t)

        case .support:
            switch support {
            case .selfTest:
                SelfTestView(theme: t, test: test, listHeight: 190, done: { support = .main; test.reset() }, sent: reported)
            case .problem:
                ProblemView(theme: t, editorHeight: 110, done: { support = .main }, sent: reported)
            case .main:
                row(test.phase == .running ? Text("Self-test running…") : Text("Test this Mac"), t) {
                    Button("Run self-test…") { support = .selfTest }.buttonStyle(FerryButtonStyle(theme: t))
                }
                hint("Tests playing, timecode, markers and the Media Composer marker list on a test video of its own and sends us an anonymous report.", t)
                row(Text("Problem or idea?"), t) {
                    Button("Report…") { support = .problem }.buttonStyle(FerryButtonStyle(theme: t))
                }
                hint("No GitHub account needed.", t)
                row(Text("Events and errors"), t) {
                    Button("Show log file") { Log.reveal() }.buttonStyle(FerryButtonStyle(theme: t))
                }
                row(Text("Like MarkTheRoughcut?"), t) {
                    Button("Buy me a coffee") { NSWorkspace.shared.open(AboutView.coffee) }.buttonStyle(FerryButtonStyle(theme: t))
                }
                hint("If you use MarkTheRoughcut and like it, I would be glad if you bought me a coffee.", t)
            }

        case .about:
            AboutView(theme: t)
        }
    }
}

/// About tab: version, GPL notice (§5d), source code, license, third-party notices.
struct AboutView: View {
    let theme: Theme

    static let repo = URL(string: "https://github.com/moritz-poth/marktheroughcut")!
    static let gpl = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
    static let coffee = URL(string: "https://buymeacoffee.com/moritzpoth")!

    var body: some View {
        let t = theme
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "MarkTheRoughcut").font(.mono(15, semibold: true)).foregroundColor(t.text)
                    Text("Version \(AppSettings.version)").font(.mono(12)).foregroundColor(t.muted)
                    Text(verbatim: "© 2026 Moritz Poth").font(.mono(12)).foregroundColor(t.muted)
                }
            }
            Text("MarkTheRoughcut is free software: you can redistribute and modify it under the terms of the GNU General Public License, version 3 or later.")
                .font(.mono(12)).foregroundColor(t.text).fixedSize(horizontal: false, vertical: true)
            Text("It comes with ABSOLUTELY NO WARRANTY – use at your own risk.")
                .font(.mono(12)).foregroundColor(t.text).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Source code") { NSWorkspace.shared.open(Self.repo) }
                    .buttonStyle(FerryButtonStyle(theme: t))
                Button("License") {
                    NSWorkspace.shared.open(Bundle.main.url(forResource: "LICENSE", withExtension: "txt") ?? Self.gpl)
                }
                .buttonStyle(FerryButtonStyle(theme: t))
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(title: "Third-party", theme: t)
                Text("JetBrains Mono font – SIL Open Font License 1.1")
                Text("Avid and Media Composer are trademarks of Avid Technology, Inc. MarkTheRoughcut is not affiliated with Avid.")
            }
            .font(.mono(11))
            .foregroundColor(t.faint)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
