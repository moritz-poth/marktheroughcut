import AppKit
import MarkerCore
import SwiftUI

/// Whole video at a glance: thumbnails, the playhead and the range the detail timeline shows (markers only
/// appear in the timeline below – lines over the pictures were too busy).
/// Click or drag to jump.
struct OverviewBar: View {
    @ObservedObject var model: PlayerModel
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(model.thumbnails.indices, id: \.self) { i in
                        Image(nsImage: model.thumbnails[i]).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: w / CGFloat(max(1, model.thumbnails.count)), height: geo.size.height).clipped()
                    }
                }
                .opacity(0.55)
                Canvas { ctx, size in
                    // frame first, so the range outline below is drawn on top of it and never looks thinner at the edges
                    ctx.stroke(Path(CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)), with: .color(theme.line), lineWidth: 1)
                    guard let info = model.info else { return }
                    let n = CGFloat(max(1, info.frameCount - 1))
                    let x = { (i: Int) in CGFloat(i) / n * size.width }
                    // range of the detail timeline: kept inside the bar, so its outline is always the full 2 px
                    let (a, b) = detailRange(model)
                    let l = min(max(0, x(a).rounded()), size.width - 6), r = max(min(size.width, x(b).rounded()), l + 6)
                    ctx.stroke(Path(CGRect(x: l, y: 0, width: r - l, height: size.height).insetBy(dx: 1, dy: 1)),
                               with: .color(theme.text.opacity(0.85)), lineWidth: 2)
                    ctx.fill(Path(CGRect(x: x(model.index) - 1.5, y: 0, width: 3, height: size.height)), with: .color(theme.playhead))
                }
            }
            .frame(width: w, height: geo.size.height)
            .background(theme.panel)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                model.player.pause()
                model.seek(toFraction: min(max(0, v.location.x / w), 1))
            })
        }
        .accessibilityLabel(Text("Overview"))
    }
}

/// Frame range [first, last] the detail timeline shows: zoomed around the playhead.
@MainActor func detailRange(_ model: PlayerModel, around center: Int? = nil) -> (Int, Int) {
    guard let info = model.info else { return (0, 0) }
    let visible = max(10, Int(Double(info.frameCount) / model.zoom))
    var start = (center ?? model.index) - visible / 2
    start = min(max(0, start), max(0, info.frameCount - visible))
    return (start, min(info.frameCount - 1, start + visible))
}

/// Zoomable timeline around the playhead (↑/↓ zoom), with timecode ruler and markers. Drag or swipe to scrub.
struct DetailTimeline: View {
    @ObservedObject var model: PlayerModel
    let theme: Theme
    /// While dragging the visible range stays put, otherwise it would run away under the pointer.
    @State private var frozen: (Int, Int)?

    var body: some View {
        GeometryReader { geo in
            let range = frozen ?? detailRange(model)
            Canvas { ctx, size in
                guard let info = model.info else { return }
                let (a, b) = range
                let span = CGFloat(max(1, b - a))
                let x = { (i: Int) in (CGFloat(i - a) / span) * size.width }
                // ruler: a label every "step" frames, chosen so labels do not collide
                let fps = info.format.fps
                let steps = [1, 2, 5, 10].map { $0 } + [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800, 3600].map { $0 * fps }
                let step = steps.first { CGFloat($0) / span * size.width >= 110 } ?? steps.last!
                var t = (a / step) * step
                while t <= b {
                    let px = x(t)
                    // only labels that fit completely (no cut-off timecode at the edges)
                    if px >= 0 && px + 84 <= size.width {
                        ctx.fill(Path(CGRect(x: px, y: 0, width: 1, height: 10)), with: .color(theme.faint))
                        ctx.draw(Text(info.format.string(info.tcFrame(ofIndex: t))).font(.mono(10)).foregroundColor(theme.faint),
                                 at: CGPoint(x: px + 4, y: 4), anchor: .topLeading)
                    }
                    t += step
                }
                ctx.fill(Path(CGRect(x: 0, y: Lane.top - 1, width: size.width, height: 1)), with: .color(theme.line))
                ctx.fill(Path(CGRect(x: 0, y: Lane.top, width: size.width, height: Lane.height)), with: .color(theme.lane))
                ctx.fill(Path(CGRect(x: 0, y: Lane.top + Lane.height, width: size.width, height: 1)), with: .color(theme.line))
                // waveform: quiet, mirrored around the middle of the lower lane
                if let wave = model.waveform {
                    let top = Lane.top + Lane.height + 1, mid = top + (size.height - top) / 2, half = (size.height - top) / 2 - 3
                    let secPerPx = Double(span) / Double(size.width) / info.fpsReal
                    let startSec = Double(a) / info.fpsReal
                    var path = Path()
                    var px: CGFloat = 0
                    while px < size.width {
                        let s0 = startSec + Double(px) * secPerPx
                        let h = max(0.5, CGFloat(wave.peak(from: s0, to: s0 + secPerPx)) * half)
                        path.addRect(CGRect(x: px, y: mid - h, width: 1, height: h * 2))
                        px += 1
                    }
                    ctx.fill(path, with: .color(theme.wave))
                }
                // in / out marks: light area between them, a thin line at each mark (like Avid's marks)
                if model.markIn != nil || model.markOut != nil {
                    let l = model.markIn.map(x) ?? 0, r = model.markOut.map { x($0 + 1) } ?? size.width
                    ctx.fill(Path(CGRect(x: l, y: Lane.top, width: max(1, r - l), height: size.height - Lane.top)), with: .color(theme.text.opacity(0.07)))
                    for e in [model.markIn.map(x), model.markOut.map { x($0 + 1) }].compactMap({ $0 }) {
                        ctx.fill(Path(CGRect(x: e - 0.5, y: 0, width: 1, height: size.height)), with: .color(theme.muted))
                    }
                }
                // playhead (under the markers, so a selected marker at the playhead stays visible)
                let ph = x(model.index)
                ctx.fill(Path(CGRect(x: ph - 1.5, y: 0, width: 3, height: size.height)), with: .color(theme.playhead))
                // markers like in Avid: slim upright bars with round ends; overlapping ones move into extra rows so all stay visible
                let (placed, rows) = place(range: range, width: size.width)
                for p in placed {
                    let r = Lane.dot(row: p.row, rows: rows)
                    let m = p.marker
                    // spanned marker: a marker at start and end, joined by a thin line slightly above the middle
                    if m.duration > 1 {
                        ctx.fill(Path(CGRect(x: p.x, y: r.midY - 2, width: max(0, p.end - p.x), height: 1)), with: .color(m.color.color))
                    }
                    let sel = m.id == model.selection
                    for bx in m.duration > 1 ? [p.x, p.end] : [p.x] {
                        // selected: looks pressed in (sunk by 1 pt, darker, shadow at the top edge) with a thin outline
                        let rect = r.offsetBy(dx: bx, dy: sel ? 1 : 0)
                        let dot = Path(roundedRect: rect, cornerRadius: rect.width / 2)
                        ctx.fill(dot, with: .color(m.color.color))
                        if sel {
                            ctx.fill(dot, with: .color(.black.opacity(0.28)))
                            ctx.fill(Path(roundedRect: CGRect(x: rect.minX + 1, y: rect.minY + 1, width: rect.width - 2, height: 2.5), cornerRadius: 1.25),
                                     with: .color(.black.opacity(0.45)))
                            // white on dark markers, dark on light ones, so the outline always shows
                            ctx.stroke(dot, with: .color(m.color.isLight ? Color(white: 0.06) : .white), lineWidth: 1)
                        } else {
                            ctx.stroke(dot, with: .color(.black.opacity(0.7)), lineWidth: 1)
                        }
                    }
                }
            }
            .background(theme.panel)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let r = frozen ?? detailRange(model)
                    if frozen == nil {
                        frozen = r
                        // a click on a marker flag selects it
                        if let m = marker(at: v.startLocation, width: geo.size.width, range: r) {
                            model.jump(to: m)
                            return
                        }
                    }
                    model.player.pause()
                    let f = min(max(0, v.location.x / geo.size.width), 1)
                    model.seek(toIndex: r.0 + Int((f * CGFloat(r.1 - r.0)).rounded()))
                }
                .onEnded { _ in frozen = nil })
            // pointing hand over a marker: it can be clicked
            .onContinuousHover { phase in
                if case .active(let p) = phase, marker(at: p, width: geo.size.width, range: frozen ?? detailRange(model)) != nil {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .overlay(ScrollCatcher { dx in model.step(dx) })
        }
        .overlay(Rectangle().stroke(theme.line, lineWidth: 1))
        .accessibilityLabel(Text("Timeline"))
    }

    private struct Placed { let marker: Marker; let x: CGFloat; let end: CGFloat; let row: Int }

    /// Like separate marker tracks in Avid: each visible marker takes the first row where it does not touch its neighbour.
    private func place(range: (Int, Int), width: CGFloat) -> ([Placed], Int) {
        guard let info = model.info else { return ([], 1) }
        let span = CGFloat(max(1, range.1 - range.0))
        let x = { (i: Int) in CGFloat(i - range.0) / span * width }
        var rowEnd = [CGFloat](repeating: -.infinity, count: Lane.maxRows)
        var out: [Placed] = []
        for m in model.markers.sorted(by: { $0.frame < $1.frame }) {
            let i = info.index(ofTcFrame: m.frame)
            guard i + m.duration - 1 >= range.0, i <= range.1 else { continue }
            let px = x(i), end = m.duration > 1 ? x(i + m.duration - 1) : px
            // shortcut: more than maxRows markers on one spot share the last row, fine for review notes
            let row = rowEnd.firstIndex { $0 + 12 <= px } ?? rowEnd.indices.min { rowEnd[$0] < rowEnd[$1] }!
            rowEnd[row] = max(px, end)
            out.append(Placed(marker: m, x: px, end: end, row: row))
        }
        return (out, (out.map(\.row).max() ?? 0) + 1)
    }

    private func marker(at p: CGPoint, width: CGFloat, range: (Int, Int)) -> Marker? {
        let (placed, rows) = place(range: range, width: width)
        let hit = { (x: CGFloat, row: Int) in Lane.dot(row: row, rows: rows).offsetBy(dx: x, dy: 0).insetBy(dx: -5, dy: -3).contains(p) }
        return placed.first { hit($0.x, $0.row) || hit($0.end, $0.row) }?.marker
    }
}

/// Geometry of the marker lane in the detail timeline (shared by drawing and clicking).
private enum Lane {
    static let top: CGFloat = 21, height: CGFloat = 36, maxRows = 3
    /// Marker bar centred on x = 0 for a row; smaller when the lane is split into more rows.
    static func dot(row: Int, rows: Int) -> CGRect {
        let rowH = height / CGFloat(rows)
        let h = min(8, rowH - 2), w: CGFloat = 4 // a short slim upright bar with round ends (user's pick: 8 × 4)
        return CGRect(x: -w / 2, y: top + rowH * (CGFloat(row) + 0.5) - h / 2, width: w, height: h)
    }
}

/// Trackpad swipes / mouse wheel over the timeline step through frames (SwiftUI on macOS 13 has no scroll events).
struct ScrollCatcher: NSViewRepresentable {
    let onFrames: (Int) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.onFrames = onFrames
        return v
    }

    func updateNSView(_ v: CatcherView, context: Context) { v.onFrames = onFrames }

    final class CatcherView: NSView {
        var onFrames: ((Int) -> Void)?
        private var carry: CGFloat = 0
        override func scrollWheel(with e: NSEvent) {
            // horizontal swipe (or shift + wheel); vertical wheel also scrubs for mice without a horizontal axis
            let d = abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) ? -e.scrollingDeltaX : -e.scrollingDeltaY
            carry += e.hasPreciseScrollingDeltas ? d / 4 : d * 2
            let frames = Int(carry)
            if frames != 0 {
                carry -= CGFloat(frames)
                onFrames?(frames)
            }
        }
        // let clicks and drags through to the SwiftUI gesture below
        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? self : nil
        }
    }
}
