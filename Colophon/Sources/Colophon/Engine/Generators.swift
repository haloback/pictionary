import CoreGraphics
import CoreImage

/// Vector shapes, in bottom-left (Core Graphics) coordinates.
enum ShapeRenderer {
    static func path(_ kind: ShapeKind, in r: CGRect, corner: CGFloat = 0.08) -> CGPath {
        let p = CGMutablePath()
        switch kind {
        case .rectangle, .rule, .frame:
            p.addRect(r)
        case .roundedRect:
            let c = min(r.width, r.height) * corner.clamped(0, 0.5)
            p.addRoundedRect(in: r, cornerWidth: c, cornerHeight: c)
        case .ellipse, .ring:
            p.addEllipse(in: r)
        case .arch:
            let radius = min(r.width / 2, r.height)
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY - radius))
            p.addArc(center: CGPoint(x: r.midX, y: r.maxY - radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.closeSubpath()
        case .diamond:
            p.addLines(between: [CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.minX, y: r.midY)])
            p.closeSubpath()
        case .triangle:
            p.addLines(between: [CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.minY)])
            p.closeSubpath()
        case .hexagon:
            let pts = (0..<6).map { i -> CGPoint in
                let a = CGFloat(i) * .pi / 3 + .pi / 6
                return CGPoint(x: r.midX + cos(a) * r.width / 2, y: r.midY + sin(a) * r.height / 2)
            }
            p.addLines(between: pts)
            p.closeSubpath()
        case .diagonalBand:
            p.addLines(between: [
                CGPoint(x: r.minX, y: r.minY + r.height * 0.1), CGPoint(x: r.maxX, y: r.minY + r.height * 0.6),
                CGPoint(x: r.maxX, y: r.minY + r.height * 0.9), CGPoint(x: r.minX, y: r.minY + r.height * 0.4)
            ])
            p.closeSubpath()
        case .chevron:
            p.addLines(between: [
                CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.midX, y: r.minY + r.height * 0.35), CGPoint(x: r.maxX, y: r.maxY),
                CGPoint(x: r.maxX, y: r.maxY - r.height * 0.3), CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.minX, y: r.maxY - r.height * 0.3)
            ])
            p.closeSubpath()
        }
        return p
    }

    static func render(_ s: ShapeContent, size: CGSize, canvasWidth: CGFloat) -> CGImage? {
        let w = max(1, Int(size.width.rounded())), h = max(1, Int(size.height.rounded()))
        guard let ctx = Gfx.context(w, h) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        let usesFill = s.kind != .frame && s.kind != .ring
        if usesFill, let f = s.fill {
            ctx.addPath(path(s.kind, in: rect, corner: CGFloat(s.cornerRadius)))
            ctx.setFillColor(f.cgColor)
            ctx.fillPath()
        }
        let strokeColor = s.stroke ?? (usesFill ? nil : s.fill)
        if let st = strokeColor, s.kind != .rule {
            let lw = max(1, CGFloat(s.strokeWidth) * canvasWidth)
            ctx.addPath(path(s.kind, in: rect.insetBy(dx: lw / 2, dy: lw / 2), corner: CGFloat(s.cornerRadius)))
            ctx.setLineWidth(lw)
            ctx.setStrokeColor(st.cgColor)
            ctx.strokePath()
        }
        return ctx.makeImage()
    }
}

/// Procedural backgrounds: color blends, paint, texture and geometric "diagram" grounds.
enum Generators {
    static func render(_ f: FillContent, size: CGSize) -> CGImage? {
        let w = max(1, Int(size.width.rounded())), h = max(1, Int(size.height.rounded()))
        guard let ctx = Gfx.context(w, h) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        let W = CGFloat(w), H = CGFloat(h), unit = min(W, H), big = max(W, H)
        var rng = SeededRNG(seed: f.seed)
        let cols = f.colors.isEmpty ? [RGBA.ink, RGBA.paper] : f.colors
        func c(_ i: Int) -> RGBA { cols[((i % cols.count) + cols.count) % cols.count] }
        let k = f.intensity.clamped01
        let scale = unit / 1000

        switch f.style {
        case .solid:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)

        case .linear:
            Gfx.linearGradient(ctx, rect, cols, angle: f.angle)

        case .radial:
            ctx.setFillColor(c(cols.count - 1).cgColor)
            ctx.fill(rect)
            if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: cols.map(\.cgColor) as CFArray, locations: nil) {
                let center = CGPoint(x: W * 0.5, y: H * CGFloat(Golden.major))
                ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center,
                                       endRadius: big * CGFloat(0.5 + 0.7 * k), options: [.drawsAfterEndLocation])
            }

        case .scrim:
            let base = c(0)
            Gfx.linearGradient(ctx, rect, [base.withAlpha(0), base.withAlpha(base.a * (0.25 + 0.45 * k)), base.withAlpha(base.a * (0.4 + 0.6 * k))],
                               angle: f.angle, locations: [0, 0.55, 1])

        case .meshBlend:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            for i in 0..<9 {
                let r = unit * CGFloat(rng.range(0.25, 0.6))
                let p = CGPoint(x: W * CGFloat(rng.unit()), y: H * CGFloat(rng.unit()))
                ctx.setFillColor(c(i + 1).withAlpha(0.9).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }
            guard let img = ctx.makeImage() else { return nil }
            let ci = FX.grain(FX.blur(CIImage(cgImage: img), unit * CGFloat(0.12 + 0.12 * k)), seed: f.seed, strength: 0.05, size: 1)
            return Gfx.render(ci, w, h)

        case .paintSmear:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            ctx.setLineCap(.round)
            for _ in 0..<(26 + Int(k * 30)) {
                ctx.setStrokeColor(c(1 + rng.int(cols.count * 3)).withAlpha(rng.range(0.55, 1)).cgColor)
                ctx.setLineWidth(unit * CGFloat(rng.range(0.03, 0.14)))
                let y0 = H * CGFloat(rng.unit()), x0 = W * CGFloat(rng.range(-0.2, 0.4))
                ctx.move(to: CGPoint(x: x0, y: y0))
                ctx.addCurve(to: CGPoint(x: W * CGFloat(rng.range(0.6, 1.2)), y: y0 + H * CGFloat(rng.range(-0.15, 0.15))),
                             control1: CGPoint(x: W * CGFloat(rng.range(0.1, 0.5)), y: y0 + H * CGFloat(rng.range(-0.25, 0.25))),
                             control2: CGPoint(x: W * CGFloat(rng.range(0.4, 0.9)), y: y0 + H * CGFloat(rng.range(-0.25, 0.25))))
                ctx.strokePath()
            }
            guard let img = ctx.makeImage() else { return nil }
            var ci = CIImage(cgImage: img)
            ci = ci.clampedToExtent().applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: unit * CGFloat(0.03 + 0.07 * k), kCIInputAngleKey: -f.angle * .pi / 180
            ]).cropped(to: ci.extent)
            ci = FX.displace(ci, by: FX.smoothNoise(ci.extent, seed: f.seed, cells: 5), scale: unit * 0.06)
            ci = ci.clampedToExtent().applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 4 * scale, kCIInputIntensityKey: 0.8]).cropped(to: ci.extent)
            return Gfx.render(FX.grain(ci, seed: f.seed, strength: 0.06, size: 1), w, h)

        case .watercolor:
            let paper = cols.max { $0.luminance < $1.luminance }!
            let inks = cols.filter { $0 != paper }
            ctx.setFillColor(paper.withLightness(max(paper.hsl.l, 0.9)).cgColor)
            ctx.fill(rect)
            ctx.setBlendMode(.multiply)
            for i in 0..<(40 + Int(k * 40)) {
                let col = inks.isEmpty ? c(i) : inks[i % inks.count]
                let r = unit * CGFloat(rng.range(0.06, 0.3))
                let p = CGPoint(x: W * CGFloat(rng.unit()), y: H * CGFloat(rng.unit()))
                ctx.setFillColor(col.withAlpha(rng.range(0.06, 0.18)).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r * CGFloat(rng.range(0.6, 1.3)), width: 2 * r, height: 2 * r))
            }
            guard let img = ctx.makeImage() else { return nil }
            var ci = FX.displace(CIImage(cgImage: img), by: FX.smoothNoise(rect, seed: f.seed, cells: 8), scale: unit * 0.08)
            ci = FX.grain(ci, seed: f.seed, strength: 0.08, size: max(1, 1.5 * scale))
            return Gfx.render(ci, w, h)

        case .smoke:
            let sorted = cols.sorted { $0.luminance < $1.luminance }
            let n = FX.smoothNoise(rect, seed: f.seed, cells: 3 + Int(k * 5))
            let shaped = FX.controls(n, contrast: 1.6 + k)
            return Gfx.render(FX.grain(FX.gradientMap(shaped, sorted), seed: f.seed, strength: 0.05, size: 1), w, h)

        case .marble:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            let band = unit * CGFloat(0.02 + 0.05 * k)
            var y: CGFloat = -big
            var i = 1
            while y < big * 2 {
                ctx.setFillColor(c(i).withAlpha(0.85).cgColor)
                ctx.fill(CGRect(x: -W, y: y, width: W * 3, height: band * CGFloat(rng.range(0.15, 0.6))))
                y += band * CGFloat(rng.range(0.8, 2.4))
                i += 1
            }
            guard let img = ctx.makeImage() else { return nil }
            let ci = FX.displace(FX.blur(CIImage(cgImage: img), 1.5 * scale), by: FX.smoothNoise(rect, seed: f.seed, cells: 4), scale: unit * 0.35)
            return Gfx.render(ci, w, h)

        case .grain:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            guard let img = ctx.makeImage() else { return nil }
            return Gfx.render(FX.grain(CIImage(cgImage: img), seed: f.seed, strength: 0.08 + 0.3 * k, size: max(1, 1.6 * scale)), w, h)

        case .sunburst:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            let center = CGPoint(x: W * 0.5, y: H * CGFloat(Golden.major))
            let rays = 16 + Int(k * 24)
            let step = 2 * CGFloat.pi / CGFloat(rays)
            ctx.setFillColor(c(1).cgColor)
            for i in 0..<rays {
                let a = CGFloat(i) * step + CGFloat(f.angle) * .pi / 180
                ctx.move(to: center)
                ctx.addLine(to: CGPoint(x: center.x + cos(a) * big * 1.5, y: center.y + sin(a) * big * 1.5))
                ctx.addLine(to: CGPoint(x: center.x + cos(a + step / 2) * big * 1.5, y: center.y + sin(a + step / 2) * big * 1.5))
                ctx.closePath()
            }
            ctx.fillPath()
            if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: [c(2).withAlpha(0.0).cgColor, c(2).withAlpha(0.75).cgColor] as CFArray, locations: nil) {
                ctx.drawRadialGradient(g, startCenter: center, startRadius: unit * 0.1, endCenter: center, endRadius: big, options: [.drawsAfterEndLocation])
            }

        case .stripes:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            ctx.translateBy(x: W / 2, y: H / 2)
            ctx.rotate(by: -CGFloat(f.angle) * .pi / 180)
            let band = unit * CGFloat(0.02 + 0.08 * k)
            var x = -big * 1.5
            var i = 1
            while x < big * 1.5 {
                ctx.setFillColor(c(i).cgColor)
                ctx.fill(CGRect(x: x, y: -big * 1.5, width: band, height: big * 3))
                x += band * 2
                i += 1
            }

        case .bokeh:
            Gfx.linearGradient(ctx, rect, [c(0), c(0).withLightness(max(0.02, c(0).hsl.l - 0.1))], angle: 90)
            for i in 0..<40 {
                let r = unit * CGFloat(rng.range(0.04, 0.12))
                let p = CGPoint(x: W * CGFloat(rng.unit()), y: H * CGFloat(rng.unit()))
                ctx.setFillColor(c(1 + i).withAlpha(rng.range(0.15, 0.4)).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }
            guard let soft = ctx.makeImage(), let blurred = Gfx.render(FX.blur(CIImage(cgImage: soft), unit * 0.02), w, h),
                  let ctx2 = Gfx.context(w, h) else { return nil }
            ctx2.draw(blurred, in: rect)
            for i in 0..<(20 + Int(k * 30)) {
                let r = unit * CGFloat(rng.range(0.008, 0.035))
                let p = CGPoint(x: W * CGFloat(rng.unit()), y: H * CGFloat(rng.unit()))
                ctx2.setFillColor(c(1 + i).withAlpha(rng.range(0.25, 0.55)).cgColor)
                ctx2.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }
            return ctx2.makeImage()

        case .starfield:
            Gfx.linearGradient(ctx, rect, [c(0), c(1)], angle: f.angle)
            for _ in 0..<Int(400 + 900 * k) {
                let r = unit * CGFloat(rng.range(0.0006, 0.0028))
                ctx.setFillColor(RGBA.white.withAlpha(rng.range(0.3, 1)).cgColor)
                ctx.fillEllipse(in: CGRect(x: W * CGFloat(rng.unit()) - r, y: H * CGFloat(rng.unit()) - r, width: 2 * r, height: 2 * r))
            }
            for _ in 0..<6 {
                let p = CGPoint(x: W * CGFloat(rng.unit()), y: H * CGFloat(rng.unit()))
                if let g = CGGradient(colorsSpace: Gfx.sRGB, colors: [RGBA.white.withAlpha(0.5).cgColor, RGBA.white.withAlpha(0).cgColor] as CFArray, locations: nil) {
                    ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: unit * CGFloat(rng.range(0.01, 0.03)), options: [])
                }
            }

        case .bauhaus:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            let variant = rng.int(3)
            let gx = W * CGFloat(Golden.major), gy = H * CGFloat(Golden.minor)
            ctx.setFillColor(c(1).cgColor)
            let R = unit * 0.34
            ctx.fillEllipse(in: CGRect(x: (variant == 1 ? W - gx : gx) - R, y: gy - R, width: 2 * R, height: 2 * R))
            ctx.setFillColor(c(2).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: W * CGFloat(Golden.minor), height: H * CGFloat(variant == 2 ? 0.5 : 0.236)))
            ctx.setFillColor(c(3).cgColor)
            ctx.move(to: CGPoint(x: W, y: H * 0.618))
            ctx.addArc(center: CGPoint(x: W, y: H * 0.618), radius: unit * 0.3, startAngle: .pi / 2, endAngle: .pi * 1.5, clockwise: false)
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(c(4).cgColor)
            ctx.fillEllipse(in: CGRect(x: W * 0.12, y: H * 0.78, width: unit * 0.08, height: unit * 0.08))
            ctx.setStrokeColor(c(2).cgColor)
            ctx.setLineWidth(unit * 0.008)
            ctx.move(to: CGPoint(x: W * 0.08, y: H * 0.382))
            ctx.addLine(to: CGPoint(x: W * 0.92, y: H * 0.382))
            ctx.strokePath()

        case .goldenBlocks:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            var r = rect
            let gap = unit * 0.008
            let spiral = CGMutablePath()
            for i in 0..<9 {
                let piece: CGRect, rest: CGRect, arcCenter: CGPoint, start: CGFloat
                let horizontal = r.width >= r.height
                let s = (horizontal ? r.width : r.height) * CGFloat(Golden.major)
                switch i % 4 {
                case 0:
                    piece = horizontal ? CGRect(x: r.minX, y: r.minY, width: s, height: r.height) : CGRect(x: r.minX, y: r.maxY - s, width: r.width, height: s)
                    rest = horizontal ? CGRect(x: r.minX + s, y: r.minY, width: r.width - s, height: r.height) : CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - s)
                    arcCenter = CGPoint(x: piece.maxX, y: piece.minY); start = .pi / 2
                case 1:
                    piece = horizontal ? CGRect(x: r.maxX - s, y: r.minY, width: s, height: r.height) : CGRect(x: r.minX, y: r.maxY - s, width: r.width, height: s)
                    rest = horizontal ? CGRect(x: r.minX, y: r.minY, width: r.width - s, height: r.height) : CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - s)
                    arcCenter = CGPoint(x: piece.minX, y: piece.minY); start = 0
                case 2:
                    piece = horizontal ? CGRect(x: r.maxX - s, y: r.minY, width: s, height: r.height) : CGRect(x: r.minX, y: r.minY, width: r.width, height: s)
                    rest = horizontal ? CGRect(x: r.minX, y: r.minY, width: r.width - s, height: r.height) : CGRect(x: r.minX, y: r.minY + s, width: r.width, height: r.height - s)
                    arcCenter = CGPoint(x: piece.minX, y: piece.maxY); start = -.pi / 2
                default:
                    piece = horizontal ? CGRect(x: r.minX, y: r.minY, width: s, height: r.height) : CGRect(x: r.minX, y: r.minY, width: r.width, height: s)
                    rest = horizontal ? CGRect(x: r.minX + s, y: r.minY, width: r.width - s, height: r.height) : CGRect(x: r.minX, y: r.minY + s, width: r.width, height: r.height - s)
                    arcCenter = CGPoint(x: piece.maxX, y: piece.maxY); start = .pi
                }
                ctx.setFillColor(c(i + 1).cgColor)
                ctx.fill(piece.insetBy(dx: gap / 2, dy: gap / 2))
                spiral.addArc(center: arcCenter, radius: min(piece.width, piece.height), startAngle: start, endAngle: start + .pi / 2, clockwise: false)
                r = rest
                if r.width < 2 || r.height < 2 { break }
            }
            ctx.addPath(spiral)
            ctx.setStrokeColor(c(0).withAlpha(0.35 + 0.4 * k).cgColor)
            ctx.setLineWidth(unit * 0.004)
            ctx.strokePath()

        case .halftone:
            ctx.setFillColor(c(0).cgColor)
            ctx.fill(rect)
            let spacing = unit * CGFloat(0.018 + 0.03 * (1 - k))
            let rad = f.angle * .pi / 180
            let dir = CGVector(dx: cos(rad), dy: -sin(rad))
            ctx.setFillColor(c(1).cgColor)
            var yy: CGFloat = 0
            var row = 0
            while yy < H + spacing {
                var xx: CGFloat = row % 2 == 0 ? 0 : spacing / 2
                while xx < W + spacing {
                    let proj = ((xx - W / 2) * dir.dx + (yy - H / 2) * dir.dy) / big + 0.5
                    let t = proj.clamped(0, 1)
                    let r = spacing * 0.55 * t
                    if r > 0.3 { ctx.fillEllipse(in: CGRect(x: xx - r, y: yy - r, width: 2 * r, height: 2 * r)) }
                    xx += spacing
                }
                yy += spacing * 0.866
                row += 1
            }
        }
        return ctx.makeImage()
    }
}
