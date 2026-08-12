import AppKit

// Renders a 1024×1024 app icon: a white shield.fill silhouette with a bolt-shaped
// cutout (shield = "Guard", cutout bolt = "Charge"), on a green-to-teal gradient
// rounded square. Usage: swift make-icon.swift <output.png>
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Rounded-square clip (Apple-ish corner radius, matching WhisperType's icon).
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let radius = size * 0.2237
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.clip()

// Diagonal green-to-teal gradient ("healthy battery" / "protected").
let colors = [
    NSColor(srgbRed: 0.24, green: 0.82, blue: 0.55, alpha: 1).cgColor,
    NSColor(srgbRed: 0.04, green: 0.42, blue: 0.52, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

// Build a white shield with a bolt-shaped cutout in an offscreen buffer, then
// composite it onto the gradient so the cutout reveals the gradient beneath.
let glyphSize = NSSize(width: size, height: size)
let badge = NSImage(size: glyphSize)
badge.lockFocus()

let shieldConfig = NSImage.SymbolConfiguration(pointSize: size * 0.62, weight: .semibold)
if let shield = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(shieldConfig) {
    let tinted = NSImage(size: shield.size)
    tinted.lockFocus()
    shield.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: shield.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let shieldOrigin = CGPoint(x: (size - shield.size.width) / 2,
                               y: (size - shield.size.height) / 2 + size * 0.02)
    tinted.draw(at: shieldOrigin, from: .zero, operation: .sourceOver, fraction: 1)
}

let boltConfig = NSImage.SymbolConfiguration(pointSize: size * 0.30, weight: .heavy)
if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(boltConfig) {
    // Rasterize to a properly alpha-masked bitmap first — drawing the raw SF
    // Symbol with a Porter-Duff operation clears its whole bounding box
    // instead of just the glyph silhouette.
    let boltMask = NSImage(size: bolt.size)
    boltMask.lockFocus()
    bolt.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: bolt.size).fill(using: .sourceAtop)
    boltMask.unlockFocus()

    let boltOrigin = CGPoint(x: (size - bolt.size.width) / 2,
                             y: (size - bolt.size.height) / 2 + size * 0.02)
    // .destinationOut punches a bolt-shaped hole out of the shield beneath it.
    boltMask.draw(at: boltOrigin, from: .zero, operation: .destinationOut, fraction: 1)
}

badge.unlockFocus()
badge.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr); exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
