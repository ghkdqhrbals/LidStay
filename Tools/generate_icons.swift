import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("LidStay/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let menuIconDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIcon.imageset", isDirectory: true)
let menuIconOnDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconOn.imageset", isDirectory: true)
let menuIconOffDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconOff.imageset", isDirectory: true)
let menuIconInfiniteDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconInfinite.imageset", isDirectory: true)

try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconOnDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconOffDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconInfiniteDir, withIntermediateDirectories: true)

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

func drawSignatureIcon(size: CGFloat, menuBar: Bool = false) -> NSBitmapImageRep {
    let pixels = Int(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap")
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let scale = size / 1024

    let background = NSBezierPath(roundedRect: rect, xRadius: 228 * scale, yRadius: 228 * scale)
    if !menuBar {
        NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.08, alpha: 1).setFill()
        background.fill()
    }

    let accentColor = menuBar
        ? NSColor.labelColor
        : NSColor(calibratedRed: 0.19, green: 0.96, blue: 0.58, alpha: 1)

    accentColor.set()

    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: 164 * scale, y: 512 * scale))
    eye.curve(
        to: NSPoint(x: 512 * scale, y: 310 * scale),
        controlPoint1: NSPoint(x: 262 * scale, y: 388 * scale),
        controlPoint2: NSPoint(x: 386 * scale, y: 310 * scale)
    )
    eye.curve(
        to: NSPoint(x: 860 * scale, y: 512 * scale),
        controlPoint1: NSPoint(x: 638 * scale, y: 310 * scale),
        controlPoint2: NSPoint(x: 762 * scale, y: 388 * scale)
    )
    eye.curve(
        to: NSPoint(x: 512 * scale, y: 714 * scale),
        controlPoint1: NSPoint(x: 762 * scale, y: 636 * scale),
        controlPoint2: NSPoint(x: 638 * scale, y: 714 * scale)
    )
    eye.curve(
        to: NSPoint(x: 164 * scale, y: 512 * scale),
        controlPoint1: NSPoint(x: 386 * scale, y: 714 * scale),
        controlPoint2: NSPoint(x: 262 * scale, y: 636 * scale)
    )
    eye.close()
    eye.lineWidth = menuBar ? 92 * scale : 78 * scale
    eye.stroke()

    let pupil = NSBezierPath(ovalIn: NSRect(x: 412 * scale, y: 412 * scale, width: 200 * scale, height: 200 * scale))
    pupil.fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawMenuBarIcon(size: CGFloat, active: Bool, infinite: Bool = false) -> NSBitmapImageRep {
    let pixels = Int(size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap")
    }

    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    NSColor.labelColor.set()

    let scale = size / 44

    func drawOpenLids() {
        let upperLid = NSBezierPath()
        upperLid.move(to: NSPoint(x: 4.2 * scale, y: 22.5 * scale))
        upperLid.curve(
            to: NSPoint(x: 39.8 * scale, y: 22.5 * scale),
            controlPoint1: NSPoint(x: 12.4 * scale, y: 31.0 * scale),
            controlPoint2: NSPoint(x: 31.6 * scale, y: 31.0 * scale)
        )
        upperLid.lineWidth = 3.0 * scale
        upperLid.lineCapStyle = .round
        upperLid.stroke()

        let lowerLid = NSBezierPath()
        lowerLid.move(to: NSPoint(x: 7.8 * scale, y: 25.0 * scale))
        lowerLid.curve(
            to: NSPoint(x: 36.2 * scale, y: 25.0 * scale),
            controlPoint1: NSPoint(x: 14.8 * scale, y: 11.8 * scale),
            controlPoint2: NSPoint(x: 29.2 * scale, y: 11.8 * scale)
        )
        lowerLid.lineWidth = 2.2 * scale
        lowerLid.lineCapStyle = .round
        lowerLid.stroke()
    }

    func drawClosedLid() {
        let closedLid = NSBezierPath()
        closedLid.move(to: NSPoint(x: 5.2 * scale, y: 22.2 * scale))
        closedLid.curve(
            to: NSPoint(x: 38.8 * scale, y: 22.2 * scale),
            controlPoint1: NSPoint(x: 13.2 * scale, y: 15.0 * scale),
            controlPoint2: NSPoint(x: 30.8 * scale, y: 15.0 * scale)
        )
        closedLid.lineWidth = 3.0 * scale
        closedLid.lineCapStyle = .round
        closedLid.stroke()
    }

    if infinite {
        drawOpenLids()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16.8 * scale, weight: .heavy),
            .foregroundColor: NSColor.labelColor,
        ]
        let mark = NSAttributedString(string: "∞", attributes: attributes)
        let markSize = mark.size()
        let opticalYOffset = 0.9 * scale
        let markRect = NSRect(
            x: (22.0 * scale) - (markSize.width / 2),
            y: (22.0 * scale) - (markSize.height / 2) + opticalYOffset,
            width: markSize.width,
            height: markSize.height
        )
        mark.draw(in: markRect)
    } else if active {
        drawOpenLids()
    } else {
        drawClosedLid()
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let appIconSpecs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, size) in appIconSpecs {
    try writePNG(drawSignatureIcon(size: size), to: appIconDir.appendingPathComponent(filename))
}

try writePNG(drawSignatureIcon(size: 44, menuBar: true), to: menuIconDir.appendingPathComponent("menubar-icon.png"))
try writePNG(drawMenuBarIcon(size: 52, active: true), to: menuIconOnDir.appendingPathComponent("menubar-icon-on.png"))
try writePNG(drawMenuBarIcon(size: 52, active: false), to: menuIconOffDir.appendingPathComponent("menubar-icon-off.png"))
try writePNG(drawMenuBarIcon(size: 52, active: true, infinite: true), to: menuIconInfiniteDir.appendingPathComponent("menubar-icon-infinite.png"))
