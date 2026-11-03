// Draws the app icon: Icon/photo.jpg, full-bleed, with a small swap-arrows badge.
// Photo: "Aaron Swartz Headshot 2007" by Aaron Swartz, public domain, via Wikimedia Commons.
// Usage: swift Icon/make-icon.swift <photo.jpg> <output.png>   (1024x1024)
import AppKit

let size: CGFloat = 1024
let args = CommandLine.arguments
let photoPath = args.count > 1 ? args[1] : "Icon/photo.jpg"
let out = args.count > 2 ? args[2] : "Icon/icon-1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Full-bleed square: macOS 26+ masks it into the app-icon shape itself. A pre-rounded tile
// with margins gets shrunk into a gray frame instead.
let tile = CGRect(x: 0, y: 0, width: size, height: size)

// Photo, scaled to the canvas width and cropped `cropTop` source pixels from the top.
let photo = NSImage(contentsOfFile: photoPath)!
let cg = photo.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let cropTop: CGFloat = 40
let scale = tile.width / CGFloat(cg.width)
let drawH = CGFloat(cg.height) * scale
ctx.interpolationQuality = .high
ctx.draw(cg, in: CGRect(x: tile.minX, y: tile.maxY + cropTop * scale - drawH, width: tile.width, height: drawH))

// Two arrows chasing each other counter-clockwise around `c`.
func arrow(center c: CGPoint, radius r: CGFloat, width w: CGFloat, from a0: CGFloat, to a1: CGFloat, colors: [UInt32]) {
    let rad = { (d: CGFloat) in d * .pi / 180 }
    let k = w / 46  // arrowhead scale relative to the original design
    let path = CGMutablePath()
    path.addArc(center: c, radius: r, startAngle: rad(a0), endAngle: rad(a1), clockwise: false)
    let t = rad(a1)
    let p = CGPoint(x: c.x + r * cos(t), y: c.y + r * sin(t))
    let tan = CGPoint(x: -sin(t), y: cos(t)), nrm = CGPoint(x: cos(t), y: sin(t))
    let head = CGMutablePath()
    head.move(to: CGPoint(x: p.x + tan.x * 80 * k, y: p.y + tan.y * 80 * k))
    head.addLine(to: CGPoint(x: p.x + (nrm.x * 62 - tan.x * 6) * k, y: p.y + (nrm.y * 62 - tan.y * 6) * k))
    head.addLine(to: CGPoint(x: p.x - (nrm.x * 62 + tan.x * 6) * k, y: p.y - (nrm.y * 62 + tan.y * 6) * k))
    head.closeSubpath()

    let shape = CGMutablePath()
    shape.addPath(path.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10))
    shape.addPath(head)

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let g = CGGradient(colorsSpace: nil, colors: colors.map { rgb($0) } as CFArray, locations: [0, 1])!
    let s = CGPoint(x: c.x + r * cos(rad(a0)), y: c.y + r * sin(rad(a0)))
    ctx.drawLinearGradient(g, start: s, end: p, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// Swap badge in the bottom-right corner.
let bc = CGPoint(x: 830, y: 194)
let br: CGFloat = 140
let badge = CGRect(x: bc.x - br, y: bc.y - br, width: br * 2, height: br * 2)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: rgb(0x000000, 0.45))
ctx.setFillColor(rgb(0x14203A))
ctx.fillEllipse(in: badge)
ctx.restoreGState()
ctx.setStrokeColor(rgb(0xFFFFFF, 0.9))
ctx.setLineWidth(10)
ctx.strokeEllipse(in: badge.insetBy(dx: 5, dy: 5))
arrow(center: bc, radius: 77, width: 22, from: 205, to: 330, colors: [0x2BC0E4, 0x5EF0FF])  // cyan
arrow(center: bc, radius: 77, width: 22, from: 25, to: 150, colors: [0xFF7A3D, 0xFFC24B])   // orange

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
