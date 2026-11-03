import Foundation

/// The eight marker colours of Avid Media Composer, with the names Avid writes into marker lists.
public enum MarkerColor: String, CaseIterable, Codable, Sendable {
    case red = "Red", green = "Green", blue = "Blue", cyan = "Cyan", magenta = "Magenta", yellow = "Yellow", black = "Black", white = "White"
}

/// One marker. `frame` counts in the file's timecode (frames since 00:00:00:00), so it matches Avid.
public struct Marker: Identifiable, Equatable, Codable, Sendable {
    public var id = UUID()
    public var frame: Int
    /// 1 = point marker; more = span marker.
    public var duration: Int = 1
    public var user: String
    public var color: MarkerColor
    public var comment: String
    /// Avid track the marker sits on ("V1", "A1" …); new markers go on V1.
    public var track: String = "V1"

    public init(frame: Int, duration: Int = 1, user: String, color: MarkerColor, comment: String, track: String = "V1") {
        self.frame = frame
        self.duration = max(1, duration)
        self.user = user
        self.color = color
        self.comment = comment
        self.track = track
    }
}
