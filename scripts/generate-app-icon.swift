#!/usr/bin/env swift
import AppKit

// Reproducible vector artwork based on the nine violet tiles in the README banner.
// Run from the repository root: swift scripts/generate-app-icon.swift
let output = URL(fileURLWithPath: "Return Launchpad/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let sizes = [16, 32, 64, 128, 256, 512, 1024]
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: alpha)
}
for size in sizes {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let plate = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(20, 18, 42).setFill()
    plate.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(17, 17, 36), ending: color(53, 39, 88))!.draw(in: plate, angle: -35)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    plate.lineWidth = 2
    plate.stroke()
    let lavender = NSGradient(starting: color(184, 164, 255), ending: color(125, 145, 255))!
    for row in 0..<3 {
        for column in 0..<3 {
            let tile = NSBezierPath(roundedRect: NSRect(x: 209 + column * 220, y: 209 + row * 220, width: 166, height: 166), xRadius: 42, yRadius: 42)
            lavender.draw(in: tile, angle: -55)
            NSColor.white.withAlphaComponent(0.14).setStroke()
            tile.lineWidth = 1.5
            tile.stroke()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon-\(size).png"))
}
let entries: [[String: String]] = [16, 32, 128, 256, 512].flatMap { points in
    [1, 2].map { scale in
        ["filename": "icon-\(points * scale).png", "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"]
    }
}
let manifest: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Generated all 10 macOS icon slots (16–1024 px).")
