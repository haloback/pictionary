// Draws the Colophon app icon: a book cover on a golden-section grid with a vermilion spine.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data? {
    let s = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // Squircle-ish tile
    let tile = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.09, blue: 0.10, alpha: 1))
    ctx.fillPath()
    // Book
    let book = CGRect(x: s * 0.3, y: s * 0.2, width: s * 0.4, height: s * 0.6)
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.04, color: CGColor(gray: 0, alpha: 0.6))
    ctx.setFillColor(CGColor(srgbRed: 0.95, green: 0.93, blue: 0.87, alpha: 1))
    ctx.fill(book)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    // Spine
    ctx.setFillColor(CGColor(srgbRed: 0.894, green: 0.341, blue: 0.180, alpha: 1))
    ctx.fill(CGRect(x: book.minX, y: book.minY, width: book.width * 0.12, height: book.height))
    // Golden line and title block
    let g = book.minY + book.height * 0.618
    ctx.setFillColor(CGColor(srgbRed: 0.08, green: 0.09, blue: 0.10, alpha: 1))
    ctx.fill(CGRect(x: book.minX + book.width * 0.22, y: g, width: book.width * 0.66, height: book.height * 0.08))
    ctx.fill(CGRect(x: book.minX + book.width * 0.22, y: g - book.height * 0.1, width: book.width * 0.44, height: book.height * 0.035))
    ctx.setStrokeColor(CGColor(srgbRed: 0.894, green: 0.341, blue: 0.180, alpha: 1))
    ctx.setLineWidth(max(1, s * 0.006))
    ctx.addEllipse(in: CGRect(x: book.minX + book.width * 0.36, y: book.minY + book.height * 0.14, width: book.width * 0.38, height: book.width * 0.38))
    ctx.strokePath()
    guard let img = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    if let d = draw(px) { try? d.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png")) }
}
