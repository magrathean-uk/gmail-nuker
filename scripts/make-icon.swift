import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for (size, suffix) in [(16,"16x16"), (32,"16x16@2x"), (32,"32x32"), (64,"32x32@2x"), (128,"128x128"), (256,"128x128@2x"), (256,"256x256"), (512,"256x256@2x"), (512,"512x512"), (1024,"512x512@2x")] {
    let pixels = CGFloat(size)
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let inset = pixels * 0.07
    let rect = NSRect(x: inset, y: inset, width: pixels - 2 * inset, height: pixels - 2 * inset)
    let path = NSBezierPath(roundedRect: rect, xRadius: pixels * 0.19, yRadius: pixels * 0.19)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.22, green: 0.59, blue: 0.98, alpha: 1), ending: NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.85, alpha: 1))!
    gradient.draw(in: path, angle: -90)
    let envelope = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pixels * 0.49, weight: .regular))!
    envelope.isTemplate = false
    let symbolRect = NSRect(x: pixels * 0.22, y: pixels * 0.29, width: pixels * 0.56, height: pixels * 0.42)
    let tinted = NSImage(size: envelope.size)
    tinted.lockFocus()
    let glyphRect = NSRect(origin: .zero, size: envelope.size)
    envelope.draw(in: glyphRect)
    NSColor.white.setFill()
    glyphRect.fill(using: .sourceAtop)
    tinted.unlockFocus()
    tinted.draw(in: symbolRect)
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: destination.appendingPathComponent("icon_\(suffix).png"))
}
