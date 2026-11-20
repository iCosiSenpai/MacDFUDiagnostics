import AppKit
import CoreGraphics
import Foundation

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = cardRect.width * 0.225

    // 1. Drop shadow & Squircle background
    ctx.saveGState()
    let path = CGPath(roundedRect: cardRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.11, green: 0.16, blue: 0.32, alpha: 1.0),
        CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }

    // Subtle radial cyan/blue glow in center
    let glowColors = [
        CGColor(red: 0.0, green: 0.72, blue: 1.0, alpha: 0.28),
        CGColor(red: 0.0, green: 0.45, blue: 0.95, alpha: 0.0)
    ] as CFArray
    if let radial = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        let center = CGPoint(x: size * 0.5, y: size * 0.54)
        ctx.drawRadialGradient(radial, startCenter: center, startRadius: 0, endCenter: center, endRadius: size * 0.42, options: [])
    }

    // 2. Circuit trace lines radiating from center silicon chip
    ctx.setStrokeColor(CGColor(red: 0.20, green: 0.78, blue: 1.0, alpha: 0.32))
    ctx.setLineWidth(size * 0.012)
    ctx.setLineCap(.round)

    let chipSize = size * 0.42
    let chipRect = CGRect(
        x: (size - chipSize) / 2.0,
        y: (size - chipSize) / 2.0 + size * 0.04,
        width: chipSize,
        height: chipSize
    )

    let pinCount = 5
    for i in 0..<pinCount {
        let fraction = CGFloat(i + 1) / CGFloat(pinCount + 1)
        // Left pins
        let yPos = chipRect.minY + chipRect.height * fraction
        ctx.move(to: CGPoint(x: chipRect.minX - size * 0.08, y: yPos))
        ctx.addLine(to: CGPoint(x: chipRect.minX, y: yPos))
        // Right pins
        ctx.move(to: CGPoint(x: chipRect.maxX, y: yPos))
        ctx.addLine(to: CGPoint(x: chipRect.maxX + size * 0.08, y: yPos))
        // Top pins
        let xPos = chipRect.minX + chipRect.width * fraction
        ctx.move(to: CGPoint(x: xPos, y: chipRect.maxY))
        ctx.addLine(to: CGPoint(x: xPos, y: chipRect.maxY + size * 0.07))
        // Bottom pins
        ctx.move(to: CGPoint(x: xPos, y: chipRect.minY - size * 0.07))
        ctx.addLine(to: CGPoint(x: xPos, y: chipRect.minY))
    }
    ctx.strokePath()

    // 3. Silicon Chip Die Body
    let chipCorner = chipSize * 0.16
    let chipPath = CGPath(roundedRect: chipRect, cornerWidth: chipCorner, cornerHeight: chipCorner, transform: nil)
    ctx.saveGState()
    ctx.addPath(chipPath)
    ctx.clip()

    let chipColors = [
        CGColor(red: 0.16, green: 0.22, blue: 0.36, alpha: 1.0),
        CGColor(red: 0.08, green: 0.11, blue: 0.20, alpha: 1.0)
    ] as CFArray
    if let chipGrad = CGGradient(colorsSpace: colorSpace, colors: chipColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            chipGrad,
            start: CGPoint(x: chipRect.minX, y: chipRect.maxY),
            end: CGPoint(x: chipRect.maxX, y: chipRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Chip Metallic Border
    ctx.addPath(chipPath)
    ctx.setStrokeColor(CGColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 0.85))
    ctx.setLineWidth(size * 0.016)
    ctx.strokePath()

    // 4. Lightning / Pulse Bolt + "DFU" inside the Silicon Die
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let dfuFont = NSFont.systemFont(ofSize: size * 0.125, weight: .black)
    let dfuAttrs: [NSAttributedString.Key: Any] = [
        .font: dfuFont,
        .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.92, blue: 1.0, alpha: 1.0),
        .paragraphStyle: paragraph
    ]
    let dfuText = "DFU" as NSString
    let dfuSize = dfuText.size(withAttributes: dfuAttrs)
    let dfuRect = CGRect(
        x: chipRect.midX - dfuSize.width / 2.0,
        y: chipRect.midY - dfuSize.height / 2.0 + size * 0.03,
        width: dfuSize.width,
        height: dfuSize.height
    )
    dfuText.draw(in: dfuRect, withAttributes: dfuAttrs)

    let subFont = NSFont.monospacedSystemFont(ofSize: size * 0.048, weight: .bold)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(calibratedRed: 0.72, green: 0.86, blue: 1.0, alpha: 0.9),
        .paragraphStyle: paragraph
    ]
    let subText = "M1–M6 • T2" as NSString
    let subSize = subText.size(withAttributes: subAttrs)
    let subRect = CGRect(
        x: chipRect.midX - subSize.width / 2.0,
        y: chipRect.minY + size * 0.045,
        width: subSize.width,
        height: subSize.height
    )
    subText.draw(in: subRect, withAttributes: subAttrs)

    // 5. Bottom USB-C Connector Pill Badge
    let pillWidth = size * 0.56
    let pillHeight = size * 0.095
    let pillRect = CGRect(
        x: (size - pillWidth) / 2.0,
        y: cardRect.minY + size * 0.065,
        width: pillWidth,
        height: pillHeight
    )
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillHeight / 2.0, cornerHeight: pillHeight / 2.0, transform: nil)
    ctx.addPath(pillPath)
    ctx.setFillColor(CGColor(red: 0.0, green: 0.82, blue: 0.62, alpha: 0.95))
    ctx.fillPath()

    let pillFont = NSFont.systemFont(ofSize: size * 0.042, weight: .heavy)
    let pillAttrs: [NSAttributedString.Key: Any] = [
        .font: pillFont,
        .foregroundColor: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.10, alpha: 1.0),
        .paragraphStyle: paragraph
    ]
    let pillText = "USB-C VDM • DIAG" as NSString
    let pillTextSize = pillText.size(withAttributes: pillAttrs)
    let pillTextRect = CGRect(
        x: pillRect.midX - pillTextSize.width / 2.0,
        y: pillRect.midY - pillTextSize.height / 2.0,
        width: pillTextSize.width,
        height: pillTextSize.height
    )
    pillText.draw(in: pillTextRect, withAttributes: pillAttrs)

    // Outer Squircle Border Highlight
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.35))
    ctx.setLineWidth(size * 0.015)
    ctx.strokePath()

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to url: URL, pixelSize: Int) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }

    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try pngData.write(to: url)
    }
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent("Resources/AppIcon.iconset")
let docsImgDir = root.appendingPathComponent("docs/images")
try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
try fm.createDirectory(at: docsImgDir, withIntermediateDirectories: true)

let masterImage = drawAppIcon(size: 1024)
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    try savePNG(masterImage, to: iconsetDir.appendingPathComponent(name), pixelSize: px)
}
try savePNG(masterImage, to: docsImgDir.appendingPathComponent("icon.png"), pixelSize: 512)
print("Generated iconset and PNG assets successfully.")
