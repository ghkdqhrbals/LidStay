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

func drawRabbitAppIcon(size: CGFloat) -> NSBitmapImageRep {
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
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 228 * scale, yRadius: 228 * scale).fill()

    let rabbit = NSBezierPath()
    rabbit.appendOval(in: NSRect(x: 284 * scale, y: 250 * scale, width: 456 * scale, height: 420 * scale))
    rabbit.appendOval(in: NSRect(x: 345 * scale, y: 520 * scale, width: 334 * scale, height: 270 * scale))
    rabbit.appendOval(in: NSRect(x: 342 * scale, y: 690 * scale, width: 104 * scale, height: 238 * scale))
    rabbit.appendOval(in: NSRect(x: 578 * scale, y: 690 * scale, width: 104 * scale, height: 238 * scale))
    rabbit.appendOval(in: NSRect(x: 236 * scale, y: 340 * scale, width: 146 * scale, height: 130 * scale))
    NSColor(calibratedRed: 0.20, green: 0.96, blue: 0.58, alpha: 1).setFill()
    rabbit.fill()

    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 425 * scale, y: 632 * scale, width: 34 * scale, height: 38 * scale)).fill()
    NSBezierPath(ovalIn: NSRect(x: 565 * scale, y: 632 * scale, width: 34 * scale, height: 38 * scale)).fill()

    let nose = NSBezierPath()
    nose.move(to: NSPoint(x: 512 * scale, y: 590 * scale))
    nose.line(to: NSPoint(x: 488 * scale, y: 620 * scale))
    nose.line(to: NSPoint(x: 536 * scale, y: 620 * scale))
    nose.close()
    nose.fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawRabbitMenuBarIcon(size: CGFloat, phase: CGFloat, active: Bool, infinite: Bool = false) -> NSBitmapImageRep {
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
    NSColor.labelColor.setFill()
    NSColor.labelColor.setStroke()

    let scale = size / 44
    let hop = active ? sin(max(0, min(1, phase)) * .pi) * 5.2 : 0
    let lean = active ? (phase - 0.5) * 1.6 : 0
    let baseY = 3.8 + hop

    let body = NSBezierPath(ovalIn: NSRect(x: (10.3 + lean) * scale, y: baseY * scale, width: 22.4 * scale, height: 20.0 * scale))
    body.fill()

    let head = NSBezierPath(ovalIn: NSRect(x: (14.3 + lean) * scale, y: (baseY + 13.2) * scale, width: 15.4 * scale, height: 13.8 * scale))
    head.fill()

    let leftEar = NSBezierPath()
    leftEar.move(to: NSPoint(x: (16.6 + lean) * scale, y: (baseY + 24.0) * scale))
    leftEar.curve(
        to: NSPoint(x: (14.2 + lean) * scale, y: (baseY + 37.4) * scale),
        controlPoint1: NSPoint(x: (14.2 + lean) * scale, y: (baseY + 27.8) * scale),
        controlPoint2: NSPoint(x: (13.3 + lean) * scale, y: (baseY + 33.4) * scale)
    )
    leftEar.curve(
        to: NSPoint(x: (20.7 + lean) * scale, y: (baseY + 24.0) * scale),
        controlPoint1: NSPoint(x: (19.5 + lean) * scale, y: (baseY + 36.8) * scale),
        controlPoint2: NSPoint(x: (20.2 + lean) * scale, y: (baseY + 29.5) * scale)
    )
    leftEar.close()
    leftEar.fill()

    let rightEar = NSBezierPath()
    rightEar.move(to: NSPoint(x: (23.1 + lean) * scale, y: (baseY + 24.0) * scale))
    rightEar.curve(
        to: NSPoint(x: (28.2 + lean) * scale, y: (baseY + 37.0) * scale),
        controlPoint1: NSPoint(x: (23.9 + lean) * scale, y: (baseY + 30.4) * scale),
        controlPoint2: NSPoint(x: (25.0 + lean) * scale, y: (baseY + 35.6) * scale)
    )
    rightEar.curve(
        to: NSPoint(x: (27.1 + lean) * scale, y: (baseY + 23.8) * scale),
        controlPoint1: NSPoint(x: (32.1 + lean) * scale, y: (baseY + 33.8) * scale),
        controlPoint2: NSPoint(x: (30.2 + lean) * scale, y: (baseY + 26.7) * scale)
    )
    rightEar.close()
    rightEar.fill()

    let tail = NSBezierPath(ovalIn: NSRect(x: (6.6 + lean) * scale, y: (baseY + 9.0) * scale, width: 7.8 * scale, height: 7.4 * scale))
    tail.fill()

    let rearFoot = NSBezierPath(ovalIn: NSRect(x: (9.2 + lean) * scale, y: (baseY - 1.2) * scale, width: 10.8 * scale, height: 4.8 * scale))
    rearFoot.fill()
    let frontFoot = NSBezierPath(ovalIn: NSRect(x: (24.8 + lean) * scale, y: (baseY - 1.0) * scale, width: 11.2 * scale, height: 4.6 * scale))
    frontFoot.fill()

    if infinite {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.white.setFill()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11.5 * scale, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
        ]
        NSAttributedString(string: "∞", attributes: attributes).draw(in: NSRect(
            x: (15.0 + lean) * scale,
            y: (baseY + 5.0) * scale,
            width: 15.0 * scale,
            height: 12.0 * scale
        ))
        NSGraphicsContext.restoreGraphicsState()
    } else if active {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: (18.2 + lean) * scale, y: (baseY + 18.4) * scale, width: 1.7 * scale, height: 1.8 * scale)).fill()
        NSBezierPath(ovalIn: NSRect(x: (24.0 + lean) * scale, y: (baseY + 18.4) * scale, width: 1.7 * scale, height: 1.8 * scale)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawPixelRabbitAppIcon(size: CGFloat) -> NSBitmapImageRep {
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
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22).fill()

    let unit = size / 16
    func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, color: NSColor) {
        color.setFill()
        NSRect(
            x: CGFloat(x) * unit,
            y: CGFloat(16 - y - h) * unit,
            width: CGFloat(w) * unit,
            height: CGFloat(h) * unit
        ).fill()
    }

    let green = NSColor(calibratedRed: 0.20, green: 0.96, blue: 0.58, alpha: 1)
    let dark = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.09, alpha: 1)
    let glow = NSColor(calibratedRed: 0.20, green: 0.96, blue: 0.58, alpha: 0.18)

    block(5, 1, 2, 5, color: glow)
    block(9, 1, 2, 5, color: glow)
    block(4, 6, 8, 7, color: glow)
    block(3, 9, 10, 4, color: glow)

    block(5, 2, 2, 5, color: green)
    block(9, 2, 2, 5, color: green)
    block(4, 6, 8, 1, color: green)
    block(3, 7, 10, 5, color: green)
    block(4, 12, 8, 1, color: green)
    block(6, 13, 4, 1, color: green)
    block(2, 10, 2, 2, color: green)
    block(11, 10, 3, 2, color: green)
    block(4, 13, 3, 1, color: green)
    block(9, 13, 3, 1, color: green)

    block(6, 8, color: dark)
    block(9, 8, color: dark)
    block(7, 10, 2, 1, color: dark)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawPixelRabbitMenuBarIcon(size: CGFloat, phase: CGFloat, active: Bool, infinite: Bool = false) -> NSBitmapImageRep {
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

    let unit = size / 24
    let t = max(0, min(1, phase))
    let xOffset = active ? Int(round((t - 0.5) * 4)) : 0
    let yOffset = active ? (t == 0.25 || t == 0.75 ? 1 : 0) : 0
    let stretched = active && (t == 0 || t == 1)
    let tucked = active && t == 0.5

    func rectY(_ y: Int, _ h: Int) -> CGFloat {
        CGFloat(24 - y - h + yOffset) * unit
    }

    func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1) {
        NSColor.labelColor.setFill()
        NSRect(
            x: CGFloat(x + xOffset) * unit,
            y: rectY(y, h),
            width: CGFloat(w) * unit,
            height: CGFloat(h) * unit
        ).fill()
    }

    func cutout(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.white.setFill()
        NSRect(
            x: CGFloat(x + xOffset) * unit,
            y: rectY(y, h),
            width: CGFloat(w) * unit,
            height: CGFloat(h) * unit
        ).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    func road(_ x: Int, _ y: Int, _ w: Int = 1) {
        NSColor.labelColor.withAlphaComponent(0.34).setFill()
        NSRect(
            x: CGFloat(x) * unit,
            y: CGFloat(24 - y - 1) * unit,
            width: CGFloat(w) * unit,
            height: unit
        ).fill()
    }

    let roadShift = active ? Int(round(t * 5)) : 0
    for start in stride(from: -roadShift, through: 24, by: 6) {
        road(start, 20, 4)
    }
    road(3, 21, 2)
    road(18, 21, 2)

    if active {
        NSColor.labelColor.withAlphaComponent(0.20).setFill()
        NSRect(x: CGFloat(1 + xOffset) * unit, y: CGFloat(24 - 14) * unit, width: 3 * unit, height: unit).fill()
        if stretched {
            NSRect(x: CGFloat(2 + xOffset) * unit, y: CGFloat(24 - 12) * unit, width: 2 * unit, height: unit).fill()
        }
    }

    block(6, 10, 9, 4)
    block(8, 9, 6, 1)
    block(9, 14, 5, 1)
    block(15, 8, 4, 4)
    block(18, 10, 3, 2)
    block(20, 11, 1, 1)
    block(4, 11, 3, 2)
    block(5, 10, 2, 1)
    block(12, 5, 2, 4)
    block(10, 6, 2, 3)
    block(14, 4, 2, 4)
    block(12, 4, 2, 1)

    if stretched {
        block(5, 15, 5, 1)
        block(14, 16, 6, 1)
        block(4, 16, 2, 1)
        block(18, 17, 3, 1)
    } else if tucked {
        block(7, 15, 3, 1)
        block(13, 15, 3, 1)
        block(8, 16, 1, 2)
        block(15, 16, 1, 2)
    } else if active {
        block(6, 16, 5, 1)
        block(14, 15, 5, 1)
        block(9, 17, 2, 1)
        block(17, 16, 2, 1)
    } else {
        block(7, 15, 4, 1)
        block(14, 15, 4, 1)
        block(9, 16, 2, 1)
        block(16, 16, 2, 1)
    }

    if infinite {
        cutout(8, 11, 1, 1)
        cutout(10, 10, 1, 1)
        cutout(11, 11, 1, 1)
        cutout(12, 10, 1, 1)
        cutout(14, 11, 1, 1)
        cutout(10, 12, 1, 1)
        cutout(12, 12, 1, 1)
    } else if active {
        cutout(17, 9, 1, 1)
    } else {
        cutout(17, 9, 1, 1)
        cutout(8, 12, 5, 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
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
    try writePNG(drawPixelRabbitAppIcon(size: size), to: appIconDir.appendingPathComponent(filename))
}

try writePNG(drawPixelRabbitMenuBarIcon(size: 52, phase: 0, active: false), to: menuIconDir.appendingPathComponent("menubar-icon.png"))
try writePNG(drawPixelRabbitMenuBarIcon(size: 52, phase: 0.35, active: true), to: menuIconOnDir.appendingPathComponent("menubar-icon-on.png"))
try writePNG(drawPixelRabbitMenuBarIcon(size: 52, phase: 0, active: false), to: menuIconOffDir.appendingPathComponent("menubar-icon-off.png"))
try writePNG(drawPixelRabbitMenuBarIcon(size: 52, phase: 0.35, active: true, infinite: true), to: menuIconInfiniteDir.appendingPathComponent("menubar-icon-infinite.png"))
try writeImageSetContents(filename: "menubar-icon.png", to: menuIconDir)
try writeImageSetContents(filename: "menubar-icon-on.png", to: menuIconOnDir)
try writeImageSetContents(filename: "menubar-icon-off.png", to: menuIconOffDir)
try writeImageSetContents(filename: "menubar-icon-infinite.png", to: menuIconInfiniteDir)

for index in 0...4 {
    let phase = CGFloat(index) / 4
    let frameFilename = "menubar-icon-frame-\(index).png"
    try writePNG(
        drawPixelRabbitMenuBarIcon(size: 52, phase: phase, active: index > 0),
        to: menuIconFrameDirs[index].appendingPathComponent(frameFilename)
    )
    try writeImageSetContents(filename: frameFilename, to: menuIconFrameDirs[index])

    let infiniteFrameFilename = "menubar-icon-infinite-frame-\(index).png"
    try writePNG(
        drawPixelRabbitMenuBarIcon(size: 52, phase: phase, active: index > 0, infinite: true),
        to: menuIconInfiniteFrameDirs[index].appendingPathComponent(infiniteFrameFilename)
    )
    try writeImageSetContents(filename: infiniteFrameFilename, to: menuIconInfiniteFrameDirs[index])
}

try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 0.20, green: 0.86, blue: 0.32, alpha: 1)), to: statusDotGreenDir.appendingPathComponent("status-dot-green.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.18, alpha: 1)), to: statusDotOrangeDir.appendingPathComponent("status-dot-orange.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedWhite: 0.58, alpha: 1)), to: statusDotGrayDir.appendingPathComponent("status-dot-gray.png"))
try writePNG(drawStatusDot(size: 24, color: NSColor(calibratedRed: 0.96, green: 0.22, blue: 0.22, alpha: 1)), to: statusDotRedDir.appendingPathComponent("status-dot-red.png"))
