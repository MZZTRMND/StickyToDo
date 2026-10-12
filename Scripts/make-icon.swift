import AppKit

// Turns a 1024x1024 full-bleed render of Assets/AppIcon.svg into a macOS
// .iconset: the artwork is clipped to its rounded square (transparent
// corners), scaled to Apple's 824x824 grid with a 100px margin so it sits at
// the same size as other Dock icons, given the template's soft drop shadow,
// and written out at every size iconutil needs.
//
// Usage: swift make-icon.swift <render-1024.png> <output.iconset>

let arguments = CommandLine.arguments
guard arguments.count == 3, let render = NSImage(contentsOfFile: arguments[1]) else {
    FileHandle.standardError.write("usage: swift make-icon.swift <render-1024.png> <output.iconset>\n".data(using: .utf8)!)
    exit(1)
}
let iconsetURL = URL(fileURLWithPath: arguments[2])

/// Corner radius of the rounded square in Assets/AppIcon.svg, on its 1024 canvas.
let artworkCornerRadius: CGFloat = 212
/// Apple's macOS icon grid: the shape is 824pt on a 1024pt canvas.
let gridSize: CGFloat = 824

func bitmap(_ pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    return rep
}

func drawing(into rep: NSBitmapImageRep, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    body()
    NSGraphicsContext.restoreGraphicsState()
}

// 1. Clip the full-bleed render to its rounded square. The SVG renderer that
//    handles its drop-shadow filter (WebKit, via qlmanage) fills the corners
//    with white, so they're cut away here.
let fullCanvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
let artwork = bitmap(1024)
drawing(into: artwork) {
    NSBezierPath(roundedRect: fullCanvas, xRadius: artworkCornerRadius, yRadius: artworkCornerRadius).addClip()
    render.draw(in: fullCanvas)
}
let artworkImage = NSImage(size: fullCanvas.size)
artworkImage.addRepresentation(artwork)

// 2. Place it on the 824 grid with the template's shadow.
let master = bitmap(1024)
drawing(into: master) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)   // 10px down
    shadow.shadowBlurRadius = 10
    shadow.set()
    let margin = (1024 - gridSize) / 2
    artworkImage.draw(in: NSRect(x: margin, y: margin, width: gridSize, height: gridSize))
}
let masterImage = NSImage(size: fullCanvas.size)
masterImage.addRepresentation(master)

// 3. Every size an .iconset needs.
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = bitmap(pixels)
        drawing(into: rep) {
            masterImage.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        }
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconsetURL.appendingPathComponent(name))
    }
}
