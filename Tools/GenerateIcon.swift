// Builds the app icon from its artwork.
//
//   swift Tools/GenerateIcon.swift            writes Resources/AppIcon.iconset and docs/images/icon.png
//   swift Tools/GenerateIcon.swift --flat X   also writes X: the artwork as a squircle that fills its
//                                             1024 px canvas, the shape the website's icons use
//
// Resources/IconArtwork.png is a full-bleed square: a white glyph (a bolt over a USB-C port, and the
// three dots this family of apps shares) on a violet-to-blue gradient. It was generated with Google
// Gemini from a written brief and is used as it came; this script only gives it the shape of a Mac
// icon: Apple's 824 pt rounded square on a 1024 pt canvas, with the template's soft shadow.
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let artworkURL = root.appendingPathComponent("Resources/IconArtwork.png")
guard let artwork = NSImage(contentsOf: artworkURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("Missing Resources/IconArtwork.png\n".utf8))
    exit(1)
}

/// The continuous-corner rounded square macOS draws its own icons with.
func squircle(in rect: CGRect) -> CGPath {
    RoundedRectangle(cornerRadius: rect.width * 0.2237, style: .continuous).path(in: rect).cgPath
}

func render(side: Int, margin: CGFloat, shadow: Bool) -> CGImage {
    let size = CGFloat(side)
    let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    let tile = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: size * margin, dy: size * margin)
    let shape = squircle(in: tile)

    if shadow {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -size * 0.0098), blur: size * 0.0195,
                          color: CGColor(gray: 0, alpha: 0.3))
        context.addPath(shape)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fillPath()
        context.restoreGState()
    }

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(artwork, in: tile)
    // A hairline of light along the top edge, as on every system icon: it keeps the tile from
    // looking cut out of paper on a dark Dock.
    context.addPath(shape)
    context.setLineWidth(max(1, size * 0.004))
    context.replacePathWithStrokedPath()
    context.clip()
    let colors = [CGColor(gray: 1, alpha: 0.28), CGColor(gray: 1, alpha: 0)] as CFArray
    let light = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(light, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])
    context.restoreGState()
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: url)
}

// Apple's grid: the tile is 824 of 1024 points, so the margin is 100/1024 on each side.
let appMargin: CGFloat = 100.0 / 1024.0
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try write(render(side: points * scale, margin: appMargin, shadow: true), to: iconset.appendingPathComponent(name))
}
try write(render(side: 512, margin: appMargin, shadow: true), to: root.appendingPathComponent("docs/images/icon.png"))

if let flag = CommandLine.arguments.firstIndex(of: "--flat"), CommandLine.arguments.count > flag + 1 {
    try write(render(side: 1024, margin: 0, shadow: false), to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
}
print("Icon written.")
