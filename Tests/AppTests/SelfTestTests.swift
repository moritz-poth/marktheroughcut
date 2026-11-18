import AVFoundation
import Foundation
import MarkerCore
import Testing
@testable import MarkTheRoughcut

struct SelfTestTests {
    /// The self-test's own video: playable, timecode 10:00:00:00 at 25 fps, an audible tone.
    @Test func testVideoHasTimecodeAndSound() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mtr-selftest-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        try await TestVideo.write(to: url)
        let asset = AVURLAsset(url: url)
        let info = try await VideoInfo.load(asset)
        #expect(info.hasTimecode)
        #expect(info.format.fps == 25)
        #expect(info.format.string(info.startFrame) == "10:00:00:00")
        #expect(info.frameCount == 50)
        let wave = try #require(try await Waveform.load(asset))
        #expect((wave.peaks.max() ?? 0) > 0.05)
    }

    @Test func anonymizeHidesNamesButKeepsStructure() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let line = "open \(home)/Movies/Client Name Rough Cut v3.mov: 25 fps"
        let a = anonymize(line)
        #expect(!a.contains("Client"))
        #expect(!a.contains(NSUserName()))
        #expect(a.hasPrefix("open ~/Movies/n"))
        #expect(a.hasSuffix(": 25 fps"))
    }

    @Test func anonymizeHidesMarkedPathsAndQuotedNames() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let url = URL(fileURLWithPath: "\(home)/Movies/Client: Film (Cut, v3)/Secret.mov")
        let a = anonymize("open \(Log.path(url)) failed: The file “Secret.mov” couldn’t be opened.")
        for word in ["Client", "Film", "Cut", "v3", "Secret", "‹", "›"] { #expect(!a.contains(word), "\(word) in \(a)") }
        #expect(a.hasPrefix("open ~/Movies/n"))
        #expect(a.contains(" failed: The file “n"))
        let tricky = URL(fileURLWithPath: "\(home)/Movies/Client›Secret/<Name>.mov")
        let b = anonymize("open \(Log.path(tricky)): 25 fps")
        for word in ["Client", "Secret", "Name"] { #expect(!b.contains(word), "\(word) in \(b)") }
    }
}
