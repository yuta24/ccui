#!/usr/bin/env swift

import AppKit
import Foundation

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Failed to get graphics context")
    }

    let s = CGFloat(size)

    // White background
    context.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // --- Orbital ellipse (gray, tilted) ---
    let orbitCenterX = s * 0.52
    let orbitCenterY = s * 0.48
    let orbitRadiusX = s * 0.36
    let orbitRadiusY = s * 0.18
    let orbitAngle: CGFloat = -25.0 * .pi / 180.0
    let orbitLineWidth = s * 0.022

    context.saveGState()
    context.translateBy(x: orbitCenterX, y: orbitCenterY)
    context.rotate(by: orbitAngle)
    context.setStrokeColor(CGColor(red: 0.78, green: 0.78, blue: 0.78, alpha: 0.7))
    context.setLineWidth(orbitLineWidth)
    context.strokeEllipse(in: CGRect(
        x: -orbitRadiusX, y: -orbitRadiusY,
        width: orbitRadiusX * 2, height: orbitRadiusY * 2
    ))
    context.restoreGState()

    // --- Draw "c" (dark charcoal, left) ---
    let charcoalColor = NSColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0)
    let orangeColor = NSColor(red: 0.93, green: 0.55, blue: 0.0, alpha: 1.0)

    let fontSize = s * 0.42
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

    let cLeftAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: charcoalColor,
    ]
    let cLeftStr = NSAttributedString(string: "c", attributes: cLeftAttrs)
    let cLeftSize = cLeftStr.size()
    let cLeftX = s * 0.18
    let cLeftY = (s - cLeftSize.height) / 2 - s * 0.03

    // --- Draw "c" (orange, right) ---
    let cRightAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: orangeColor,
    ]
    let cRightStr = NSAttributedString(string: "c", attributes: cRightAttrs)
    let cRightSize = cRightStr.size()
    let cRightX = s * 0.42
    let cRightY = (s - cRightSize.height) / 2 - s * 0.03

    // Draw orbit behind the letters first (already done above),
    // then letters on top
    cLeftStr.draw(at: NSPoint(x: cLeftX, y: cLeftY))
    cRightStr.draw(at: NSPoint(x: cRightX, y: cRightY))

    // --- Small orange dot on orbit path (upper right) ---
    // Position on the ellipse at roughly -50 degrees (upper right in screen coords)
    let dotAngleOnEllipse: CGFloat = 55.0 * .pi / 180.0
    let dotLocalX = orbitRadiusX * cos(dotAngleOnEllipse)
    let dotLocalY = orbitRadiusY * sin(dotAngleOnEllipse)
    let dotX = orbitCenterX + dotLocalX * cos(orbitAngle) - dotLocalY * sin(orbitAngle)
    let dotY = orbitCenterY + dotLocalX * sin(orbitAngle) + dotLocalY * cos(orbitAngle)
    let dotRadius = s * 0.022

    context.setFillColor(CGColor(red: 0.93, green: 0.55, blue: 0.0, alpha: 1.0))
    context.fillEllipse(in: CGRect(
        x: dotX - dotRadius, y: dotY - dotRadius,
        width: dotRadius * 2, height: dotRadius * 2
    ))

    // --- Four-pointed star sparkle above the dot ---
    let sparkleX = dotX + s * 0.02
    let sparkleY = dotY + s * 0.07
    let sparkleSize = s * 0.045
    let sparkleSmall = sparkleSize * 0.35

    context.saveGState()
    context.setFillColor(CGColor(red: 0.93, green: 0.55, blue: 0.0, alpha: 1.0))

    let sparklePath = CGMutablePath()
    // Top point
    sparklePath.move(to: CGPoint(x: sparkleX, y: sparkleY + sparkleSize))
    // Right point
    sparklePath.addLine(to: CGPoint(x: sparkleX + sparkleSmall, y: sparkleY + sparkleSmall))
    sparklePath.addLine(to: CGPoint(x: sparkleX + sparkleSize, y: sparkleY))
    // Bottom point
    sparklePath.addLine(to: CGPoint(x: sparkleX + sparkleSmall, y: sparkleY - sparkleSmall))
    sparklePath.addLine(to: CGPoint(x: sparkleX, y: sparkleY - sparkleSize))
    // Left point
    sparklePath.addLine(to: CGPoint(x: sparkleX - sparkleSmall, y: sparkleY - sparkleSmall))
    sparklePath.addLine(to: CGPoint(x: sparkleX - sparkleSize, y: sparkleY))
    sparklePath.addLine(to: CGPoint(x: sparkleX - sparkleSmall, y: sparkleY + sparkleSmall))
    sparklePath.closeSubpath()

    context.addPath(sparklePath)
    context.fillPath()
    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: path))
}

let iconSizes: [(String, Int, Int)] = [
    ("icon_16x16", 16, 16),
    ("icon_16x16@2x", 16, 32),
    ("icon_32x32", 32, 32),
    ("icon_32x32@2x", 32, 64),
    ("icon_128x128", 128, 128),
    ("icon_128x128@2x", 128, 256),
    ("icon_256x256", 256, 256),
    ("icon_256x256@2x", 256, 512),
    ("icon_512x512", 512, 512),
    ("icon_512x512@2x", 512, 1024),
]

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

for (name, _, pixelSize) in iconSizes {
    let image = generateIcon(size: pixelSize)
    let path = "\(outputDir)/\(name).png"
    savePNG(image, to: path, pixelSize: pixelSize)
    print("Generated: \(path) (\(pixelSize)x\(pixelSize))")
}

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try! contentsJSON.write(
    toFile: "\(outputDir)/Contents.json",
    atomically: true,
    encoding: .utf8
)
print("Generated: Contents.json")
