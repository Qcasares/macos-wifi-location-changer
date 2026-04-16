#!/usr/bin/env swift
import AppKit
import Foundation

// Generates AppIcon.icns in build/ from a procedurally drawn Wi-Fi-with-pin glyph.
// No external dependencies — uses CoreGraphics + iconutil (CLT-available).

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build")
let iconset = outDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct Size {
    let pixels: Int
    let filename: String
}

let sizes: [Size] = [
    .init(pixels: 16,   filename: "icon_16x16.png"),
    .init(pixels: 32,   filename: "icon_16x16@2x.png"),
    .init(pixels: 32,   filename: "icon_32x32.png"),
    .init(pixels: 64,   filename: "icon_32x32@2x.png"),
    .init(pixels: 128,  filename: "icon_128x128.png"),
    .init(pixels: 256,  filename: "icon_128x128@2x.png"),
    .init(pixels: 256,  filename: "icon_256x256.png"),
    .init(pixels: 512,  filename: "icon_256x256@2x.png"),
    .init(pixels: 512,  filename: "icon_512x512.png"),
    .init(pixels: 1024, filename: "icon_512x512@2x.png"),
]

func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
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
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded-square background with macOS-like continuous corner.
    let margin = size * 0.08
    let rect = CGRect(x: margin, y: margin, width: size - 2*margin, height: size - 2*margin)
    let cornerRadius = size * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient: blue → indigo.
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.20, green: 0.48, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.12, green: 0.22, blue: 0.72, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )
    ctx.restoreGState()

    // Wi-Fi arcs (white).
    ctx.setStrokeColor(.white)
    ctx.setLineCap(.round)
    let center = CGPoint(x: size * 0.5, y: size * 0.38)
    let arcRadii: [(radius: CGFloat, width: CGFloat)] = [
        (size * 0.34, size * 0.085),
        (size * 0.22, size * 0.085),
    ]
    for arc in arcRadii {
        ctx.setLineWidth(arc.width)
        ctx.beginPath()
        ctx.addArc(
            center: center,
            radius: arc.radius,
            startAngle: CGFloat.pi * 0.25,
            endAngle: CGFloat.pi * 0.75,
            clockwise: true
        )
        ctx.strokePath()
    }
    // Wi-Fi dot.
    ctx.setFillColor(.white)
    ctx.fillEllipse(in: CGRect(
        x: center.x - size * 0.055,
        y: center.y - size * 0.055,
        width: size * 0.11,
        height: size * 0.11
    ))

    // Pin (location marker) above the dot, subtly.
    // Omitted for simplicity — Wi-Fi mark alone reads clearly at all sizes.

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for s in sizes {
    let data = renderIcon(pixels: s.pixels)
    let url = iconset.appendingPathComponent(s.filename)
    try data.write(to: url)
}

// Convert iconset -> icns via iconutil.
let icnsURL = outDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.launchPath = "/usr/bin/iconutil"
proc.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()
if proc.terminationStatus != 0 {
    FileHandle.standardError.write("iconutil failed with status \(proc.terminationStatus)\n".data(using: .utf8)!)
    exit(proc.terminationStatus)
}
print("wrote \(icnsURL.path)")
