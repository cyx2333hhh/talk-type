import AppKit
import Foundation

// Generates the Talk-type app icon (full macOS size set) and custom menu-bar
// template glyphs into Murmur/Assets.xcassets. Run with: swift Murmur-icongen.swift
// This file lives OUTSIDE the Murmur source folder so it is never compiled into the app.

let assetsRoot = FileManager.default.currentDirectoryPath + "/Murmur/Assets.xcassets"
let appIconSet = "\(assetsRoot)/AppIcon.appiconset"
let menuIdleSet = "\(assetsRoot)/MenuBarIcon.imageset"
let menuActiveSet = "\(assetsRoot)/MenuBarIconActive.imageset"
let docsIcon = FileManager.default.currentDirectoryPath + "/docs/icon.png"

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

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha)
}

func talkTracePath(centerX: CGFloat,
                   centerY: CGFloat,
                   halfWidth: CGFloat,
                   amplitude: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: centerX - halfWidth, y: centerY))
    path.addCurve(to: CGPoint(x: centerX, y: centerY),
                  control1: CGPoint(x: centerX - halfWidth * 0.66,
                                    y: centerY + amplitude),
                  control2: CGPoint(x: centerX - halfWidth * 0.34,
                                    y: centerY - amplitude))
    path.addCurve(to: CGPoint(x: centerX + halfWidth, y: centerY),
                  control1: CGPoint(x: centerX + halfWidth * 0.34,
                                    y: centerY + amplitude),
                  control2: CGPoint(x: centerX + halfWidth * 0.66,
                                    y: centerY - amplitude))
    return path
}

// MARK: - App icon

func drawAppIcon(_ cg: CGContext, _ s: CGFloat) {
    let inset = s * 0.068
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // A restrained macOS tile: graphite with a precise rim and deep soft shadow.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                 blur: s * 0.042,
                 color: NSColor.black.withAlphaComponent(0.34).cgColor)
    cg.addPath(shape)
    cg.setFillColor(NSColor.white.cgColor)
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(shape)
    cg.clip()

    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0x090C0D).cgColor, color(0x242A2A).cgColor] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(background,
                          start: CGPoint(x: rect.midX, y: rect.minY),
                          end: CGPoint(x: rect.midX, y: rect.maxY),
                          options: [])
    cg.restoreGState()

    // Hairline rim, visible only where the light meets the graphite.
    cg.saveGState()
    cg.addPath(shape)
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.13).cgColor)
    cg.setLineWidth(max(1, s * 0.0022))
    cg.strokePath()
    cg.restoreGState()

    let tCenterX = rect.midX
    let crownY = rect.midY + rect.height * 0.15
    let stemBottom = rect.midY - rect.height * 0.28
    let slant: CGFloat = 0.025

    // A quiet voice trace and insertion cursor form the letter T.
    cg.saveGState()
    cg.translateBy(x: tCenterX, y: stemBottom)
    cg.concatenate(CGAffineTransform(a: 1, b: 0, c: slant, d: 1, tx: 0, ty: 0))
    cg.translateBy(x: -tCenterX, y: -stemBottom)

    let crown = talkTracePath(centerX: tCenterX,
                              centerY: crownY,
                              halfWidth: rect.width * 0.265,
                              amplitude: rect.height * 0.028)

    cg.setShadow(offset: CGSize(width: 0, height: -rect.width * 0.008),
                 blur: rect.width * 0.018,
                 color: NSColor.black.withAlphaComponent(0.30).cgColor)
    cg.setStrokeColor(color(0xF3F6F4).cgColor)
    cg.setLineWidth(rect.width * 0.062)
    cg.setLineCap(.round)
    cg.addPath(crown)
    cg.strokePath()

    let stemWidth = rect.width * 0.062
    let stemTop = crownY + rect.height * 0.006
    let stemRect = CGRect(x: tCenterX - stemWidth / 2,
                          y: stemBottom,
                          width: stemWidth,
                          height: stemTop - stemBottom)
    let stemPath = CGPath(roundedRect: stemRect,
                          cornerWidth: stemWidth / 2,
                          cornerHeight: stemWidth / 2,
                          transform: nil)
    cg.setShadow(offset: .zero,
                 blur: rect.width * 0.030,
                 color: color(0x5BCDB9, alpha: 0.22).cgColor)
    cg.addPath(stemPath)
    cg.setFillColor(color(0x65D7C3).cgColor)
    cg.fillPath()

    cg.addPath(stemPath)
    cg.clip()
    let stemGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0x3DB9A6).cgColor, color(0xB4F3E8).cgColor] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(stemGradient,
                          start: CGPoint(x: stemRect.midX, y: stemRect.minY),
                          end: CGPoint(x: stemRect.midX, y: stemRect.maxY),
                          options: [])
    cg.restoreGState()
}

// MARK: - Menu bar template glyph

func drawMenuGlyph(_ cg: CGContext, _ s: CGFloat, active: Bool) {
    let centerX = s / 2
    let crownY = s * 0.65
    let crown = talkTracePath(centerX: centerX,
                              centerY: crownY,
                              halfWidth: s * 0.32,
                              amplitude: s * (active ? 0.065 : 0.035))
    let ink = NSColor.black

    cg.saveGState()
    cg.setStrokeColor(ink.cgColor)
    cg.setLineWidth(max(1.4, s * (active ? 0.092 : 0.084)))
    cg.setLineCap(.round)
    cg.addPath(crown)
    cg.strokePath()

    let stemWidth = max(1.4, s * (active ? 0.10 : 0.09))
    let stemRect = CGRect(x: centerX - stemWidth / 2,
                          y: s * (active ? 0.13 : 0.16),
                          width: stemWidth,
                          height: crownY - s * (active ? 0.12 : 0.15))
    cg.addPath(CGPath(roundedRect: stemRect,
                      cornerWidth: stemWidth / 2,
                      cornerHeight: stemWidth / 2,
                      transform: nil))
    cg.setFillColor(ink.cgColor)
    cg.fillPath()
    cg.restoreGState()
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
    if e.px == 1024 {
        try! data.write(to: URL(fileURLWithPath: docsIcon))
    }
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
