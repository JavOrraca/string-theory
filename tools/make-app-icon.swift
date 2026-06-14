// Generates the app icon: the phosphor "system online" signal dot inside a
// marker ring (the same ring the fretboard draws for an open string), over a
// soft radial glow on the near-black void background.
//
// Usage: swift tools/make-app-icon.swift <output.png>
// Regenerate the asset with:
//   swift tools/make-app-icon.swift \
//     App/StringTheory/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("could not allocate bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let dim = CGFloat(size)
let center = CGPoint(x: dim / 2, y: dim / 2)
let rgb = CGColorSpaceCreateDeviceRGB()
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [r, g, b, a])!
}
let phosphor = color(0.41, 0.93, 0.58)

// Void background.
ctx.setFillColor(color(0.07, 0.085, 0.10))
ctx.fill(CGRect(x: 0, y: 0, width: dim, height: dim))

// Soft radial glow.
let glow = CGGradient(colorsSpace: rgb,
                      colors: [color(0.41, 0.93, 0.58, 0.45), color(0.41, 0.93, 0.58, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                       endCenter: center, endRadius: 440, options: [])

// Marker ring (the fretboard's open-string marker).
ctx.setStrokeColor(phosphor.copy(alpha: 0.9)!)
ctx.setLineWidth(14)
ctx.strokeEllipse(in: CGRect(x: center.x - 235, y: center.y - 235, width: 470, height: 470))

// Core signal dot.
ctx.setFillColor(phosphor)
ctx.fillEllipse(in: CGRect(x: center.x - 150, y: center.y - 150, width: 300, height: 300))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
