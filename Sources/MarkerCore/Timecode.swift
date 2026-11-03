import Foundation

/// SMPTE timecode counting: frames per second as counted in the timecode (24 for 23.976, 30 for 29.97)
/// and whether drop-frame numbering is used (29.97/59.94 DF, written with ";").
public struct TimecodeFormat: Equatable, Codable, Sendable {
    public var fps: Int
    public var dropFrame: Bool

    public init(fps: Int, dropFrame: Bool = false) {
        self.fps = max(1, fps)
        self.dropFrame = dropFrame && (fps == 30 || fps == 60)
    }

    /// Frames dropped per minute in drop-frame mode (2 at 30 fps, 4 at 60 fps).
    private var dropPerMinute: Int { dropFrame ? fps / 15 : 0 }

    /// Timecode text for a frame count since 00:00:00:00.
    public func string(_ frames: Int) -> String {
        var f = max(0, frames)
        if dropFrame {
            let perMinute = fps * 60 - dropPerMinute
            let perTenMinutes = fps * 600 - 9 * dropPerMinute
            let tens = f / perTenMinutes
            let rest = f % perTenMinutes
            f += 9 * dropPerMinute * tens
            if rest > dropPerMinute {
                f += dropPerMinute * ((rest - dropPerMinute) / perMinute)
            }
        }
        let ff = f % fps
        let s = (f / fps) % 60
        let m = (f / (fps * 60)) % 60
        let h = (f / (fps * 3600)) % 24
        return String(format: "%02d:%02d:%02d%@%02d", h, m, s, dropFrame ? ";" : ":", ff)
    }

    /// Frame count for "HH:MM:SS:FF" (or ";" before the frames). nil if it is no valid timecode.
    public func frames(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0 == ":" || $0 == ";" || $0 == "." })
        guard parts.count == 4, let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]), let ff = Int(parts[3]),
              (0..<24).contains(h), (0..<60).contains(m), (0..<60).contains(s), (0..<fps).contains(ff) else { return nil }
        let totalMinutes = h * 60 + m
        var f = ((h * 3600 + m * 60 + s) * fps) + ff
        if dropFrame {
            f -= dropPerMinute * (totalMinutes - totalMinutes / 10)
        }
        return f
    }
}
