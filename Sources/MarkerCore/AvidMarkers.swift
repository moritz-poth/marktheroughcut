import Foundation

/// Avid Media Composer marker lists (Markers window → Export / Import Markers): one marker per line,
/// tab-separated: user, timecode, track, colour, comment, duration, (empty), colour.
/// Avid writes them in Mac Roman and leaves line breaks inside comments as they are.
public enum AvidMarkers {
    public struct ImportResult: Equatable {
        public var markers: [Marker]
        /// Records that could not be read (shown to the user, never silently dropped).
        public var skipped: Int
    }

    // MARK: import

    public static func read(_ data: Data, format: TimecodeFormat) -> ImportResult {
        let text = decode(data)
        // a record starts at a line beginning with "<user>\t<timecode>\t"; everything up to the next one
        // belongs to it (comments may contain line breaks)
        let start = try! NSRegularExpression(pattern: "^[^\\t\\n]*\\t\\d{2}[:;.]\\d{2}[:;.]\\d{2}[:;.]\\d{2}\\t", options: [.anchorsMatchLines])
        let ns = text as NSString
        let starts = start.matches(in: text, range: NSRange(location: 0, length: ns.length)).map(\.range.location)
        var markers: [Marker] = []
        var skipped = 0
        for (i, s) in starts.enumerated() {
            let end = i + 1 < starts.count ? starts[i + 1] : ns.length
            let record = ns.substring(with: NSRange(location: s, length: end - s)).trimmingCharacters(in: .newlines)
            let f = record.components(separatedBy: "\t")
            guard f.count >= 5, let frame = format.frames(f[1]) else {
                skipped += 1
                continue
            }
            let color = MarkerColor(rawValue: f[3].capitalized) ?? .red
            let duration = f.count > 5 ? Int(f[5].trimmingCharacters(in: .whitespaces)) ?? 1 : 1
            markers.append(Marker(frame: frame, duration: duration, user: f[0], color: color,
                                  comment: f[4], track: f[2].isEmpty ? "V1" : f[2]))
        }
        // text that looks like a list but has no readable record at all
        if markers.isEmpty && starts.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            skipped = text.split(whereSeparator: \.isNewline).count
        }
        return ImportResult(markers: markers.sorted { $0.frame < $1.frame }, skipped: skipped)
    }

    /// UTF-8 if the bytes are valid UTF-8 (lists edited elsewhere), otherwise Mac Roman (what Avid writes).
    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") }
        let s = String(data: data, encoding: .macOSRoman) ?? String(decoding: data, as: UTF8.self)
        return s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: export

    /// Marker list Avid imports completely: plain ASCII, one line per marker.
    public static func write(_ markers: [Marker], format: TimecodeFormat) -> Data {
        var out = ""
        for m in markers.sorted(by: { $0.frame < $1.frame }) {
            let color = m.color.rawValue
            let fields = [safe(m.user), format.string(m.frame), safe(m.track), color, safe(m.comment), String(max(1, m.duration)), "", color]
            out += fields.joined(separator: "\t") + "\n"
        }
        return Data(out.utf8)
    }

    /// Text Avid's marker import swallows without losing the rest of the list: a "/" (and quotes) cut the
    /// comment off, umlauts arrive garbled, and line breaks would start a new record.
    public static func safe(_ text: String) -> String {
        var out = ""
        for c in text.precomposedStringWithCanonicalMapping {
            switch c {
            case "ä": out += "ae"
            case "ö": out += "oe"
            case "ü": out += "ue"
            case "Ä": out += "Ae"
            case "Ö": out += "Oe"
            case "Ü": out += "Ue"
            case "ß": out += "ss"
            case "/", "\\", "|": out += " - "
            case "\"", "“", "”", "„", "«", "»": out += "'"
            case "‘", "’", "‚", "´", "`": out += "'"
            case "–", "—", "·", "•": out += "-"
            case "…": out += "..."
            case "€": out += "EUR"
            case "\n", "\r", "\t", "\u{2028}", "\u{2029}": out += " "
            default:
                if c.isASCII {
                    if let v = c.asciiValue, v >= 32 { out.append(c) }
                } else {
                    // é → e, ñ → n …; anything else (emoji, symbols) is dropped
                    out += String(c).decomposedStringWithCanonicalMapping.unicodeScalars
                        .filter { $0.isASCII && $0.value >= 32 }.map(String.init).joined()
                }
            }
        }
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        return out.trimmingCharacters(in: .whitespaces)
    }
}
