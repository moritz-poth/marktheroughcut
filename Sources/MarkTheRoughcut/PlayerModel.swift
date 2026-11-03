import AVFoundation
import AppKit
import CryptoKit
import MarkerCore
import SwiftUI

/// One open video: playback, position, markers. Markers are saved automatically next to the video.
@MainActor
final class PlayerModel: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var url: URL?
    @Published private(set) var info: VideoInfo?
    /// Frame index of the playhead (0 = first frame of the file).
    @Published private(set) var index = 0
    @Published private(set) var rate: Float = 0
    @Published var markers: [Marker] = [] { didSet { if !loading { save() } } }
    @Published var selection: Marker.ID?
    /// Detail timeline zoom: visible seconds = duration / zoom.
    @Published var zoom: Double = 8
    @Published var notice: String?
    @Published var thumbnails: [NSImage] = []
    @Published var waveform: Waveform?
    /// Marker whose comment field should take the keyboard focus (just created).
    @Published var editing: Marker.ID?
    /// Ask for the user's name (first marker, or "Change Name…").
    @Published var needsName = false
    /// The name was asked because M was pressed: set the marker once the name is there.
    var pendingMarker = false

    @AppStorage("userName") var userName = ""
    @AppStorage("markerColor") var defaultColor = MarkerColor.red.rawValue

    private var observer: Any?
    private var loading = false
    private var storeURL: URL?

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 50), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self, let info = self.info else { return }
                let i = info.index(at: t)
                if i != self.index { self.index = i }
                if self.player.rate != self.rate { self.rate = self.player.rate }
            }
        }
    }

    var tc: String { info.map { $0.format.string($0.tcFrame(ofIndex: index)) } ?? "--:--:--:--" }
    var durationSeconds: Double { info.map { Double($0.frameCount) / $0.fpsReal } ?? 0 }

    // MARK: opening

    func open(_ url: URL) async {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        do {
            guard try await asset.load(.isPlayable) else {
                notice = String(localized: "This file cannot be played. MarkTheRoughcut plays what QuickTime Player plays (e.g. MOV and MP4 with H.264, HEVC or ProRes).")
                return
            }
            let info = try await VideoInfo.load(asset)
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            self.url = url
            self.info = info
            index = 0
            notice = info.hasTimecode ? nil : String(localized: "This file has no timecode. Markers start at 00:00:00:00 – they will only line up in Avid if the clip there starts at 00:00:00:00 too.")
            loadMarkers(for: url)
            makeThumbnails(asset, info)
            waveform = nil
            Task { [weak self] in
                // read off the main thread, assign on it – only if the same video is still open
                let wave = await Task.detached(priority: .utility) { try? await Waveform.load(asset) }.value
                if self?.url == url { self?.waveform = wave }
            }
        } catch {
            notice = String(localized: "The video could not be opened: \(error.localizedDescription)")
        }
    }

    private func makeThumbnails(_ asset: AVURLAsset, _ info: VideoInfo) {
        thumbnails = []
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 160, height: 90)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)
        let count = 24
        let times = (0..<count).map { NSValue(time: CMTime(seconds: durationSeconds * (Double($0) + 0.5) / Double(count), preferredTimescale: 600)) }
        var images = [NSImage?](repeating: nil, count: count)
        var done = 0
        gen.generateCGImagesAsynchronously(forTimes: times) { requested, cg, _, _, _ in
            let img = cg.map { NSImage(cgImage: $0, size: .zero) }
            DispatchQueue.main.async { [weak self] in
                guard let self, let k = times.firstIndex(where: { $0.timeValue == requested }) else { return }
                images[k] = img
                done += 1
                if done == count { self.thumbnails = images.compactMap { $0 } }
            }
        }
    }

    // MARK: transport

    func seek(toIndex i: Int) {
        guard let info else { return }
        let clamped = min(max(0, i), info.frameCount - 1)
        index = clamped
        player.seek(to: info.time(ofIndex: clamped), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(toFraction f: Double) {
        guard let info else { return }
        seek(toIndex: Int((f * Double(info.frameCount - 1)).rounded()))
    }

    func step(_ frames: Int) {
        player.pause()
        let (sum, overflow) = index.addingReportingOverflow(frames)
        seek(toIndex: overflow ? (frames > 0 ? Int.max : 0) : sum)
    }

    func togglePlay() {
        if player.rate != 0 { player.pause() } else { player.rate = 1 }
        rate = player.rate
    }

    /// J/K/L like Avid: L = forward, J = backward, pressing again doubles the speed; K stops.
    func shuttle(_ key: Character) {
        switch key {
        case "k": player.pause()
        case "l": player.rate = player.rate > 0 ? min(player.rate * 2, 8) : 1
        case "j": player.rate = player.rate < 0 ? max(player.rate * 2, -8) : -1
        default: break
        }
        rate = player.rate
    }

    func zoom(in: Bool) {
        zoom = min(max(1, `in` ? zoom * 1.6 : zoom / 1.6), max(1, durationSeconds / 2))
    }

    // MARK: markers

    func addMarker() {
        guard let info else { return }
        player.pause()
        let frame = info.tcFrame(ofIndex: index)
        if let existing = markers.first(where: { $0.frame == frame }) {
            selection = existing.id
            editing = existing.id
            return
        }
        let m = Marker(frame: frame, user: userName, color: MarkerColor(rawValue: defaultColor) ?? .red, comment: "")
        markers.append(m)
        markers.sort { $0.frame < $1.frame }
        selection = m.id
        editing = m.id
    }

    /// Binding to one marker found by id on every access (a position-based binding would write into the
    /// neighbour after an insert).
    func binding(for id: Marker.ID, fallback: Marker) -> Binding<Marker> {
        Binding(
            get: { [weak self] in self?.markers.first { $0.id == id } ?? fallback },
            set: { [weak self] new in
                guard let self, let i = self.markers.firstIndex(where: { $0.id == id }) else { return }
                self.markers[i] = new
            })
    }

    func delete(_ id: Marker.ID) {
        markers.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }

    func jump(to m: Marker) {
        guard let info else { return }
        player.pause()
        selection = m.id
        seek(toIndex: info.index(ofTcFrame: m.frame))
    }

    func jumpMarker(forward: Bool) {
        guard let info else { return }
        let here = info.tcFrame(ofIndex: index)
        let target = forward ? markers.first { $0.frame > here } : markers.last { $0.frame < here }
        if let target { jump(to: target) }
    }

    // MARK: import / export

    func importMarkers(from file: URL) {
        guard let info else { return }
        do {
            let result = AvidMarkers.read(try Data(contentsOf: file), format: info.format)
            let range = info.startFrame..<(info.startFrame + info.frameCount)
            let inside = result.markers.filter { range.contains($0.frame) }
            let outside = result.markers.count - inside.count
            let known = Set(markers.map { "\($0.frame)|\($0.comment)" })
            let new = inside.filter { !known.contains("\($0.frame)|\($0.comment)") }
            markers = (markers + new).sorted { $0.frame < $1.frame }
            var parts = [String(localized: "\(new.count) markers imported.")]
            if outside > 0 { parts.append(String(localized: "\(outside) lie outside this video’s timecode and were left out.")) }
            if result.skipped > 0 { parts.append(String(localized: "\(result.skipped) lines could not be read.")) }
            notice = parts.joined(separator: " ")
        } catch {
            notice = String(localized: "The marker list could not be read: \(error.localizedDescription)")
        }
    }

    func exportData() -> Data? {
        guard let info else { return nil }
        return AvidMarkers.write(markers, format: info.format)
    }

    // MARK: saving (next to the video, or in Application Support if that folder is read-only)

    private func loadMarkers(for video: URL) {
        loading = true
        defer { loading = false }
        let side = video.deletingPathExtension().appendingPathExtension("markers.json")
        let fallback = Self.supportURL(for: video)
        storeURL = FileManager.default.isWritableFile(atPath: video.deletingLastPathComponent().path) ? side : fallback
        let source = [side, fallback].first { FileManager.default.fileExists(atPath: $0.path) }
        markers = source.flatMap { try? JSONDecoder().decode(SavedMarkers.self, from: Data(contentsOf: $0)).markers } ?? []
        selection = nil
    }

    private func save() {
        guard let storeURL else { return }
        do {
            let data = try JSONEncoder.pretty.encode(SavedMarkers(video: url?.lastPathComponent ?? "", markers: markers))
            try data.write(to: storeURL, options: .atomic)
        } catch {
            notice = String(localized: "The markers could not be saved: \(error.localizedDescription)")
        }
    }

    private static func supportURL(for video: URL) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MarkTheRoughcut", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // stable across launches (String.hashValue is randomised per process)
        let key = SHA256.hash(data: Data(video.path.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent("\(video.deletingPathExtension().lastPathComponent)-\(key).markers.json")
    }
}

struct SavedMarkers: Codable {
    var video: String
    var markers: [Marker]
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
