import Foundation
import Testing

/// Every language has every UI text with the same placeholders, and a manual.
struct LocalizationTests {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")

    private func strings(_ code: String) -> [String: String] {
        NSDictionary(contentsOf: root.appendingPathComponent("\(code).lproj/Localizable.strings")) as? [String: String] ?? [:]
    }

    @Test func allLanguagesComplete() {
        let reference = strings("de")
        #expect(reference.count > 50)
        for code in ["fr", "es"] {
            let other = strings(code)
            #expect(Set(other.keys) == Set(reference.keys), "\(code): missing \(Set(reference.keys).subtracting(other.keys)), extra \(Set(other.keys).subtracting(reference.keys))")
            for (key, value) in other {
                let marks = { (s: String) in [s.components(separatedBy: "%@").count, s.components(separatedBy: "%lld").count] }
                #expect(marks(key) == marks(value), "\(code): placeholders differ in \(key)")
            }
        }
        for code in ["en", "de", "fr", "es"] {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("help/\(code).md").path), "manual \(code) missing")
        }
    }
}
