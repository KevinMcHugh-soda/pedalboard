#!/usr/bin/env swift
//
// make-icon.swift — render the app icon at every macOS size.
//
// Draws a guitar stompbox seen from above: two knobs, a red LED, and the big
// footswitch you stamp on — the one-press switch the app is. Pure
// CoreGraphics, no assets, no dependencies — runs under plain `swift`. The
// Makefile runs `iconutil -c icns build/AppIcon.iconset` on the PNGs this
// writes.
//
// `--dev` draws the dev variant's icon into build/AppIconDev.iconset: the same
// pedal with an orange DEV band across the foot, so the copy built from a
// working checkout is never mistaken for the installed one.

import AppKit

let isDev = CommandLine.arguments.contains("--dev")
let iconsetDir = isDev ? "build/AppIconDev.iconset" : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(
    atPath: iconsetDir, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func fillCircle(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: the rounded square sits inside a ~10% margin. The
    // tile is the pedal's enclosure, in stompbox orange-red enamel.
    let inset = size * 0.1
    let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = tile.width * 0.225
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [rgb(0.93, 0.33, 0.22), rgb(0.74, 0.18, 0.14)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])

    let unit = tile.width
    let small = pixels <= 32

    // Knobs across the top — dropped at small sizes, where only the
    // footswitch reads.
    if !small {
        for fraction in [0.3, 0.7] {
            let center = CGPoint(x: tile.minX + unit * fraction, y: tile.minY + unit * 0.76)
            fillCircle(ctx, center: center, radius: unit * 0.105, color: rgb(0.12, 0.12, 0.14))
            ctx.setStrokeColor(rgb(0.95, 0.95, 0.95))
            ctx.setLineWidth(unit * 0.025)
            ctx.setLineCap(.round)
            ctx.move(to: center)
            ctx.addLine(to: CGPoint(x: center.x - unit * 0.05, y: center.y + unit * 0.065))
            ctx.strokePath()
        }
        // The LED, lit: the pedal is engaged.
        let led = CGPoint(x: tile.midX, y: tile.minY + unit * 0.58)
        fillCircle(ctx, center: led, radius: unit * 0.05, color: rgb(1, 0.25, 0.2, 0.35))
        fillCircle(ctx, center: led, radius: unit * 0.028, color: rgb(1, 0.85, 0.8))
    }

    // The footswitch: a chrome ring around a dark cap.
    let switchCenter = CGPoint(x: tile.midX, y: tile.minY + unit * (small ? 0.5 : (isDev ? 0.39 : 0.33)))
    let switchRadius = unit * (small ? 0.26 : 0.17)
    fillCircle(ctx, center: switchCenter, radius: switchRadius, color: rgb(0.86, 0.87, 0.9))
    fillCircle(ctx, center: switchCenter, radius: switchRadius * 0.72, color: rgb(0.55, 0.57, 0.62))
    fillCircle(ctx, center: switchCenter, radius: switchRadius * 0.5, color: rgb(0.78, 0.8, 0.84))

    if isDev { drawDevBand(in: tile, pixels: pixels, context: ctx) }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// An orange band across the foot of the tile, lettered DEV where there is
/// room to read it. Drawn while the tile's rounded clip is still in force.
func drawDevBand(in tile: CGRect, pixels: Int, context ctx: CGContext) {
    let band = CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: tile.height * 0.2)
    ctx.setFillColor(rgb(0.96, 0.62, 0.13))
    ctx.fill(band)
    guard pixels >= 64 else { return }
    let font = NSFont.systemFont(ofSize: band.height * 0.62, weight: .heavy)
    let text = NSAttributedString(
        string: "DEV",
        attributes: [.font: font, .foregroundColor: NSColor.white, .kern: band.height * 0.06])
    let size = text.size()
    text.draw(at: CGPoint(x: band.midX - size.width / 2, y: band.midY - size.height / 2))
}

for variant in variants {
    let url = URL(fileURLWithPath: "\(iconsetDir)/\(variant.name)")
    try render(pixels: variant.pixels).write(to: url)
}
print("✓ wrote \(variants.count) icon sizes to \(iconsetDir)")
