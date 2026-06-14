// Generates the placeholder app icon: the phosphor "system online" signal dot
// on the near-black void background, matching the app's palette.
//
// Usage: swift tools/make-app-icon.swift <output.png>
// Regenerate the asset with:
//   swift tools/make-app-icon.swift \
//     App/StringTheory/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    fatalError("could not allocate bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let dim = CGFloat(size)
let center = CGPoint(x: dim / 2, y: dim / 2)
let phosphor = NSColor(srgbRed: 0.41, green: 0.93, blue: 0.58, alpha: 1)

// Void background.
ctx.setFillColor(NSColor(srgbRed: 0.07, green: 0.085, blue: 0.10, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: dim, height: dim))

// Glow rings, faint to bright.
for (radius, alpha) in [(CGFloat(360), 0.08), (270, 0.14), (200, 0.24)] {
    ctx.setFillColor(phosphor.withAlphaComponent(alpha).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                               width: radius * 2, height: radius * 2))
}

// Core dot.
let core: CGFloat = 150
ctx.setFillColor(phosphor.cgColor)
ctx.fillEllipse(in: CGRect(x: center.x - core, y: center.y - core,
                           width: core * 2, height: core * 2))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("wrote \(outputPath)")
