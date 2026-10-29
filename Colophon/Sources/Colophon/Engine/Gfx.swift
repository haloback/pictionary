import AppKit
import CoreGraphics
import CoreImage

/// Low-level drawing helpers shared by the renderer, generators and effects.
enum Gfx {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let gray = CGColorSpaceCreateDeviceGray()

    static let ci: CIContext = CIContext(options: [
        .outputColorSpace: sRGB,
        .cacheIntermediates: false
    ])

    /// Premultiplied RGBA bitmap context, bottom-left origin.
    static func context(_ w: Int, _ h: Int) -> CGContext? {
        let ctx = CGContext(data: nil, width: max(1, w), height: max(1, h), bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.interpolationQuality = .high
        ctx?.setShouldAntialias(true)
        return ctx
    }

    /// 8-bit gray context without alpha, used for masks.
    static func grayContext(_ w: Int, _ h: Int) -> CGContext? {
        let ctx = CGContext(data: nil, width: max(1, w), height: max(1, h), bitsPerComponent: 8, bytesPerRow: 0,
                            space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)
        ctx?.interpolationQuality = .high
        return ctx
    }

    /// Draws an image the right way up into a context that has been flipped to a top-left origin.
    static func drawUpright(_ img: CGImage, in r: CGRect, _ ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(img, in: CGRect(origin: .zero, size: r.size))
        ctx.restoreGState()
    }

    static func render(_ image: CIImage, _ w: Int, _ h: Int) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        return ci.createCGImage(image.cropped(to: rect), from: rect, format: .RGBA8, colorSpace: sRGB)
    }

    static func render(_ image: CIImage, extent: CGRect) -> CGImage? {
        ci.createCGImage(image.cropped(to: extent), from: extent, format: .RGBA8, colorSpace: sRGB)
    }

    /// Linear gradient across `rect`. Angle uses the top-left convention: 90 runs top to bottom.
    static func linearGradient(_ ctx: CGContext, _ rect: CGRect, _ colors: [RGBA], angle: Double, locations: [CGFloat]? = nil) {
        guard !colors.isEmpty else { return }
        let cols = colors.count == 1 ? [colors[0], colors[0]] : colors
        let cgColors = cols.map(\.cgColor) as CFArray
        let gradient: CGGradient?
        if let locations {
            gradient = CGGradient(colorsSpace: sRGB, colors: cgColors, locations: locations)
        } else {
            gradient = CGGradient(colorsSpace: sRGB, colors: cgColors, locations: nil)
        }
        guard let g = gradient else { return }
        let rad = angle * .pi / 180
        // y is flipped because the context is bottom-left.
        let v = CGVector(dx: cos(rad), dy: -sin(rad))
        let half = abs(rect.width * v.dx) / 2 + abs(rect.height * v.dy) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let start = CGPoint(x: c.x - v.dx * half, y: c.y - v.dy * half)
        let end = CGPoint(x: c.x + v.dx * half, y: c.y + v.dy * half)
        ctx.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    /// Smooth value noise built from stacked, upscaled random grids. Deterministic per seed.
    static func valueNoise(_ w: Int, _ h: Int, cells: Int, seed: Int, octaves: Int = 4) -> CGImage? {
        guard let ctx = grayContext(w, h) else { return nil }
        var rng = SeededRNG(seed: seed)
        ctx.setFillColor(gray: 0.5, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        var cx = max(2, cells)
        for o in 0..<octaves {
            let cy = max(2, Int((Double(cx) * Double(h) / Double(max(1, w))).rounded()))
            let bytes = (0..<(cx * cy)).map { _ in UInt8(rng.unit() * 255) }
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                  let img = CGImage(width: cx, height: cy, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: cx,
                                    space: gray, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            else { break }
            ctx.setAlpha(o == 0 ? 1 : 0.45)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            cx *= 2
        }
        guard let raw = ctx.makeImage() else { return nil }
        // Smooth away grid artifacts left by the upscale.
        let sigma = Double(max(w, h)) / Double(max(2, cells)) * 0.18
        let blurred = FX.blur(CIImage(cgImage: raw), CGFloat(sigma))
        return render(blurred, w, h)
    }
}
