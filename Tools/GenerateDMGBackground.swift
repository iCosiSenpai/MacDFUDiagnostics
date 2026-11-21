// Run from the project root to regenerate the 1x/2x Finder background.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let canvas = CGSize(width: 660, height: 400)
let output = URL(fileURLWithPath: "Resources/dmg/background.tiff")
let rgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func label(_ text: String, size: CGFloat, weight: NSFont.Weight, ink: NSColor,
           x: CGFloat? = nil, y: CGFloat, tracking: CGFloat = 0) {
    let title = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: ink, .kern: tracking
    ])
    title.draw(at: CGPoint(x: x ?? (canvas.width - title.size().width) / 2, y: y))
}

func render(scale: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: 660 * scale, height: 400 * scale,
                        bitsPerComponent: 8, bytesPerRow: 0, space: rgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    defer { NSGraphicsContext.restoreGraphicsState() }

    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(origin: .zero, size: canvas))
    let header = NSBezierPath(roundedRect: NSRect(x: 12, y: 286, width: 636, height: 102),
                              xRadius: 17, yRadius: 17)
    ctx.saveGState()
    header.addClip()
    NSGradient(colors: [color(0x211b40), color(0x413780), color(0x8568bd)])!
        .draw(in: header.bounds, angle: 0)

    // Nested USB-C outlines give the two installers distinct artwork.
    ctx.saveGState()
    ctx.translateBy(x: 556, y: 340)
    ctx.rotate(by: 18 * .pi / 180)
    for band in 0..<7 {
        let inset = CGFloat(band * 12)
        let width = 280 - 2 * inset, height = 193 - 2 * inset
        let port = NSBezierPath(roundedRect: NSRect(x: -width / 2, y: -height / 2,
                                                   width: width, height: height),
                                xRadius: height / 2, yRadius: height / 2)
        NSGradient(colors: [color(0x342957), color(0xad9bdb), color(0xe3cfff)])!
            .draw(in: port, angle: 65)
        color(0x8068aa).setStroke()
        port.lineWidth = 1
        port.stroke()
    }
    ctx.restoreGState()
    label("Mac DFU Studio", size: 32, weight: .semibold, ink: .white, x: 36, y: 329, tracking: -1.3)
    label("macOS 15+   ·   Apple silicon", size: 13, weight: .regular, ink: color(0xe8ddff), x: 37, y: 308)
    ctx.restoreGState()

    // At y=205 from the top, Finder supplies both icons and their filenames.
    for center in [170, 490] {
        let bounds = NSRect(x: center - 108, y: 92, width: 216, height: 184)
        let stage = NSBezierPath(roundedRect: bounds, xRadius: 37, yRadius: 37)
        NSGradient(colors: [color(0xf3eff9), .white])!.draw(in: stage, angle: 85)
        color(0xe4ddec).setStroke()
        stage.lineWidth = 1
        stage.stroke()
    }
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 305, y: 195))
    arrow.line(to: CGPoint(x: 354, y: 195))
    arrow.move(to: CGPoint(x: 345, y: 204))
    arrow.line(to: CGPoint(x: 354, y: 195))
    arrow.line(to: CGPoint(x: 345, y: 186))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0x69518d).setStroke()
    arrow.stroke()

    label("Drag the app to Applications.", size: 16, weight: .semibold, ink: color(0x251d38), y: 36, tracking: -0.3)
    label("Trascina l’app in Applicazioni.", size: 13, weight: .regular, ink: color(0x594d66), y: 18)
    return ctx.makeImage()!
}

let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.tiff.identifier as CFString, 2, nil)!
for scale in [1, 2] {
    let dpi = 72 * scale
    let metadata: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi,
                                    kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5]]
    CGImageDestinationAddImage(destination, render(scale: scale), metadata as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write the installer artwork.") }
