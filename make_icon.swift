// Рисует иконку LayoutFixer — клавишу «A / Ф» (без внешних файлов) и сохраняет набор PNG для iconutil.
import Cocoa

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1) }

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // тень под клавишей
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)

    // корпус (боковая грань клавиши)
    let body = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let r = body.width * 0.2
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    rgb(178, 184, 196).setFill()
    NSBezierPath(roundedRect: body, xRadius: r, yRadius: r).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: rgb(196, 201, 211), ending: rgb(160, 166, 180))!
        .draw(in: NSBezierPath(roundedRect: body, xRadius: r, yRadius: r), angle: -90)

    // верхняя грань — чуть меньше и приподнята
    let top = NSRect(x: body.minX + s * 0.045, y: body.minY + s * 0.085,
                     width: body.width - s * 0.09, height: body.height - s * 0.115)
    let topPath = NSBezierPath(roundedRect: top, xRadius: r * 0.8, yRadius: r * 0.8)
    NSGradient(starting: rgb(255, 255, 255), ending: rgb(232, 235, 241))!.draw(in: topPath, angle: -90)
    rgb(255, 255, 255).withAlphaComponent(0.9).setStroke()
    topPath.lineWidth = max(1, s * 0.004)
    topPath.stroke()

    // буквы, как на клавише Mac: латиница слева сверху, кириллица справа снизу
    let font = NSFont.systemFont(ofSize: s * 0.27, weight: .semibold)
    NSAttributedString(string: "A", attributes: [.font: font, .foregroundColor: rgb(40, 44, 52)])
        .draw(at: NSPoint(x: top.minX + s * 0.09, y: top.midY - s * 0.02))
    NSAttributedString(string: "Ф", attributes: [.font: font, .foregroundColor: rgb(37, 99, 235)])
        .draw(at: NSPoint(x: top.midX + s * 0.01, y: top.minY + s * 0.03))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
