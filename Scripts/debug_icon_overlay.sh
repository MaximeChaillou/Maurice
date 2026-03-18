#!/bin/bash
# Overlay a "DEBUG" banner on the app icon in Debug builds only.
# Restores the original icon for Release builds.

set -e

ICON_DIR="${SRCROOT}/Resources/Assets.xcassets/AppIcon.appiconset"
BACKUP_DIR="${ICON_DIR}/.originals"

if [ "${CONFIGURATION}" != "Debug" ]; then
    if [ -d "${BACKUP_DIR}" ]; then
        cp "${BACKUP_DIR}"/*.png "${ICON_DIR}/"
        rm -rf "${BACKUP_DIR}"
    fi
    exit 0
fi

# Back up originals (only if not already backed up)
if [ ! -d "${BACKUP_DIR}" ]; then
    mkdir -p "${BACKUP_DIR}"
    cp "${ICON_DIR}"/*.png "${BACKUP_DIR}/"
fi

# Use Swift to draw the debug banner via CoreGraphics
/usr/bin/swift - "${ICON_DIR}" "${BACKUP_DIR}" << 'SWIFT'
import AppKit
import CoreGraphics
import CoreText

let iconDir = CommandLine.arguments[1]
let backupDir = CommandLine.arguments[2]

let fm = FileManager.default
guard let files = try? fm.contentsOfDirectory(atPath: backupDir) else { exit(0) }

for filename in files where filename.hasSuffix(".png") {
    let srcPath = "\(backupDir)/\(filename)"
    let dstPath = "\(iconDir)/\(filename)"

    guard let srcImage = NSImage(contentsOfFile: srcPath),
          let srcRep = srcImage.representations.first else { continue }

    let w = srcRep.pixelsWide
    let h = srcRep.pixelsHigh

    // Skip tiny icons
    if w < 32 { continue }

    guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 4 * w, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }

    // Draw original
    guard let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

    // Draw banner
    let bannerHeight = Int(Double(h) * 0.22)
    ctx.setFillColor(red: 0.9, green: 0.3, blue: 0.0, alpha: 0.85)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: bannerHeight))

    // Draw text
    let fontSize = Double(bannerHeight) * 0.65
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let attrStr = NSAttributedString(string: "DEBUG", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, [])

    let tx = (Double(w) - bounds.width) / 2.0
    let ty = (Double(bannerHeight) - bounds.height) / 2.0

    ctx.textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, ctx)

    // Save
    guard let result = ctx.makeImage(),
          let dstURL = CFURLCreateFromFileSystemRepresentation(nil, dstPath, dstPath.utf8.count, false),
          let dest = CGImageDestinationCreateWithURL(dstURL, "public.png" as CFString, 1, nil) else { continue }

    CGImageDestinationAddImage(dest, result, nil)
    CGImageDestinationFinalize(dest)
}

print("Debug icon overlay applied.")
SWIFT
