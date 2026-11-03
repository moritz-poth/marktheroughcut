import AVFoundation
import Foundation
import Testing
@testable import MarkerCore

/// Reads frame timing and the timecode track of real files. The test videos are made with ffmpeg
/// (Homebrew); without it the tests are skipped.
struct VideoInfoTests {
    static let ffmpeg = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }

    func make(_ name: String, rate: String, seconds: Int, timecode: String?) throws -> URL? {
        guard let ffmpeg = Self.ffmpeg else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mtr-\(UUID().uuidString)-\(name)")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = ["-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=320x180:rate=\(rate)", "-t", "\(seconds)"]
            + (timecode.map { ["-timecode", $0] } ?? []) + ["-c:v", "libx264", "-pix_fmt", "yuv420p", url.path]
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? url : nil
    }

    @Test func timecode25() async throws {
        guard let url = try make("tc25.mov", rate: "25", seconds: 4, timecode: "01:00:00:00") else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        let info = try await VideoInfo.load(AVURLAsset(url: url))
        #expect(info.hasTimecode)
        #expect(info.format == TimecodeFormat(fps: 25))
        #expect(info.format.string(info.startFrame) == "01:00:00:00")
        #expect(info.frameCount == 100)
        #expect(info.format.string(info.tcFrame(ofIndex: 99)) == "01:00:03:24")
        #expect(info.index(at: info.time(ofIndex: 57)) == 57)
    }

    @Test func dropFrame2997() async throws {
        guard let url = try make("df.mov", rate: "30000/1001", seconds: 2, timecode: "00:59:59;20") else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        let info = try await VideoInfo.load(AVURLAsset(url: url))
        #expect(info.format == TimecodeFormat(fps: 30, dropFrame: true))
        #expect(info.format.string(info.startFrame) == "00:59:59;20")
        // ten frames later the hour rolls over (no frames dropped at a full ten minutes)
        #expect(info.format.string(info.tcFrame(ofIndex: 10)) == "01:00:00;00")
        #expect(abs(info.fpsReal - 29.97) < 0.01)
    }

    @Test func waveformFollowsLoudness() async throws {
        guard let ffmpeg = Self.ffmpeg else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mtr-\(UUID().uuidString)-wave.mov")
        defer { try? FileManager.default.removeItem(at: url) }
        // 2 s silence, then 2 s loud tone
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = ["-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=160x90:rate=25", "-f", "lavfi",
                       "-i", "aevalsrc='0.8*sin(2*PI*440*t)*gte(t,2)':s=48000", "-t", "4", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", url.path]
        try p.run()
        p.waitUntilExit()
        let wave = try #require(try await Waveform.load(AVURLAsset(url: url)))
        #expect(abs(Double(wave.peaks.count) / Waveform.rate - 4) < 0.2)
        #expect(wave.peak(from: 0.2, to: 1.8) < 0.05)
        #expect(wave.peak(from: 2.5, to: 3.5) > 0.5)
    }

    @Test func noTimecodeStartsAtZero() async throws {
        guard let url = try make("plain.mp4", rate: "24000/1001", seconds: 2, timecode: nil) else { return }
        defer { try? FileManager.default.removeItem(at: url) }
        let info = try await VideoInfo.load(AVURLAsset(url: url))
        #expect(!info.hasTimecode)
        #expect(info.startFrame == 0)
        #expect(info.format.fps == 24)
    }
}
