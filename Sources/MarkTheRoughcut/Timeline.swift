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
                    guard let info = model.info else { return }
                    let n = CGFloat(max(1, info.frameCount - 1))
                    let x = { (i: Int) in CGFloat(i) / n * size.width }
                    // range of the detail timeline
                    let (a, b) = detailRange(model)
                    ctx.stroke(Path(CGRect(x: x(a), y: 0.5, width: max(2, x(b) - x(a)), height: size.height - 1)), with: .color(theme.text.opacity(0.7)), lineWidth: 1)
                    ctx.fill(Path(CGRect(x: x(model.index) - 1, y: 0, width: 2, height: size.height)), with: .color(theme.playhead))
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
        .overlay(Rectangle().stroke(theme.line, lineWidth: 1))
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
                ctx.fill(Path(CGRect(x: 0, y: 22, width: size.width, height: 1)), with: .color(theme.line))
                // waveform: quiet, mirrored around the middle of the lower lane
                if let wave = model.waveform {
                    let top: CGFloat = 46, mid = top + (size.height - top) / 2, half = (size.height - top) / 2 - 3
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
                // markers like in Avid: a coloured dot on the marker lane, spans as a bar to their end
                for m in model.markers {
                    let i = info.index(ofTcFrame: m.frame)
                    guard i + m.duration >= a, i <= b else { continue }
                    let px = x(i)
                    if m.duration > 1 {
                        ctx.fill(Path(roundedRect: CGRect(x: px, y: 30, width: max(2, x(i + m.duration) - px), height: 6), cornerRadius: 3),
                                 with: .color(m.color.color.opacity(0.75)))
                    }
                    let dot = Path(ellipseIn: CGRect(x: px - 6, y: 27, width: 12, height: 12))
                    ctx.fill(dot, with: .color(m.color.color))
                    ctx.stroke(dot, with: .color(.black.opacity(0.55)), lineWidth: 1)
                    if m.id == model.selection {
                        ctx.stroke(Path(ellipseIn: CGRect(x: px - 8.5, y: 24.5, width: 17, height: 17)), with: .color(theme.text), lineWidth: 1.5)
                    }
                }
                // playhead
                let p = x(model.index)
                ctx.fill(Path(CGRect(x: p - 1, y: 0, width: 2, height: size.height)), with: .color(theme.playhead))
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
            .overlay(ScrollCatcher { dx in model.step(dx) })
        }
        .overlay(Rectangle().stroke(theme.line, lineWidth: 1))
        .accessibilityLabel(Text("Timeline"))
    }

    private func marker(at p: CGPoint, width: CGFloat, range: (Int, Int)) -> Marker? {
        guard let info = model.info, p.y > 20, p.y < 46 else { return nil }
        let span = CGFloat(max(1, range.1 - range.0))
        return model.markers.first {
            let x = CGFloat(info.index(ofTcFrame: $0.frame) - range.0) / span * width
            return abs(x - p.x) < 8
        }
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
