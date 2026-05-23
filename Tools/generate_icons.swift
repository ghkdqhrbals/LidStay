import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("LidStay/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let menuIconDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIcon.imageset", isDirectory: true)
let menuIconOnDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconOn.imageset", isDirectory: true)
let menuIconOffDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconOff.imageset", isDirectory: true)
let menuIconInfiniteDir = root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconInfinite.imageset", isDirectory: true)
let menuIconFrameDirs = (0...4).map { index in
    root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconFrame\(index).imageset", isDirectory: true)
}
let menuIconInfiniteFrameDirs = (0...4).map { index in
    root.appendingPathComponent("LidStay/Assets.xcassets/MenuBarIconInfiniteFrame\(index).imageset", isDirectory: true)
}
let statusDotGreenDir = root.appendingPathComponent("LidStay/Assets.xcassets/StatusDotGreen.imageset", isDirectory: true)
let statusDotOrangeDir = root.appendingPathComponent("LidStay/Assets.xcassets/StatusDotOrange.imageset", isDirectory: true)
let statusDotGrayDir = root.appendingPathComponent("LidStay/Assets.xcassets/StatusDotGray.imageset", isDirectory: true)
let statusDotRedDir = root.appendingPathComponent("LidStay/Assets.xcassets/StatusDotRed.imageset", isDirectory: true)

try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconOnDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconOffDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: menuIconInfiniteDir, withIntermediateDirectories: true)
for dir in menuIconFrameDirs + menuIconInfiniteFrameDirs {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}
try FileManager.default.createDirectory(at: statusDotGreenDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: statusDotOrangeDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: statusDotGrayDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: statusDotRedDir, withIntermediateDirectories: true)

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

func writeImageSetContents(filename: String, to url: URL) throws {
    let contents: [String: Any] = [
        "images": [
            [
                "filename": filename,
                "idiom": "universal",
                "scale": "2x",
            ],
        ],
        "info": [
            "author": "xcode",
            "version": 1,
        ],
        "properties": [
            "template-rendering-intent": "template",
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url.appendingPathComponent("Contents.json"))
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
        NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1).setFill()
        background.fill()
    }

    let accentColor = menuBar
        ? NSColor.labelColor
        : NSColor(calibratedRed: 0.19, green: 0.96, blue: 0.58, alpha: 1)

    accentColor.set()

    let upperLid = NSBezierPath()
    upperLid.move(to: NSPoint(x: 164 * scale, y: 518 * scale))
    upperLid.curve(
        to: NSPoint(x: 860 * scale, y: 518 * scale),
        controlPoint1: NSPoint(x: 318 * scale, y: 712 * scale),
        controlPoint2: NSPoint(x: 706 * scale, y: 712 * scale)
    )
    upperLid.lineWidth = menuBar ? 94 * scale : 86 * scale
    upperLid.lineCapStyle = .round
    upperLid.stroke()

    let lowerLid = NSBezierPath()
    lowerLid.move(to: NSPoint(x: 228 * scale, y: 555 * scale))
    lowerLid.curve(
        to: NSPoint(x: 796 * scale, y: 555 * scale),
        controlPoint1: NSPoint(x: 360 * scale, y: 298 * scale),
        controlPoint2: NSPoint(x: 664 * scale, y: 298 * scale)
    )
    lowerLid.lineWidth = menuBar ? 70 * scale : 64 * scale
    lowerLid.lineCapStyle = .round
    lowerLid.stroke()

    if !menuBar {
        NSColor(calibratedRed: 0.15, green: 0.78, blue: 0.48, alpha: 0.20).setStroke()
        let glow = NSBezierPath()
        glow.move(to: NSPoint(x: 252 * scale, y: 515 * scale))
        glow.curve(
            to: NSPoint(x: 772 * scale, y: 515 * scale),
            controlPoint1: NSPoint(x: 374 * scale, y: 384 * scale),
            controlPoint2: NSPoint(x: 650 * scale, y: 384 * scale)
        )
        glow.lineWidth = 26 * scale
        glow.lineCapStyle = .round
        glow.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawAnimatedMenuBarIcon(size: CGFloat, openness: CGFloat, infinite: Bool = false) -> NSBitmapImageRep {
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
    let t = min(1, max(0, openness))

    let eyeCenterX: CGFloat = 22.0
    let eyeWidthScale: CGFloat = 1.0

    func eyeX(_ x: CGFloat) -> CGFloat {
        eyeCenterX + (x - 22.0) * eyeWidthScale
    }

    func eyeInteriorPath() -> NSBezierPath {
        let opennessOffset = max(0.04, t)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: eyeX(7.2) * scale, y: (22.2 + 0.1 * opennessOffset) * scale))
        path.curve(
            to: NSPoint(x: eyeX(36.8) * scale, y: (22.2 + 0.1 * opennessOffset) * scale),
            controlPoint1: NSPoint(x: eyeX(13.6) * scale, y: (15.0 + 15.1 * opennessOffset) * scale),
            controlPoint2: NSPoint(x: eyeX(30.4) * scale, y: (15.0 + 15.1 * opennessOffset) * scale)
        )
        path.curve(
            to: NSPoint(x: eyeX(7.2) * scale, y: (22.2 + 0.1 * opennessOffset) * scale),
            controlPoint1: NSPoint(x: eyeX(29.6) * scale, y: (22.2 - 9.6 * opennessOffset) * scale),
            controlPoint2: NSPoint(x: eyeX(14.4) * scale, y: (22.2 - 9.6 * opennessOffset) * scale)
        )
        path.close()
        return path
    }

    func drawInfinityPupil() {
        let opacity = min(1, max(0, (t - 0.18) / 0.35))
        guard opacity > 0 else {
            return
        }

        NSColor.labelColor.withAlphaComponent(0.95 * opacity).setFill()
        eyeInteriorPath().fill()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.white.withAlphaComponent(opacity).setFill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 17.2 * scale, weight: .heavy),
            .foregroundColor: NSColor.white.withAlphaComponent(opacity),
            .paragraphStyle: paragraphStyle,
            .kern: -0.4 * scale,
        ]
        NSAttributedString(string: "∞", attributes: attributes).draw(in: NSRect(
            x: 8.0 * scale,
            y: 10.9 * scale,
            width: 28.0 * scale,
            height: 22.0 * scale
        ))
        NSGraphicsContext.restoreGraphicsState()
    }

    func drawLids() {
        if t <= 0.01 {
            let closedLid = NSBezierPath()
            closedLid.move(to: NSPoint(x: eyeX(5.2) * scale, y: 22.2 * scale))
            closedLid.curve(
                to: NSPoint(x: eyeX(38.8) * scale, y: 22.2 * scale),
                controlPoint1: NSPoint(x: eyeX(13.2) * scale, y: 15.0 * scale),
                controlPoint2: NSPoint(x: eyeX(30.8) * scale, y: 15.0 * scale)
            )
            closedLid.lineWidth = 3.0 * scale
            closedLid.lineCapStyle = .round
            closedLid.stroke()
            return
        }

        let upperLid = NSBezierPath()
        upperLid.move(to: NSPoint(x: eyeX(4.2) * scale, y: (22.2 + 0.3 * t) * scale))
        upperLid.curve(
            to: NSPoint(x: eyeX(39.8) * scale, y: (22.2 + 0.3 * t) * scale),
            controlPoint1: NSPoint(x: eyeX(12.4) * scale, y: (15.0 + 16.0 * t) * scale),
            controlPoint2: NSPoint(x: eyeX(31.6) * scale, y: (15.0 + 16.0 * t) * scale)
        )
        upperLid.lineWidth = 3.0 * scale
        upperLid.lineCapStyle = .round
        upperLid.stroke()

        let lowerLid = NSBezierPath()
        lowerLid.move(to: NSPoint(x: eyeX(7.8) * scale, y: (22.2 + 2.8 * t) * scale))
        lowerLid.curve(
            to: NSPoint(x: eyeX(36.2) * scale, y: (22.2 + 2.8 * t) * scale),
            controlPoint1: NSPoint(x: eyeX(14.8) * scale, y: (22.2 - 10.4 * t) * scale),
            controlPoint2: NSPoint(x: eyeX(29.2) * scale, y: (22.2 - 10.4 * t) * scale)
        )
        lowerLid.lineWidth = (1.4 + 0.8 * t) * scale
        lowerLid.lineCapStyle = .round
        lowerLid.stroke()
    }

    if infinite {
        drawInfinityPupil()
    }
    drawLids()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawMenuBarIcon(size: CGFloat, active: Bool, infinite: Bool = false) -> NSBitmapImageRep {
    drawAnimatedMenuBarIcon(size: size, openness: active ? 1 : 0, infinite: infinite)
}

func drawStatusDot(size: CGFloat, color: NSColor) -> NSBitmapImageRep {
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

    color.setFill()
    let inset = size * 0.16
    NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset)).fill()

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
try writeImageSetContents(filename: "menubar-icon.png", to: menuIconDir)
try writeImageSetContents(filename: "menubar-icon-on.png", to: menuIconOnDir)
try writeImageSetContents(filename: "menubar-icon-off.png", to: menuIconOffDir)
try writeImageSetContents(filename: "menubar-icon-infinite.png", to: menuIconInfiniteDir)

for index in 0...4 {
    let openness = CGFloat(index) / 4
    let frameFilename = "menubar-icon-frame-\(index).png"
    try writePNG(
        drawAnimatedMenuBarIcon(size: 52, openness: openness),
        to: menuIconFrameDirs[index].appendingPathComponent(frameFilename)
    )
    try writeImageSetContents(filename: frameFilename, to: menuIconFrameDirs[index])

    let infiniteFrameFilename = "menubar-icon-infinite-frame-\(index).png"
    try writePNG(
        drawAnimatedMenuBarIcon(size: 52, openness: openness, infinite: true),
        to: menuIconInfiniteFrameDirs[index].appendingPathComponent(infiniteFrameFilename)
    )
    try writeImageSetContents(filename: infiniteFrameFilename, to: menuIconInfiniteFrameDirs[index])
}

try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 0.20, green: 0.86, blue: 0.32, alpha: 1)), to: statusDotGreenDir.appendingPathComponent("status-dot-green.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.18, alpha: 1)), to: statusDotOrangeDir.appendingPathComponent("status-dot-orange.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedWhite: 0.58, alpha: 1)), to: statusDotGrayDir.appendingPathComponent("status-dot-gray.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 0.96, green: 0.22, blue: 0.22, alpha: 1)), to: statusDotRedDir.appendingPathComponent("status-dot-red.png"))
