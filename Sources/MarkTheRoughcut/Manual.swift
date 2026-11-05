import SwiftUI

/// The manual (Help menu): `Resources/help/<language>.md`, shown with a small Markdown renderer
/// (headings, paragraphs, bullet lists, inline bold/code, screenshots from `help/images/<language>/`).
struct ManualView: View {
    @ObservedObject private var settings = AppSettings.shared
    /// Text to show instead of the bundled manual (tests).
    var text: String?

    var body: some View {
        let t = settings.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .title(let s):
                        Text(inline(s)).font(.custom("HelveticaNeue-Light", size: 26)).foregroundColor(t.text).padding(.bottom, 6)
                    case .heading(let s):
                        Text(inline(s)).font(.mono(14, semibold: true)).foregroundColor(t.text).padding(.top, 14)
                    case .bullet(let s):
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").font(.mono(12)).foregroundColor(t.faint)
                            Text(inline(s)).font(.mono(12)).foregroundColor(t.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    case .paragraph(let s):
                        Text(inline(s)).font(.mono(12)).foregroundColor(t.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    case .image(let file):
                        if let img = picture(file) {
                            // 2x screenshots: shown at their point size, never wider than the text
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: img.size.width).padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .background(t.background)
        .environment(\.colorScheme, settings.dark ? .dark : .light)
    }

    enum Block: Equatable { case title(String), heading(String), bullet(String), paragraph(String), image(String) }

    /// A screenshot in the manual's language, else the English one.
    private func picture(_ file: String) -> NSImage? {
        for lang in [settings.language, "en"] {
            if let url = Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "help/images/\(lang)"), let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }

    private var blocks: [Block] {
        if let text { return ManualView.parse(text) }
        let url = Bundle.main.url(forResource: settings.language, withExtension: "md", subdirectory: "help")
            ?? Bundle.main.url(forResource: "en", withExtension: "md", subdirectory: "help")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "The manual is missing from this copy of the app."
        return ManualView.parse(text)
    }

    static func parse(_ text: String) -> [Block] {
        var out: [Block] = []
        var para: [String] = []
        func flush() { if !para.isEmpty { out.append(.paragraph(para.joined(separator: " "))); para = [] } }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush() }
            else if line.hasPrefix("## ") { flush(); out.append(.heading(String(line.dropFirst(3)))) }
            else if line.hasPrefix("# ") { flush(); out.append(.title(String(line.dropFirst(2)))) }
            else if line.hasPrefix("- ") { flush(); out.append(.bullet(String(line.dropFirst(2)))) }
            else if line.hasPrefix("!["), let open = line.lastIndex(of: "("), line.hasSuffix(")") {
                flush(); out.append(.image(String(line[line.index(after: open)..<line.index(before: line.endIndex)])))
            }
            else { para.append(line) }
        }
        flush()
        return out
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}
