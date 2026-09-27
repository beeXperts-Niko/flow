import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024

    // Apple-Raster: 824 pt Inhalt auf 1024 pt Leinwand.
    let rect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 186 * s, yRadius: 186 * s)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    color(0x4F46E5).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x4F46E5), color(0x8B5CF6), color(0xEC4899)])!
        .draw(in: shape, angle: -55)

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
    NSColor.white.withAlphaComponent(0.08).setFill()
    NSBezierPath(ovalIn: NSRect(x: 560 * s, y: 560 * s, width: 520 * s, height: 520 * s)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let heights: [CGFloat] = [0.20, 0.40, 0.66, 0.92, 0.60, 0.36, 0.18]
    let barWidth = 60 * s
    let gap = 34 * s
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    let start = 512 * s - total / 2
    NSGraphicsContext.saveGraphicsState()
    let barShadow = NSShadow()
    barShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    barShadow.shadowBlurRadius = 12 * s
    barShadow.shadowOffset = NSSize(width: 0, height: -5 * s)
    barShadow.set()
    NSColor.white.setFill()
    for (index, height) in heights.enumerated() {
        let barHeight = 540 * s * height
        let bar = NSRect(
            x: start + CGFloat(index) * (barWidth + gap),
            y: 512 * s - barHeight / 2,
            width: barWidth,
            height: barHeight
        )
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, pixels) in sizes {
    try render(pixels).write(to: output.appendingPathComponent(name))
}
