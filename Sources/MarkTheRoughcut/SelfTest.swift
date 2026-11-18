import AppKit
import AVFoundation
import CryptoKit
import Foundation
import MarkerCore

/// Self-test for testers: makes its own short test video (timecode 10:00:00:00, a tone) in a temporary folder and checks
/// reading the timecode, playing, the waveform, saving markers, the Avid export/import, the update check and the log.
/// The user's videos and markers are never touched; the test folder is deleted at the end.
/// Result: `SelfTestReport` (JSON, anonymized) – the user can save it to look at it before sending (Reporter.swift).
struct CheckResult: Codable, Identifiable, Equatable {
    enum Status: String, Codable { case pass, fail, skip }
    let id: String
    let title: String
    var status: Status
    var seconds: Double
    var detail: String
}

struct SelfTestReport: Codable {
    var product = "marktheroughcut"   // the worker files it in moritz-poth/marktheroughcut-reports
    var kind: String          // "selftest" | "problem"
    var app: String
    var build: String
    var date: String
    var system: [String: String]
    var results: [CheckResult]
    var durationSeconds: Double
    var log: [String]
    var note: String?
    var contact: String?
}

/// A check is skipped (e.g. no internet) – not an error.
struct SkipCheck: Error { let reason: String }
struct CheckFailed: Error { let reason: String }

@MainActor
final class SelfTest: ObservableObject {
    static let shared = SelfTest()

    enum Phase: Equatable { case idle, running, done }
    @Published private(set) var phase = Phase.idle
    @Published private(set) var results: [CheckResult] = []
    @Published private(set) var current: String?
    private(set) var report: SelfTestReport?

    private let fm = FileManager.default
    private var folder: URL!
    private var video: URL { folder.appendingPathComponent("Selftest.mov") }
    private var info: VideoInfo?
    private var started = Date()

    struct Check {
        let id: String
        let title: String
        let run: @MainActor (SelfTest) async throws -> String
    }

    func start() {
        guard phase != .running else { return }
        phase = .running
        results = []
        report = nil
        info = nil
        started = Date()
        Log.write("self-test started")
        Task { await runAll() }
    }

    func reset() { if phase == .done { phase = .idle; results = []; report = nil } }

    private func runAll() async {
        folder = fm.temporaryDirectory.appendingPathComponent("MarkTheRoughcut-Selftest-\(UUID().uuidString.prefix(6))")
        for c in checks {
            current = c.title
            let t = Date()
            var r = CheckResult(id: c.id, title: c.title, status: .pass, seconds: 0, detail: "")
            do { r.detail = try await c.run(self) }
            catch let s as SkipCheck { r.status = .skip; r.detail = s.reason }
            catch let f as CheckFailed { r.status = .fail; r.detail = f.reason }
            catch { r.status = .fail; r.detail = error.localizedDescription }
            r.seconds = (Date().timeIntervalSince(t) * 100).rounded() / 100
            results.append(r)
        }
        try? fm.removeItem(at: folder)
        current = nil
        let failed = results.filter { $0.status == .fail }.count
        Log.write("self-test done: \(results.count) checks, \(failed) failed")
        report = SelfTestReport(
            kind: "selftest", app: Updater.current, build: Self.build, date: ISO8601DateFormatter().string(from: Date()),
            system: Self.systemInfo(), results: results.map { var r = $0; r.detail = anonymize(r.detail); return r },
            durationSeconds: (Date().timeIntervalSince(started) * 10).rounded() / 10, log: Self.logTail(), note: nil, contact: nil)
        phase = .done
    }

    /// Titles stay English in the report (one language to evaluate); the view translates them.
    private var checks: [Check] {
        [
            Check(id: "video", title: "Test video") { t in
                try t.fm.createDirectory(at: t.folder, withIntermediateDirectories: true)
                let url = t.video
                try await Task.detached { try await TestVideo.write(to: url) }.value
                let size = (try? t.fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                return "2 s, 25 fps, timecode 10:00:00:00, \(size / 1024) KB"
            },
            Check(id: "timecode", title: "Timecode from the file") { t in
                guard t.fm.fileExists(atPath: t.video.path) else { throw SkipCheck(reason: "no test video") }
                let info = try await VideoInfo.load(AVURLAsset(url: t.video))
                t.info = info
                let expected = info.format.frames("10:00:00:00")
                guard info.hasTimecode, info.format.fps == 25, info.startFrame == expected else {
                    throw CheckFailed(reason: "read \(info.format.string(info.startFrame)) at \(info.format.fps) fps, timecode track: \(info.hasTimecode)")
                }
                return "\(info.format.string(info.startFrame)), \(info.frameCount) frames"
            },
            Check(id: "play", title: "Playing") { t in
                guard t.fm.fileExists(atPath: t.video.path) else { throw SkipCheck(reason: "no test video") }
                let asset = AVURLAsset(url: t.video)
                guard try await asset.load(.isPlayable) else { throw CheckFailed(reason: "AVFoundation cannot play the test video") }
                let gen = AVAssetImageGenerator(asset: asset)
                gen.requestedTimeToleranceBefore = .zero
                gen.requestedTimeToleranceAfter = .zero
                let image = try gen.copyCGImage(at: CMTime(value: 1, timescale: 1), actualTime: nil)
                return "frame at 1 s: \(image.width) × \(image.height)"
            },
            Check(id: "waveform", title: "Waveform") { t in
                guard t.fm.fileExists(atPath: t.video.path) else { throw SkipCheck(reason: "no test video") }
                let url = t.video
                let wave = try await Task.detached { try await Waveform.load(AVURLAsset(url: url)) }.value
                guard let wave, !wave.peaks.isEmpty else { throw CheckFailed(reason: "no sound read") }
                let loud = wave.peaks.max() ?? 0
                guard loud > 0.05 else { throw CheckFailed(reason: "the tone reads as silence (peak \(loud))") }
                return "\(wave.peaks.count) peaks, loudest \(String(format: "%.2f", loud))"
            },
            Check(id: "save", title: "Saving markers next to the video") { t in
                try t.fm.createDirectory(at: t.folder, withIntermediateDirectories: true)
                let file = t.video.deletingPathExtension().appendingPathExtension("markers.json")
                let markers = Self.sampleMarkers(t.info)
                try JSONEncoder.pretty.encode(SavedMarkers(video: t.video.lastPathComponent, markers: markers)).write(to: file, options: .atomic)
                let back = try JSONDecoder().decode(SavedMarkers.self, from: Data(contentsOf: file)).markers
                guard back == markers else { throw CheckFailed(reason: "read back \(back.count) of \(markers.count) markers, not identical") }
                return "\(markers.count) markers written and read back"
            },
            Check(id: "avid", title: "Media Composer marker list export and import") { t in
                let format = t.info?.format ?? TimecodeFormat(fps: 25)
                let markers = Self.sampleMarkers(t.info)
                let data = AvidMarkers.write(markers, format: format)
                guard data.allSatisfy({ $0 < 0x80 }) else { throw CheckFailed(reason: "export is not plain ASCII") }
                let text = String(decoding: data, as: UTF8.self)
                guard !text.contains("/"), !text.contains("\""), !text.contains("ä") else { throw CheckFailed(reason: "export still contains / \" or umlauts") }
                let back = AvidMarkers.read(data, format: format)
                guard back.skipped == 0, back.markers.map(\.frame) == markers.map(\.frame),
                      back.markers.map(\.duration) == markers.map(\.duration) else {
                    throw CheckFailed(reason: "import read \(back.markers.count) of \(markers.count) markers, \(back.skipped) lines skipped")
                }
                return "\(markers.count) markers, incl. a span of \(markers[1].duration) frames"
            },
            Check(id: "update", title: "Update check") { _ in
                var req = URLRequest(url: URL(string: "https://api.github.com/repos/moritz-poth/marktheroughcut/releases?per_page=20")!, timeoutInterval: 15)
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                guard let (data, resp) = try? await URLSession.shared.data(for: req) else { throw SkipCheck(reason: "GitHub not reachable (no internet?)") }
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200 else { throw CheckFailed(reason: "GitHub answered HTTP \(status)") }
                let r = newestRelease(fromJSON: data, includePrereleases: true)
                return r.map { "newest signed release \($0.tag)" } ?? "GitHub reachable, no signed release yet"
            },
            Check(id: "log", title: "Log file") { _ in
                Log.write("self-test: log check")
                Log.flush()
                guard let size = try? FileManager.default.attributesOfItem(atPath: Log.file.path)[.size] as? Int, size > 0 else {
                    throw CheckFailed(reason: "the log file could not be written")
                }
                return "\(size) bytes"
            },
        ]
    }

    /// Markers with the characters the export has to replace, one spanned marker.
    nonisolated static func sampleMarkers(_ info: VideoInfo?) -> [Marker] {
        let start = info?.startFrame ?? 900_000
        return [
            Marker(frame: start + 5, user: "Selftest", color: .red, comment: "Schnitt / Ton \"lauter\" – ä ö ü ß"),
            Marker(frame: start + 20, duration: 11, user: "Selftest", color: .blue, comment: "span\nwith a line break"),
        ]
    }

    // MARK: helpers

    nonisolated static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev" }

    /// System info without personal data.
    static func systemInfo() -> [String: String] {
        func sysctl(_ name: String) -> String {
            var size = 0
            sysctlbyname(name, nil, &size, nil, 0)
            var buf = [CChar](repeating: 0, count: max(size, 1))
            sysctlbyname(name, &buf, &size, nil, 0)
            return String(cString: buf)
        }
        func plistVersion(_ path: String) -> String? { NSDictionary(contentsOfFile: path)?["CFBundleShortVersionString"] as? String }
        let fm = FileManager.default
        var s: [String: String] = [:]
        s["macOS"] = ProcessInfo.processInfo.operatingSystemVersionString
        s["model"] = sysctl("hw.model")
        s["cpu"] = sysctl("machdep.cpu.brand_string")
        s["arch"] = sysctl("hw.optional.arm64") == "" ? "x86_64" : "arm64"
        s["memoryGB"] = String(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        s["language"] = Locale.preferredLanguages.first ?? "?"
        s["appLanguage"] = AppSettings.shared.language
        s["appearance"] = AppSettings.shared.dark ? "dark" : "light"
        s["testVersions"] = Updater.shared.betas ? "on" : "off"
        let avid = (try? fm.contentsOfDirectory(atPath: "/Applications"))?.filter { $0.hasPrefix("Avid Media Composer") } ?? []
        s["mediaComposer"] = avid.isEmpty ? "not installed" : avid.compactMap { dir -> String? in
            let items = (try? fm.contentsOfDirectory(atPath: "/Applications/\(dir)")) ?? []
            let app = items.first { $0.hasSuffix(".app") && $0.replacingOccurrences(of: " ", with: "").contains("MediaComposer") }
            return app.flatMap { plistVersion("/Applications/\(dir)/\($0)/Contents/Info.plist") } ?? "installed"
        }.joined(separator: ", ")
        return s
    }

    nonisolated static func logTail(_ lines: Int = 150) -> [String] {
        guard let text = try? String(contentsOf: Log.file, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").suffix(lines).map { anonymize(String($0)) }
    }
}

/// Writes a 2-second QuickTime test video: H.264 320 × 180 at 25 fps, a 440 Hz tone (LPCM), timecode track 10:00:00:00.
enum TestVideo {
    static let fps: Int32 = 25
    static let seconds = 2

    static func write(to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180,
        ])
        let pixels = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180,
        ])
        var asbd = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                                               mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1,
                                               mBitsPerChannel: 16, mReserved: 0)
        var audioFormat: CMAudioFormatDescription?
        try check(CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                                 magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormat), "audio format")
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: audioFormat)
        var tcFormat: CMTimeCodeFormatDescription?
        try check(CMTimeCodeFormatDescriptionCreate(allocator: nil, timeCodeFormatType: kCMTimeCodeFormatType_TimeCode32,
                                                    frameDuration: CMTime(value: 1, timescale: fps), frameQuanta: UInt32(fps),
                                                    flags: 0, extensions: nil, formatDescriptionOut: &tcFormat), "timecode format")
        let timecode = AVAssetWriterInput(mediaType: .timecode, outputSettings: nil, sourceFormatHint: tcFormat)
        for input in [video, audio, timecode] {
            guard writer.canAdd(input) else { throw CheckFailed(reason: "cannot add \(input.mediaType.rawValue) track") }
            writer.add(input)
        }
        video.addTrackAssociation(withTrackOf: timecode, type: AVAssetTrack.AssociationType.timecode.rawValue)
        // without it the writer holds the video back waiting for more timecode/sound to interleave, and never goes on
        for input in [video, audio, timecode] { input.expectsMediaDataInRealTime = true }
        guard writer.startWriting() else { throw writer.error ?? CheckFailed(reason: "cannot write the test video") }
        writer.startSession(atSourceTime: .zero)

        // never hang: each input gets at most 10 s to accept its next sample
        func ready(_ input: AVAssetWriterInput) async throws {
            let deadline = Date().addingTimeInterval(10)
            while !input.isReadyForMoreMediaData {
                guard Date() < deadline, writer.status == .writing else {
                    throw writer.error ?? CheckFailed(reason: "the \(input.mediaType.rawValue) track stopped accepting data")
                }
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        // timecode: one sample, the frame number of 10:00:00:00 (big-endian), lasting the whole clip
        let frames = Int(fps) * seconds
        let start = Int32(10 * 3600 * fps).bigEndian
        let tcBuffer = try sampleBuffer(bytes: withUnsafeBytes(of: start) { Data($0) }) { block in
            var timing = CMSampleTimingInfo(duration: CMTime(value: CMTimeValue(frames), timescale: fps), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
            var size = 4
            var out: CMSampleBuffer?
            try check(CMSampleBufferCreate(allocator: nil, dataBuffer: block, dataReady: true, makeDataReadyCallback: nil, refcon: nil,
                                           formatDescription: tcFormat, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                           sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &out), "timecode buffer")
            return out!
        }

        // video and sound frame by frame, interleaved (the writer waits for both): grey getting lighter, a 440 Hz tone
        let perFrame = 48_000 / Int(fps)
        for i in 0..<frames {
            try await ready(video)
            guard let pool = pixels.pixelBufferPool else { throw CheckFailed(reason: "no pixel buffer pool") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw CheckFailed(reason: "no pixel buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(40 + i * 3), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard pixels.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps)) else {
                throw writer.error ?? CheckFailed(reason: "video frame \(i) not written")
            }

            let first = i * perFrame
            let samples = (first..<first + perFrame).map { Int16(12_000 * sin(2 * Double.pi * 440 * Double($0) / 48_000)) }
            let audioBuffer = try sampleBuffer(bytes: samples.withUnsafeBytes { Data($0) }) { block in
                var out: CMSampleBuffer?
                try check(CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: audioFormat!,
                                                                               sampleCount: perFrame, presentationTimeStamp: CMTime(value: CMTimeValue(first), timescale: 48_000),
                                                                               packetDescriptions: nil, sampleBufferOut: &out), "audio buffer")
                return out!
            }
            try await ready(audio)
            guard audio.append(audioBuffer) else { throw writer.error ?? CheckFailed(reason: "audio not written") }
        }
        video.markAsFinished()
        audio.markAsFinished()
        // one timecode sample for the whole clip
        try await ready(timecode)
        guard timecode.append(tcBuffer) else { throw writer.error ?? CheckFailed(reason: "timecode not written") }
        timecode.markAsFinished()

        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: fps))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CheckFailed(reason: "the test video could not be finished") }
    }

    /// Copies `bytes` into a CMBlockBuffer and hands it to `make`.
    private static func sampleBuffer(bytes: Data, _ make: (CMBlockBuffer) throws -> CMSampleBuffer) throws -> CMSampleBuffer {
        var block: CMBlockBuffer?
        try check(CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes.count, blockAllocator: nil,
                                                     customBlockSource: nil, offsetToData: 0, dataLength: bytes.count, flags: 0,
                                                     blockBufferOut: &block), "block buffer")
        try bytes.withUnsafeBytes { raw in
            try check(CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block!, offsetIntoDestination: 0, dataLength: bytes.count), "block data")
        }
        return try make(block!)
    }

    private static func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw CheckFailed(reason: "\(what): error \(status)") }
    }
}

// MARK: anonymizing

/// Replaces user name, computer name and own folder/file names in paths with short ids (same name → same id).
/// Folder names with spaces are taken whole – better one word too many replaced than a name in the report.
func anonymize(_ text: String) -> String {
    var t = text
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    t = t.replacingOccurrences(of: home, with: "~")
    let user = NSUserName()
    if user.count > 2 { t = t.replacingOccurrences(of: user, with: "<user>") }
    if let host = Host.current().localizedName, host.count > 2 { t = t.replacingOccurrences(of: host, with: "<computer>") }
    if let urlRe = try? NSRegularExpression(pattern: #"\b(smb|afp|nfs|cifs)://[^\s)"',]+"#, options: [.caseInsensitive]) {
        let ns = t as NSString
        for m in urlRe.matches(in: t, range: NSRange(location: 0, length: ns.length)).reversed() {
            let scheme = ns.substring(with: m.range(at: 1))
            let h = SHA256.hash(data: Data(ns.substring(with: m.range).utf8)).prefix(3).map { String(format: "%02x", $0) }.joined()
            t = (t as NSString).replacingCharacters(in: m.range, with: "\(scheme)://<server-\(h)>")
        }
    }
    let keep: Set<String> = ["Library", "Logs", "MarkTheRoughcut", "Application Support", "Volumes", "Users", "Shared",
                             "Macintosh HD", "Desktop", "Documents", "Downloads", "Movies", "tmp", "private", "var", "folders"]
    guard let re = try? NSRegularExpression(pattern: #"(/Volumes/|~/|/Users/)([^\s,:"'|()]+(?: (?!→)[^\s,:"'|()]+)*)"#) else { return t }
    let ns = t as NSString
    var out = ""
    var last = 0
    for m in re.matches(in: t, range: NSRange(location: 0, length: ns.length)) {
        out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
        out += ns.substring(with: m.range(at: 1))
        let parts = ns.substring(with: m.range(at: 2)).split(separator: "/", omittingEmptySubsequences: false).map { part -> String in
            let p = String(part)
            if p.isEmpty || keep.contains(p) || p.hasPrefix("MarkTheRoughcut") || p.hasPrefix("<") { return p }
            let h = SHA256.hash(data: Data(p.utf8)).prefix(3).map { String(format: "%02x", $0) }.joined()
            return "n" + h
        }
        out += parts.joined(separator: "/")
        last = m.range.location + m.range.length
    }
    out += ns.substring(from: last)
    return out
}
