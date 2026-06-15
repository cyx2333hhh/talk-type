import AppKit
import Foundation

// Generates the Murmur app icon (full macOS size set) and custom menu-bar
// template glyphs into Murmur/Assets.xcassets. Run with: swift Murmur-icongen.swift
// This file lives OUTSIDE the Murmur source folder so it is never compiled into the app.

let assetsRoot = FileManager.default.currentDirectoryPath + "/Murmur/Assets.xcassets"
let appIconSet = "\(assetsRoot)/AppIcon.appiconset"
let menuIdleSet = "\(assetsRoot)/MenuBarIcon.imageset"
let menuActiveSet = "\(assetsRoot)/MenuBarIconActive.imageset"

let fm = FileManager.default
for dir in [assetsRoot, appIconSet, menuIdleSet, menuActiveSet] {
    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
}

func render(_ pixels: Int, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    draw(gctx.cgContext, CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func roundedBar(_ cg: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
    let r = CGRect(x: x, y: y, width: w, height: h)
    cg.addPath(CGPath(roundedRect: r, cornerWidth: w / 2, cornerHeight: w / 2, transform: nil))
    cg.fillPath()
}

// MARK: - App icon

func drawAppIcon(_ cg: CGContext, _ s: CGFloat) {
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft drop shadow.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                 blur: s * 0.035,
                 color: NSColor.black.withAlphaComponent(0.28).cgColor)
    cg.addPath(shape)
    cg.setFillColor(NSColor.white.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Flat pure-black fill.
    cg.saveGState()
    cg.addPath(shape)
    cg.clip()
    cg.setFillColor(NSColor.black.cgColor)
    cg.fill(rect)
    cg.restoreGState()

    // White waveform bars.
    let heights: [CGFloat] = [0.30, 0.58, 0.86, 0.50, 0.34]
    let barW = rect.width * 0.078
    let gap = barW * 0.78
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = rect.midX - total / 2
    cg.setFillColor(NSColor.white.cgColor)
    for f in heights {
        let h = rect.height * f
        roundedBar(cg, x: x, y: rect.midY - h / 2, w: barW, h: h)
        x += barW + gap
    }
}

// MARK: - Menu bar template glyph

func drawMenuGlyph(_ cg: CGContext, _ s: CGFloat, active: Bool) {
    let heights: [CGFloat] = active ? [0.45, 0.78, 1.0, 0.66, 0.5]
                                    : [0.34, 0.60, 0.86, 0.54, 0.40]
    let barW = s * 0.115
    let gap = barW * 0.78
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = (s - total) / 2
    let maxH = s * 0.82
    cg.setFillColor(NSColor.black.cgColor) // template: tinted by the system
    for f in heights {
        let h = maxH * f
        roundedBar(cg, x: x, y: (s - h) / 2, w: barW, h: h)
        x += barW + gap
    }
}

// MARK: - Write app icon set

struct IconEntry { let px: Int; let size: String; let scale: String }
let entries: [IconEntry] = [
    .init(px: 16,   size: "16x16",   scale: "1x"),
    .init(px: 32,   size: "16x16",   scale: "2x"),
    .init(px: 32,   size: "32x32",   scale: "1x"),
    .init(px: 64,   size: "32x32",   scale: "2x"),
    .init(px: 128,  size: "128x128", scale: "1x"),
    .init(px: 256,  size: "128x128", scale: "2x"),
    .init(px: 256,  size: "256x256", scale: "1x"),
    .init(px: 512,  size: "256x256", scale: "2x"),
    .init(px: 512,  size: "512x512", scale: "1x"),
    .init(px: 1024, size: "512x512", scale: "2x"),
]

var images: [[String: String]] = []
for e in entries {
    let name = "icon_\(e.size)_\(e.scale).png"
    let data = render(e.px) { cg, s in drawAppIcon(cg, s) }
    try! data.write(to: URL(fileURLWithPath: "\(appIconSet)/\(name)"))
    images.append(["idiom": "mac", "size": e.size, "scale": e.scale, "filename": name])
}
func writeContents(_ dir: String, images: [[String: String]], extra: [String: Any] = [:]) {
    var dict: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
    for (k, v) in extra { dict[k] = v }
    let data = try! JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: URL(fileURLWithPath: "\(dir)/Contents.json"))
}
writeContents(appIconSet, images: images)

// MARK: - Write menu-bar image sets (template)

func writeMenuSet(_ dir: String, prefix: String, active: Bool) {
    let one = render(18) { cg, s in drawMenuGlyph(cg, s, active: active) }
    let two = render(36) { cg, s in drawMenuGlyph(cg, s, active: active) }
    try! one.write(to: URL(fileURLWithPath: "\(dir)/\(prefix).png"))
    try! two.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)@2x.png"))
    let images: [[String: String]] = [
        ["idiom": "universal", "scale": "1x", "filename": "\(prefix).png"],
        ["idiom": "universal", "scale": "2x", "filename": "\(prefix)@2x.png"],
    ]
    writeContents(dir, images: images,
                  extra: ["info": ["version": 1, "author": "xcode"],
                          "properties": ["template-rendering-intent": "template"]])
}
writeMenuSet(menuIdleSet, prefix: "menubar", active: false)
writeMenuSet(menuActiveSet, prefix: "menubar_active", active: true)

// Top-level asset catalog Contents.json
let rootContents = #"{"info":{"author":"xcode","version":1}}"#
try! rootContents.data(using: .utf8)!.write(to: URL(fileURLWithPath: "\(assetsRoot)/Contents.json"))

print("Icons generated at \(assetsRoot)")
