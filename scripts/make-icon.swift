// App icon: play button in a ring, a small marker in the playhead blue on top. Writes an .iconset folder.
import AppKit

func rgb(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}

func draw(_ c: CGContext, px: CGFloat) {
    c.scaleBy(x: px / 1024, y: px / 1024)
    // thin lines would vanish at 16/32 px: keep them at least ~1.6 device pixels
    let minLine = 1.6 * 1024 / px
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0, 0.45))
    c.addPath(body); c.setFillColor(rgb(0x2c3035)); c.fillPath()
    c.restoreGState()
    c.saveGState(); c.addPath(body); c.clip()
    c.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [rgb(0x2c3035), rgb(0x16181a)] as CFArray, locations: nil)!,
                         start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    c.restoreGState()
    c.addPath(body); c.setStrokeColor(rgb(0xffffff, 0.08)); c.setLineWidth(max(3, minLine / 2)); c.strokePath()

    let fg = rgb(0xe6e7e8)
    c.addEllipse(in: CGRect(x: 262, y: 262, width: 500, height: 500)); c.setStrokeColor(fg); c.setLineWidth(max(36, minLine)); c.strokePath()
    // play triangle with rounded corners
    let s: CGFloat = 230, cx: CGFloat = 530, cy: CGFloat = 512, r: CGFloat = 15
    let tri = CGMutablePath()
    tri.move(to: CGPoint(x: cx - s * 0.38 + r, y: cy + s / 2 - r * 1.6))
    tri.addLine(to: CGPoint(x: cx + s * 0.5 - r * 1.8, y: cy))
    tri.addLine(to: CGPoint(x: cx - s * 0.38 + r, y: cy - s / 2 + r * 1.6))
    tri.closeSubpath()
    c.addPath(tri); c.setFillColor(fg); c.fillPath()
    c.addPath(tri); c.setStrokeColor(fg); c.setLineWidth(30); c.setLineJoin(.round); c.strokePath()
    // marker on the ring, in the playhead blue
    let m = CGRect(x: 512 - 23, y: 762 - 55, width: 46, height: 110)
    let mp = CGPath(roundedRect: m, cornerWidth: 23, cornerHeight: 23, transform: nil)
    c.addPath(mp); c.setFillColor(rgb(0x226e8e)); c.fillPath()
    c.addPath(mp); c.setStrokeColor(rgb(0, 0.75)); c.setLineWidth(max(8, minLine / 2)); c.strokePath()
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(c, px: CGFloat(px))
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
    }
}
