#!/usr/bin/env swift
import AppKit
import Foundation

// Draws the app icon procedurally so the repo ships no binary art and the
// mark can be regenerated or re-tinted at any time.

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(size: Int) -> Data {
    let side = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // Squircle
    let margin = side * 0.075
    let rect = NSRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2)
    let radius = rect.width * 0.225
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()

    let gradient = NSGradient(starting: color(0x3E8EF7), ending: color(0x7B5CF0))!
    gradient.draw(in: rect, angle: -62)

    // Soft top-left highlight
    let glow = NSGradient(
        colors: [NSColor.white.withAlphaComponent(0.30), NSColor.white.withAlphaComponent(0.0)]
    )!
    let glowRect = NSRect(
        x: rect.minX - rect.width * 0.2,
        y: rect.maxY - rect.height * 0.55,
        width: rect.width * 1.4,
        height: rect.height * 0.8
    )
    glow.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: NSPoint(x: 0, y: 0))

    // Vignette for depth
    let vignette = NSGradient(
        colors: [NSColor.black.withAlphaComponent(0.0), NSColor.black.withAlphaComponent(0.22)]
    )!
    vignette.draw(in: rect, angle: -90)

    // Notch lip at the top: the app lives there.
    let lipHeight = rect.height * 0.085
    let lipWidth = rect.width * 0.46
    let lipRect = NSRect(
        x: rect.midX - lipWidth / 2,
        y: rect.maxY - lipHeight,
        width: lipWidth,
        height: lipHeight * 2.2
    )
    color(0x0A0A0F, alpha: 0.92).setFill()
    NSBezierPath(roundedRect: lipRect, xRadius: lipHeight, yRadius: lipHeight).fill()

    // Waveform
    let bars: [CGFloat] = [0.26, 0.46, 0.72, 0.94, 0.72, 0.46, 0.26]
    let totalWidth = rect.width * 0.62
    let gap = totalWidth / CGFloat(bars.count * 3)
    let barWidth = gap * 1.55
    let startX = rect.midX - totalWidth / 2 + gap * 0.45
    let baseY = rect.minY + rect.height * 0.30
    let maxHeight = rect.height * 0.34

    NSColor.white.setFill()
    for (index, weight) in bars.enumerated() {
        let height = maxHeight * weight
        let x = startX + CGFloat(index) * (barWidth + gap * 1.2)
        let barRect = NSRect(x: x, y: baseY, width: barWidth, height: height)
        NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }

    NSGraphicsContext.current?.restoreGraphicsState()

    // Hairline edge
    let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
    edge.lineWidth = max(1, side * 0.004)
    NSColor.white.withAlphaComponent(0.16).setStroke()
    edge.stroke()

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for variant in variants {
    let data = drawIcon(size: variant.pixels)
    try data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Wrote Resources/AppIcon.icns")
} else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
