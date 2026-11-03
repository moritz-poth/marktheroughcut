import Foundation
import Testing
@testable import MarkerCore

struct TimecodeTests {
    @Test func nonDropRoundTrip() {
        let f = TimecodeFormat(fps: 25)
        #expect(f.frames("02:07:19:07") == ((2 * 3600 + 7 * 60 + 19) * 25 + 7))
        #expect(f.string(f.frames("02:07:19:07")!) == "02:07:19:07")
        #expect(f.frames("00:00:00:25") == nil) // frame out of range at 25 fps
        #expect(f.frames("garbage") == nil)
    }

    @Test func dropFrameSkipsFrameNumbers() {
        let df = TimecodeFormat(fps: 30, dropFrame: true)
        // after 00:00:59;29 comes 00:01:00;02 (frames ;00 and ;01 are skipped), but not every tenth minute
        let a = df.frames("00:00:59;29")!
        #expect(df.string(a + 1) == "00:01:00;02")
        #expect(df.string(df.frames("00:10:00;00")!) == "00:10:00;00")
        // one hour of 29.97 DF is 107892 frames
        #expect(df.frames("01:00:00;00") == 107_892)
        for n in stride(from: 0, to: 300_000, by: 997) { #expect(df.frames(df.string(n)) == n) }
    }
}

struct AvidMarkerTests {
    /// Same quirks as a real Avid export: Mac Roman, comment with a line break, slash, quotes, umlauts.
    static let sample: Data = {
        let text = "Editor\t01:00:10:00\tV1\tYellow\tRetusche Kamera im Spiegel\t1\t\tYellow\n"
            + "Regie, Kamera\t01:00:20:12\tV9\tBlue\t[Regie · 09:28] früher aussteigen?\nZweite Zeile \"so\" / anders\t1\t\tBlue\n"
            + "Ton\t01:01:00:00\tA1\tGreen\tAtmo lauter\t50\t\tGreen\n"
        return text.data(using: .macOSRoman)!
    }()

    @Test func importsAvidExport() {
        let fmt = TimecodeFormat(fps: 25)
        let r = AvidMarkers.read(Self.sample, format: fmt)
        #expect(r.skipped == 0)
        #expect(r.markers.count == 3)
        #expect(r.markers[1].user == "Regie, Kamera")
        #expect(r.markers[1].comment == "[Regie · 09:28] früher aussteigen?\nZweite Zeile \"so\" / anders")
        #expect(r.markers[1].track == "V9" && r.markers[1].color == .blue)
        #expect(r.markers[2].duration == 50 && r.markers[2].track == "A1")
        #expect(fmt.string(r.markers[0].frame) == "01:00:10:00")
    }

    @Test func exportIsSafeAndReimports() {
        let fmt = TimecodeFormat(fps: 25)
        let markers = AvidMarkers.read(Self.sample, format: fmt).markers
        let data = AvidMarkers.write(markers, format: fmt)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.allSatisfy { $0.isASCII })
        #expect(!text.contains("/") && !text.contains("\""))
        #expect(text.split(separator: "\n").count == 3) // line break inside the comment is gone
        #expect(text.contains("Regie, Kamera\t01:00:20:12\tV9\tBlue\t[Regie - 09:28] frueher aussteigen? Zweite Zeile 'so' - anders\t1\t\tBlue"))
        let back = AvidMarkers.read(data, format: fmt)
        #expect(back.markers.map(\.frame) == markers.map(\.frame))
        #expect(back.markers.map(\.duration) == [1, 1, 50])
    }

    @Test func safeText() {
        #expect(AvidMarkers.safe("Größe: 5€ – „gut“ / schlecht…") == "Groesse: 5EUR - 'gut' - schlecht...")
        #expect(AvidMarkers.safe("Café 🎬\tok") == "Cafe ok")
    }

    @Test func utf8ListsAndBrokenLines() {
        let utf8 = "Me\t00:00:01:00\tV1\tred\tÜberblendung\t1\t\tRed\nthis is no marker\n".data(using: .utf8)!
        let r = AvidMarkers.read(utf8, format: TimecodeFormat(fps: 24))
        #expect(r.markers.count == 1 && r.markers[0].comment.hasPrefix("Überblendung") && r.markers[0].color == .red)
        let bad = "Me\t00:00:01:99\tV1\tRed\tx\t1\t\tRed\n".data(using: .utf8)!
        #expect(AvidMarkers.read(bad, format: TimecodeFormat(fps: 24)).skipped == 1)
    }
}
