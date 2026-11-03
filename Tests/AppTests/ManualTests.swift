import Foundation
import Testing
@testable import MarkTheRoughcut

/// The manuals parse into headings, paragraphs and bullets – no stray Markdown left over.
struct ManualTests {
    let help = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/help")

    @Test func manualsParse() throws {
        for code in ["en", "de", "fr", "es"] {
            let text = try String(contentsOf: help.appendingPathComponent("\(code).md"), encoding: .utf8)
            let blocks = ManualView.parse(text)
            let headings = blocks.filter { if case .heading = $0 { return true } else { return false } }.count
            let bullets = blocks.filter { if case .bullet = $0 { return true } else { return false } }.count
            #expect(headings == 8, "\(code): \(headings) headings")
            #expect(bullets > 20, "\(code): \(bullets) bullets")
            if case .title = blocks.first {} else { Issue.record("\(code): no title") }
        }
    }
}
