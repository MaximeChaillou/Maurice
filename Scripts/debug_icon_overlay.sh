#!/bin/bash
# Overlay a "DEBUG" banner on the app icon in Debug builds only.
# Works on the built .app bundle — never modifies source files.

set -e

if [ "${CONFIGURATION}" != "Debug" ]; then
    exit 0
fi

APP_ICON_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
ICNS_PATH="${APP_ICON_DIR}/AppIcon.icns"

if [ ! -f "${ICNS_PATH}" ]; then
    exit 0
fi

SRC_ICON_DIR="${SRCROOT}/Resources/Assets.xcassets/AppIcon.appiconset"

# Use Swift to draw the debug banner on a temp copy, then repack the icns
/usr/bin/swift - "${SRC_ICON_DIR}" "${ICNS_PATH}" << 'SWIFT'
import AppKit
import CoreGraphics
import CoreText

let iconDir = CommandLine.arguments[1]
let icnsPath = CommandLine.arguments[2]

let fm = FileManager.default
guard let files = try? fm.contentsOfDirectory(atPath: iconDir) else { exit(0) }

let tmpDir = NSTemporaryDirectory() + "maurice_debug_icons_\(ProcessInfo.processInfo.processIdentifier)"
try? fm.removeItem(atPath: tmpDir)
try! fm.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)

var iconPaths: [String] = []

for filename in files where filename.hasSuffix(".png") {
    let srcPath = "\(iconDir)/\(filename)"
    let dstPath = "\(tmpDir)/\(filename)"

    guard let srcImage = NSImage(contentsOfFile: srcPath),
          let srcRep = srcImage.representations.first else { continue }

    let w = srcRep.pixelsWide
    let h = srcRep.pixelsHigh

    if w < 32 { continue }

    guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 4 * w, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }

    guard let cgImage = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

    let bannerHeight = Int(Double(h) * 0.22)
    ctx.setFillColor(red: 0.9, green: 0.3, blue: 0.0, alpha: 0.85)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: bannerHeight))

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

    guard let result = ctx.makeImage(),
          let dstURL = CFURLCreateFromFileSystemRepresentation(nil, dstPath, dstPath.utf8.count, false),
          let dest = CGImageDestinationCreateWithURL(dstURL, "public.png" as CFString, 1, nil) else { continue }

    CGImageDestinationAddImage(dest, result, nil)
    CGImageDestinationFinalize(dest)
    iconPaths.append(dstPath)
}

// Repack as icns using iconutil
if !iconPaths.isEmpty {
    let iconsetDir = tmpDir + "/AppIcon.iconset"
    try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    // Map PNG filenames to iconset naming convention
    let sizeMap: [(String, String)] = [
        ("icon_16.png", "icon_16x16.png"),
        ("icon_16@2x.png", "icon_16x16@2x.png"),
        ("icon_32.png", "icon_32x32.png"),
        ("icon_32@2x.png", "icon_32x32@2x.png"),
        ("icon_128.png", "icon_128x128.png"),
        ("icon_128@2x.png", "icon_128x128@2x.png"),
        ("icon_256.png", "icon_256x256.png"),
        ("icon_256@2x.png", "icon_256x256@2x.png"),
        ("icon_512.png", "icon_512x512.png"),
        ("icon_512@2x.png", "icon_512x512@2x.png"),
    ]

    for (src, dst) in sizeMap {
        let srcFile = "\(tmpDir)/\(src)"
        let dstFile = "\(iconsetDir)/\(dst)"
        if fm.fileExists(atPath: srcFile) {
            try? fm.copyItem(atPath: srcFile, toPath: dstFile)
        }
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", "-o", icnsPath, iconsetDir]
    try? task.run()
    task.waitUntilExit()
}

try? fm.removeItem(atPath: tmpDir)
print("Debug icon overlay applied to built app.")
SWIFT
