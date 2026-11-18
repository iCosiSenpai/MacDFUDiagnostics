import AppKit
import CoreGraphics
import Foundation

func drawDMGBackground(scale: CGFloat) -> NSImage {
    let baseW: CGFloat = 660
    let baseH: CGFloat = 400
    let width = baseW * scale
    let height = baseH * scale

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.saveGState()
    ctx.scaleBy(x: scale, y: scale)

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Deep Midnight / Apple Silicon Titanium Gradient Background
    let bgColors = [
        CGColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1.0),
        CGColor(red: 0.09, green: 0.14, blue: 0.27, alpha: 1.0),
        CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: 0, y: baseH),
            end: CGPoint(x: baseW, y: 0),
            options: []
        )
    }

    // 2. Subtle Technical Grid Lines
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 0.045))
    ctx.setLineWidth(1.0)
    let gridStep: CGFloat = 30
    for x in stride(from: gridStep, to: baseW, by: gridStep) {
        ctx.move(to: CGPoint(x: x, y: 0))
        ctx.addLine(to: CGPoint(x: x, y: baseH))
    }
    for y in stride(from: gridStep, to: baseH, by: gridStep) {
        ctx.move(to: CGPoint(x: 0, y: y))
        ctx.addLine(to: CGPoint(x: baseW, y: y))
    }
    ctx.strokePath()

    // 3. Soft Radial Glows behind Left Icon (170, 195), Center Bridge (330, 195), and Right Icon (490, 195)
    // Note: Finder's y=205 from top corresponds to y = 400 - 205 = 195 from bottom in CoreGraphics.
    let iconCenterY: CGFloat = baseH - 205.0
    let leftCenter = CGPoint(x: 170, y: iconCenterY)
    let rightCenter = CGPoint(x: 490, y: iconCenterY)
    let midCenter = CGPoint(x: 330, y: iconCenterY)

    let cyanGlow = [
        CGColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.22),
        CGColor(red: 0.0, green: 0.50, blue: 0.95, alpha: 0.0)
    ] as CFArray
    if let g1 = CGGradient(colorsSpace: colorSpace, colors: cyanGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g1, startCenter: leftCenter, startRadius: 0, endCenter: leftCenter, endRadius: 135, options: [])
    }

    let emeraldGlow = [
        CGColor(red: 0.0, green: 0.85, blue: 0.62, alpha: 0.20),
        CGColor(red: 0.0, green: 0.65, blue: 0.45, alpha: 0.0)
    ] as CFArray
    if let g2 = CGGradient(colorsSpace: colorSpace, colors: emeraldGlow, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g2, startCenter: rightCenter, startRadius: 0, endCenter: rightCenter, endRadius: 135, options: [])
    }

    // 4. Glowing Drop-Zone Pedestals for App Icon (170, 195) and Applications (490, 195)
    let pedestalSize: CGFloat = 148
    for (center, strokeColor) in [
        (leftCenter, CGColor(red: 0.25, green: 0.85, blue: 1.0, alpha: 0.42)),
        (rightCenter, CGColor(red: 0.15, green: 0.90, blue: 0.68, alpha: 0.42))
    ] {
        let pRect = CGRect(
            x: center.x - pedestalSize / 2.0,
            y: center.y - pedestalSize / 2.0,
            width: pedestalSize,
            height: pedestalSize
        )
        let pPath = CGPath(roundedRect: pRect, cornerWidth: 32, cornerHeight: 32, transform: nil)
        ctx.addPath(pPath)
        ctx.setFillColor(CGColor(red: 0.06, green: 0.10, blue: 0.20, alpha: 0.55))
        ctx.fillPath()

        ctx.addPath(pPath)
        ctx.setStrokeColor(strokeColor)
        ctx.setLineWidth(1.6)
        ctx.strokePath()
    }

    // 5. Center USB-C / DFU Arrow Bridge between (256, 195) and (404, 195)
    let arrowStartX: CGFloat = 258
    let arrowEndX: CGFloat = 402

    // Glowing dashed track line
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.88, blue: 0.85, alpha: 0.45))
    ctx.setLineWidth(2.5)
    ctx.setLineDash(phase: 0, lengths: [6, 5])
    ctx.move(to: CGPoint(x: arrowStartX, y: iconCenterY))
    ctx.addLine(to: CGPoint(x: arrowEndX - 12, y: iconCenterY))
    ctx.strokePath()
    ctx.restoreGState()

    // Central circular badge with chevron arrow
    let badgeRadius: CGFloat = 22
    let badgeRect = CGRect(
        x: midCenter.x - badgeRadius,
        y: midCenter.y - badgeRadius,
        width: badgeRadius * 2,
        height: badgeRadius * 2
    )
    ctx.fillEllipse(in: badgeRect)
    let badgeGradColors = [
        CGColor(red: 0.0, green: 0.78, blue: 0.96, alpha: 1.0),
        CGColor(red: 0.0, green: 0.84, blue: 0.62, alpha: 1.0)
    ] as CFArray
    ctx.saveGState()
    ctx.addEllipse(in: badgeRect)
    ctx.clip()
    if let bGrad = CGGradient(colorsSpace: colorSpace, colors: badgeGradColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bGrad,
            start: CGPoint(x: badgeRect.minX, y: badgeRect.maxY),
            end: CGPoint(x: badgeRect.maxX, y: badgeRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Draw right arrow chevron inside center badge
    ctx.setStrokeColor(CGColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1.0))
    ctx.setLineWidth(3.2)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: midCenter.x - 5, y: midCenter.y + 8))
    ctx.addLine(to: CGPoint(x: midCenter.x + 6, y: midCenter.y))
    ctx.addLine(to: CGPoint(x: midCenter.x - 5, y: midCenter.y - 8))
    ctx.strokePath()

    // Small pill above center arrow: "TRASCINA IN APPLICAZIONI • DRAG TO INSTALL"
    let centerPara = NSMutableParagraphStyle()
    centerPara.alignment = .center

    let dragText = "TRASCINA  •  DRAG TO INSTALL" as NSString
    let dragAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.45, green: 0.92, blue: 1.0, alpha: 0.9),
        .paragraphStyle: centerPara
    ]
    let dragSize = dragText.size(withAttributes: dragAttrs)
    dragText.draw(
        in: CGRect(x: midCenter.x - dragSize.width / 2.0, y: midCenter.y + 30, width: dragSize.width, height: dragSize.height),
        withAttributes: dragAttrs
    )

    // 6. Top Header Title & Subtitle
    let titleText = "Mac DFU Studio" as NSString
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 25, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: centerPara
    ]
    let titleSize = titleText.size(withAttributes: titleAttrs)
    titleText.draw(
        in: CGRect(x: (baseW - titleSize.width) / 2.0, y: baseH - 54, width: titleSize.width, height: titleSize.height),
        withAttributes: titleAttrs
    )

    let subText = "1-Click USB-C VDM DFU  •  BootROM & Target Disk Diagnostics  •  Apple Silicon (M1–M6) & Intel T2" as NSString
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 0.92),
        .paragraphStyle: centerPara
    ]
    let subSize = subText.size(withAttributes: subAttrs)
    subText.draw(
        in: CGRect(x: (baseW - subSize.width) / 2.0, y: baseH - 76, width: subSize.width, height: subSize.height),
        withAttributes: subAttrs
    )

    // 7. Bottom Footer Pill (well below Finder's icon labels at y=18..36 from bottom)
    let footerPillW: CGFloat = 524
    let footerPillH: CGFloat = 26
    let footerPillRect = CGRect(
        x: (baseW - footerPillW) / 2.0,
        y: 18,
        width: footerPillW,
        height: footerPillH
    )
    let footerPath = CGPath(roundedRect: footerPillRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
    ctx.addPath(footerPath)
    ctx.setFillColor(CGColor(red: 0.04, green: 0.07, blue: 0.14, alpha: 0.75))
    ctx.fillPath()
    ctx.addPath(footerPath)
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.78, blue: 0.95, alpha: 0.28))
    ctx.setLineWidth(1.0)
    ctx.strokePath()

    let footerText = "✓ Developer ID Signed & Apple Notarized   •   macOS 15+ (Apple Silicon Host)" as NSString
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
        .foregroundColor: NSColor(calibratedRed: 0.70, green: 0.88, blue: 0.98, alpha: 0.90),
        .paragraphStyle: centerPara
    ]
    let footerSize = footerText.size(withAttributes: footerAttrs)
    footerText.draw(
        in: CGRect(
            x: footerPillRect.midX - footerSize.width / 2.0,
            y: footerPillRect.midY - footerSize.height / 2.0,
            width: footerSize.width,
            height: footerSize.height
        ),
        withAttributes: footerAttrs
    )

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to url: URL, width: Int, height: Int) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }

    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    if let pngData = rep.representation(using: .png, properties: [:]) {
        try pngData.write(to: url)
    }
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let dmgDir = root.appendingPathComponent("Resources/dmg")
try fm.createDirectory(at: dmgDir, withIntermediateDirectories: true)

let bg1x = drawDMGBackground(scale: 1.0)
let bg2x = drawDMGBackground(scale: 2.0)

let png1xURL = dmgDir.appendingPathComponent("bg-1x.png")
let png2xURL = dmgDir.appendingPathComponent("bg-2x.png")
try savePNG(bg1x, to: png1xURL, width: 660, height: 400)
try savePNG(bg2x, to: png2xURL, width: 1320, height: 800)
print("Generated 1x and 2x DMG backgrounds successfully.")
