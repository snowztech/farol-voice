// Draws the app icon: Farol's lighthouse, with sound waves for beams.
// Writes assets/icon.png and assets/FarolVoice.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("assets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func polygon(_ ctx: CGContext, _ points: [(CGFloat, CGFloat)]) {
    ctx.beginPath()
    ctx.move(to: CGPoint(x: points[0].0, y: points[0].1))
    points.dropFirst().forEach { ctx.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
    ctx.closePath()
}

/// Drawn on Apple's grid: 1024 canvas, 824 artwork, corner radius about 22.5% of the artwork.
func render(size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0x161c2b), color(0x0a0d14)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // The tower narrows toward the top, with its stripes cut out.
    let white = color(0xf2f4f8)
    let body: [(CGFloat, CGFloat)] = [(392, 232), (632, 232), (580, 560), (444, 560)]
    ctx.saveGState()
    polygon(ctx, body)
    ctx.clip()
    ctx.setFillColor(white)
    ctx.fill(CGRect(x: 300, y: 200, width: 424, height: 400))
    ctx.setFillColor(color(0x10141f))
    for y in [CGFloat(285), 395, 505] {
        polygon(ctx, [(340, y - 34), (700, y + 74), (700, y + 112), (340, y + 4)])
        ctx.fillPath()
    }
    ctx.restoreGState()
    ctx.setFillColor(white)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 340, y: 196, width: 344, height: 36), cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()
    ctx.fill(CGRect(x: 428, y: 560, width: 168, height: 24))

    // The lamp room, lit, under its roof.
    ctx.setFillColor(color(0x71adff))
    ctx.fill(CGRect(x: 456, y: 584, width: 112, height: 84))
    ctx.setFillColor(white)
    ctx.fill(CGRect(x: 456, y: 584, width: 12, height: 84))
    ctx.fill(CGRect(x: 556, y: 584, width: 12, height: 84))
    ctx.fill(CGRect(x: 506, y: 584, width: 12, height: 84))
    polygon(ctx, [(432, 668), (592, 668), (512, 760)])
    ctx.fillPath()

    // Sound waves where Farol's icon has beams, fading as they travel.
    for sign in [CGFloat(1), -1] {
        for (index, height) in [CGFloat(132), 96, 58].enumerated() {
            let x = 512 + sign * (118 + CGFloat(index) * 52)
            let bar = CGRect(x: x - 15, y: 626 - height / 2, width: 30, height: height)
            ctx.setFillColor(color(0x71adff, 1 - CGFloat(index) * 0.22))
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 15, cornerHeight: 15, transform: nil))
            ctx.fillPath()
        }
    }
    ctx.restoreGState()

    // A faint edge keeps a dark tile visible on a dark Dock.
    ctx.addPath(tile)
    ctx.setStrokeColor(color(0xffffff, 0.12))
    ctx.setLineWidth(3)
    ctx.strokePath()

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

try render(size: 512).write(to: assets.appendingPathComponent("icon.png"))

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("FarolVoice.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("FarolVoice.icns").path]
try tool.run()
tool.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
