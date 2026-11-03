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

/// Settings window (⌘,): appearance and language. About has its own window.
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        let t = settings.theme
        general(t)
            .padding(24)
            .frame(width: 460)
            .fixedSize(horizontal: false, vertical: true)
            .background(t.background)
            .environment(\.colorScheme, settings.dark ? .dark : .light)
    }

    private func general(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("Appearance").font(.mono()).foregroundColor(t.text)
                Spacer()
                Text("Light").font(.mono(12)).foregroundColor(settings.dark ? t.faint : t.text)
                Switch(on: settings.dark, theme: t) { settings.dark.toggle() }
                    .accessibilityLabel(Text("Dark appearance"))
                Text("Dark").font(.mono(12)).foregroundColor(settings.dark ? t.text : t.faint)
            }
            HStack(spacing: 10) {
                Text("Language").font(.mono()).foregroundColor(t.text)
                Spacer()
                Dropdown(title: Text(verbatim: languages.first { $0.code == settings.language }?.name ?? "English"), theme: t) {
                    ForEach(languages, id: \.code) { l in
                        Button(l.name) { settings.setLanguage(l.code) }.disabled(l.code == settings.language)
                    }
                }
            }
            Text("Changing the language restarts MarkTheRoughcut. Your markers are saved.")
                .font(.mono(11)).foregroundColor(t.faint).fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(t.line).frame(height: 1)
            // updates, same as in Mountpoint
            HStack(spacing: 10) {
                Text("Version \(Updater.current)").font(.mono()).foregroundColor(t.text)
                Spacer()
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
            Text("MarkTheRoughcut checks GitHub for new versions on its own and shows a notice.")
                .font(.mono(11)).foregroundColor(t.faint).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// About window (App menu → About MarkTheRoughcut): version, license, third-party notices.
struct AboutView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        let t = settings.theme
        about(t)
            .padding(24)
            .frame(width: 440)
            .fixedSize(horizontal: false, vertical: true)
            .background(t.background)
            .environment(\.colorScheme, settings.dark ? .dark : .light)
    }

    private func about(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
                Button("Source code") { NSWorkspace.shared.open(URL(string: "https://github.com/moritz-poth/marktheroughcut")!) }
                    .buttonStyle(FerryButtonStyle(theme: t))
                Button("License") {
                    if let url = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") { NSWorkspace.shared.open(url) }
                    else { NSWorkspace.shared.open(URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) }
                }
                .buttonStyle(FerryButtonStyle(theme: t))
            }
            Rectangle().fill(t.line).frame(height: 1)
            Text("JetBrains Mono font – SIL Open Font License 1.1").font(.mono(11)).foregroundColor(t.faint)
            Text("Avid and Media Composer are trademarks of Avid Technology, Inc. MarkTheRoughcut is not affiliated with Avid.")
                .font(.mono(11)).foregroundColor(t.faint).fixedSize(horizontal: false, vertical: true)
        }
    }
}
