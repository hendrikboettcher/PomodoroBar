// Zeichnet das App-Icon (1024×1024 PNG). Aufruf: swift make_icon.swift <ausgabe.png>
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Kachel nach Apples Icon-Raster: 824 pt Körper, abgerundete Ecken
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.28).cgColor)
rgb(0xE8372C).setFill()
shape.fill()
ctx.restoreGState()

// Tomatenrot mit Verlauf + dezentem Glanz oben
ctx.saveGState()
shape.addClip()
NSGradient(starting: rgb(0xFF6247), ending: rgb(0xD8261C))!.draw(in: body, angle: -90)
NSGradient(starting: rgb(0xFFFFFF, 0.12), ending: rgb(0xFFFFFF, 0))!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
ctx.restoreGState()

// Timer-Ring = Umriss der Tomate
let center = NSPoint(x: 512, y: 478)
let radius: CGFloat = 228
let lineWidth: CGFloat = 72

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = lineWidth
rgb(0xFFFFFF, 0.25).setStroke()
track.stroke()

// Fortschritt: von oben (unter dem Strunk) im Uhrzeigersinn, 70 %
let progress: CGFloat = 0.70
let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true)
arc.lineWidth = lineWidth
arc.lineCapStyle = .round
rgb(0xFFFFFF).setStroke()
arc.stroke()

// Strunk: Kelchblätter, die oben auf dem Ring aufliegen, plus kurzer Stiel
let top = NSPoint(x: center.x, y: center.y + radius)

func sepal(angle: CGFloat, length: CGFloat, width: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: top.x, y: top.y)
    ctx.rotate(by: angle * .pi / 180)
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 0, y: -width * 0.3))
    p.curve(to: NSPoint(x: 0, y: length),
            controlPoint1: NSPoint(x: width, y: length * 0.25), controlPoint2: NSPoint(x: width * 0.45, y: length * 0.8))
    p.curve(to: NSPoint(x: 0, y: -width * 0.3),
            controlPoint1: NSPoint(x: -width * 0.45, y: length * 0.8), controlPoint2: NSPoint(x: -width, y: length * 0.25))
    NSGradient(starting: rgb(0x6FCF4F), ending: rgb(0x2F8F35))!.draw(in: p, angle: -90)
    ctx.restoreGState()
}

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: rgb(0x7A0E08, 0.35).cgColor)
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
// Seitliche Blätter hängen am Ring entlang nach unten, mittlere stehen schräg ab
sepal(angle: 112, length: 170, width: 62)
sepal(angle: -112, length: 170, width: 62)
sepal(angle: 52, length: 130, width: 56)
sepal(angle: -52, length: 130, width: 56)

// Stiel, leicht nach rechts gebogen
let stem = NSBezierPath()
stem.move(to: NSPoint(x: top.x - 20, y: top.y))
stem.curve(to: NSPoint(x: top.x + 22, y: top.y + 118),
           controlPoint1: NSPoint(x: top.x - 22, y: top.y + 60), controlPoint2: NSPoint(x: top.x - 4, y: top.y + 104))
stem.line(to: NSPoint(x: top.x + 50, y: top.y + 100))
stem.curve(to: NSPoint(x: top.x + 20, y: top.y),
           controlPoint1: NSPoint(x: top.x + 26, y: top.y + 80), controlPoint2: NSPoint(x: top.x + 20, y: top.y + 50))
stem.close()
NSGradient(starting: rgb(0x5DBE43), ending: rgb(0x2F8F35))!.draw(in: stem, angle: -90)
ctx.endTransparencyLayer()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
