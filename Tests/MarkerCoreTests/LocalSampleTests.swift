import Foundation
import Testing
@testable import MarkerCore

/// Uses a real Avid export placed next to the package as Marker.txt (git-ignored, private). Skipped without it.
struct LocalSampleTests {
    @Test func realAvidExportIfPresent() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Marker.txt")
        guard let data = try? Data(contentsOf: url) else { return }
        let fmt = TimecodeFormat(fps: 25)
        let r = AvidMarkers.read(data, format: fmt)
        print("real sample: \(r.markers.count) markers, \(r.skipped) skipped, \(r.markers.filter { $0.comment.contains("\n") }.count) multi-line")
        #expect(r.skipped == 0)
        #expect(!r.markers.isEmpty)
        let out = AvidMarkers.write(r.markers, format: fmt)
        let again = AvidMarkers.read(out, format: fmt)
        #expect(again.markers.count == r.markers.count)
        #expect(String(decoding: out, as: UTF8.self).allSatisfy { $0.isASCII })
        try out.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mtr-export-check.txt"))
    }
}
