import CoreGraphics
import CoreImage
import Foundation

// MARK: - Model

enum SurfaceTexture: String, Codable, CaseIterable, Identifiable {
    case none, gold, goldLeaf, silver, chrome, copper, bronze, rust, stone, marble, wood, leather, ice, fire, concrete, paper, galaxy, smoke
    case glitter, thread, charred, chalk, stripes, polkaDots, checker, plaid, gradient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Text Color"
        case .gold: return "Polished Gold"
        case .goldLeaf: return "Gold Leaf"
        case .silver: return "Brushed Silver"
        case .chrome: return "80s Chrome"
        case .copper: return "Copper"
        case .bronze: return "Oxidized Bronze"
        case .rust: return "Rusted Iron"
        case .stone: return "Stone"
        case .marble: return "Marble"
        case .wood: return "Wood"
        case .leather: return "Leather"
        case .ice: return "Ice"
        case .fire: return "Fire"
        case .concrete: return "Concrete"
        case .paper: return "Paper"
        case .galaxy: return "Galaxy"
        case .smoke: return "Smoke"
        case .glitter: return "Glitter"
        case .thread: return "Embroidery Thread"
        case .charred: return "Burnt Wood"
        case .chalk: return "Chalk"
        case .stripes: return "Stripes"
        case .polkaDots: return "Polka Dots"
        case .checker: return "Checkerboard"
        case .plaid: return "Plaid"
        case .gradient: return "Two-Tone Gradient"
        }
    }
}

enum BevelStyle: String, Codable, CaseIterable, Identifiable {
    case chisel, smooth, pillow, inflated
    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

enum WearKind: String, Codable, CaseIterable, Identifiable {
    case none, distressed, cracked, scratched, grunge, eroded, inkBleed, shattered

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Clean"
        case .distressed: return "Distressed"
        case .cracked: return "Cracked"
        case .scratched: return "Scratched"
        case .grunge: return "Grunge"
        case .eroded: return "Eroded Edges"
        case .inkBleed: return "Ink Bleed"
        case .shattered: return "Shattered Glass"
        }
    }
}

/// A stack of type effects, applied in a fixed, designer-sensible order:
/// wear, surface, relief, inner light, then outlines, glow, extrusion and shadow behind,
/// and finally the passes that blend the type into the photo underneath.
struct TextStyle: Codable, Hashable {
    var presetName = ""

    var surface: SurfaceTexture = .none
    var surfaceScale = 1.0
    /// 0 keeps the material's own color, 1 tints it fully toward the text color.
    var surfaceTint = 0.0

    var bevel = 0.0
    var bevelStyle: BevelStyle = .smooth
    /// Degrees; 135 lights from the top left.
    var lightAngle = 135.0
    var gloss = 0.0

    var innerShadow = 0.0
    var innerGlow = 0.0
    var innerGlowColor: RGBA?

    /// Outline widths as a fraction of the font size.
    var outline = 0.0
    var outlineColor: RGBA?
    var outline2 = 0.0
    var outline2Color: RGBA?
    var outerGlow = 0.0
    var outerGlowColor: RGBA?
    /// 3D depth as a fraction of the font size.
    var extrude = 0.0
    var extrudeAngle = 300.0
    var extrudeColor: RGBA?
    var longShadow = 0.0
    var longShadowColor: RGBA?

    var wear: WearKind = .none
    var wearAmount = 0.5

    var halftone = 0.0
    var glitch = 0.0

    /// Pattern and thread colors for pattern surfaces, glitter and embroidery.
    var patternColor: RGBA?
    var patternColor2: RGBA?
    /// Rounds every corner of the letters (balloon and sticker type).
    var roundness = 0.0
    /// Paint or liquid running off the bottom of the letters.
    var drips = 0.0
    /// A dashed stitch line just inside each letter.
    var stitch = 0.0
    var stitchColor: RGBA?
    /// A soft offset shadow cast away from the light.
    var dropShadow = 0.0
    /// Stacked offset copies behind the type, in alternating colors.
    var echo = 0.0
    var echoColor: RGBA?
    var echoColor2: RGBA?
    /// Smoke rising off the letters.
    var smokeTrail = 0.0
    var smokeColor: RGBA?
    /// A material from `MaterialLibrary` for the letter face; overrides `surface`.
    var materialID: String?

    // Scene blending: these read the pixels under the type.
    var photoTexture = 0.0
    var photoDisplace = 0.0
    var lightWrap = 0.0
    var colorMatch = 0.0
    var photoErode = 0.0
    var photoFill = 0.0

    var isActive: Bool {
        var plain = self
        plain.presetName = ""
        return plain != TextStyle()
    }

    var needsScene: Bool {
        photoTexture > 0 || photoDisplace > 0 || lightWrap > 0 || colorMatch > 0 || photoErode > 0 || photoFill > 0
    }

    /// Extra room the effects need around the type, in multiples of the font size.
    var paddingFactor: Double {
        outline + outline2 + outerGlow * 0.7 + extrude * 1.1 + longShadow * 2.6 + (wear == .inkBleed ? 0.04 : 0) + glitch * 0.05
            + drips * 0.9 + dropShadow * 0.12 + echo * 0.36 + smokeTrail * 1.2
    }
}

extension TextStyle {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        func d(_ k: CodingKeys, _ v: Double) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? v }
        presetName = try c.decodeIfPresent(String.self, forKey: .presetName) ?? ""
        surface = try c.decodeIfPresent(SurfaceTexture.self, forKey: .surface) ?? .none
        surfaceScale = try d(.surfaceScale, 1)
        surfaceTint = try d(.surfaceTint, 0)
        bevel = try d(.bevel, 0)
        bevelStyle = try c.decodeIfPresent(BevelStyle.self, forKey: .bevelStyle) ?? .smooth
        lightAngle = try d(.lightAngle, 135)
        gloss = try d(.gloss, 0)
        innerShadow = try d(.innerShadow, 0)
        innerGlow = try d(.innerGlow, 0)
        innerGlowColor = try c.decodeIfPresent(RGBA.self, forKey: .innerGlowColor)
        outline = try d(.outline, 0)
        outlineColor = try c.decodeIfPresent(RGBA.self, forKey: .outlineColor)
        outline2 = try d(.outline2, 0)
        outline2Color = try c.decodeIfPresent(RGBA.self, forKey: .outline2Color)
        outerGlow = try d(.outerGlow, 0)
        outerGlowColor = try c.decodeIfPresent(RGBA.self, forKey: .outerGlowColor)
        extrude = try d(.extrude, 0)
        extrudeAngle = try d(.extrudeAngle, 300)
        extrudeColor = try c.decodeIfPresent(RGBA.self, forKey: .extrudeColor)
        longShadow = try d(.longShadow, 0)
        longShadowColor = try c.decodeIfPresent(RGBA.self, forKey: .longShadowColor)
        wear = try c.decodeIfPresent(WearKind.self, forKey: .wear) ?? .none
        wearAmount = try d(.wearAmount, 0.5)
        halftone = try d(.halftone, 0)
        glitch = try d(.glitch, 0)
        photoTexture = try d(.photoTexture, 0)
        photoDisplace = try d(.photoDisplace, 0)
        lightWrap = try d(.lightWrap, 0)
        colorMatch = try d(.colorMatch, 0)
        photoErode = try d(.photoErode, 0)
        photoFill = try d(.photoFill, 0)
        patternColor = try c.decodeIfPresent(RGBA.self, forKey: .patternColor)
        patternColor2 = try c.decodeIfPresent(RGBA.self, forKey: .patternColor2)
        roundness = try d(.roundness, 0)
        drips = try d(.drips, 0)
        stitch = try d(.stitch, 0)
        stitchColor = try c.decodeIfPresent(RGBA.self, forKey: .stitchColor)
        dropShadow = try d(.dropShadow, 0)
        echo = try d(.echo, 0)
        echoColor = try c.decodeIfPresent(RGBA.self, forKey: .echoColor)
        echoColor2 = try c.decodeIfPresent(RGBA.self, forKey: .echoColor2)
        smokeTrail = try d(.smokeTrail, 0)
        smokeColor = try c.decodeIfPresent(RGBA.self, forKey: .smokeColor)
        materialID = try c.decodeIfPresent(String.self, forKey: .materialID)
    }
}

// MARK: - Styler

enum TextStyler {
    /// Turns a glyph mask and its flat fill into a fully styled raster (same size).
    /// `mask` is gray, white inside the glyphs; `fill` is the flat or gradient face.
    static func compose(mask: CGImage, fill: CGImage, style s: TextStyle, color: RGBA, fontSize: CGFloat, seed: Int) -> CGImage? {
        let ext = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
        let size = max(4, fontSize)
        var grayMask = CIImage(cgImage: mask)

        // 1. Wear changes the letter shapes first, so every later pass follows it.
        if s.wear != .none {
            grayMask = wear(grayMask, kind: s.wear, amount: s.wearAmount, size: size, seed: seed, extent: ext)
        }
        if s.roundness > 0 {
            grayMask = FX.controls(FX.blur(grayMask, size * CGFloat(0.015 + 0.06 * s.roundness)), contrast: 7).cropped(to: ext)
        }
        if s.drips > 0, let dripped = addDrips(grayMask, extent: ext, size: size, amount: s.drips, seed: seed) {
            grayMask = dripped
        }
        let alpha = grayMask.applyingFilter("CIMaskToAlpha").cropped(to: ext)

        // 2. Face: a material or the flat fill.
        var face: CIImage
        if let mid = s.materialID, MaterialLibrary.shared.material(mid) != nil {
            let pal = [ColorAdvisor.opposite(color), color, s.patternColor ?? RGBA.nearWhite]
            var tex = MaterialLibrary.shared.render(mid, extent: ext, palette: pal, seed: seed, scale: CGFloat(s.surfaceScale))
            if s.surfaceTint > 0 {
                tex = FX.mix(tex, FX.blend(FX.solid(color, ext), over: tex, mode: "CIColorBlendMode"), s.surfaceTint)
            }
            face = tex
        } else if s.surface != .none {
            let pa = s.patternColor ?? color, pb = s.patternColor2 ?? ColorAdvisor.opposite(color)
            var tex = SurfaceGen.make(s.surface, extent: ext, size: size * CGFloat(s.surfaceScale), seed: seed, a: pa, b: pb)
            if s.surfaceTint > 0 {
                tex = FX.mix(tex, FX.blend(FX.solid(color, ext), over: tex, mode: "CIColorBlendMode"), s.surfaceTint)
            }
            face = tex
        } else {
            // Shape passes (drips, rounding, ink bleed) grow the letters past the original fill,
            // so back it with the text color.
            face = CIImage(cgImage: fill).composited(over: FX.solid(color, ext))
        }
        if s.halftone > 0 {
            let dots = face.applyingFilter("CIDotScreen", parameters: [
                kCIInputCenterKey: CIVector(x: ext.midX, y: ext.midY), kCIInputAngleKey: 0.5,
                kCIInputWidthKey: max(2, size * 0.06), kCIInputSharpnessKey: 0.7
            ]).cropped(to: ext)
            face = FX.mix(face, FX.blend(dots, over: face, mode: "CIMultiplyBlendMode"), s.halftone)
        }

        // 3. Relief: a lit height field from the letter shapes.
        if s.bevel > 0 {
            face = bevel(face, grayMask: grayMask, style: s, size: size, extent: ext)
        }
        // 4. Inner light and shadow.
        if s.innerShadow > 0 {
            let rad = s.lightAngle * .pi / 180
            let off = CGAffineTransform(translationX: -cos(rad) * size * 0.04, y: -sin(rad) * size * 0.04)
            let inverse = invertedAlpha(alpha, extent: ext)
            let shadow = FX.blur(colored(RGBA(0, 0, 0, 0.85), alpha: inverse.transformed(by: off), extent: ext), size * 0.035)
            face = FX.mix(face, FX.blend(shadow, over: face, mode: "CISourceAtopCompositing"), s.innerShadow)
        }
        if s.innerGlow > 0 {
            let inverse = invertedAlpha(alpha, extent: ext)
            let glow = FX.blur(colored(s.innerGlowColor ?? RGBA(1, 1, 1, 0.9), alpha: inverse, extent: ext), size * 0.06)
            face = FX.mix(face, FX.blend(glow, over: face, mode: "CIScreenBlendMode"), s.innerGlow)
        }
        if s.stitch > 0 {
            let inset = alpha.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: size * 0.05]).cropped(to: ext)
            let inner = alpha.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: size * CGFloat(0.062 + 0.01 * s.stitch)]).cropped(to: ext)
            let ring = inset.applyingFilter("CISourceOutCompositing", parameters: [kCIInputBackgroundImageKey: inner])
            let dashes = (CIFilter(name: "CIStripesGenerator", parameters: [
                "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1), "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                kCIInputWidthKey: max(1.5, size * 0.025), kCIInputSharpnessKey: 1
            ])?.outputImage ?? CIImage.empty()).transformed(by: CGAffineTransform(rotationAngle: .pi / 4)).cropped(to: ext)
            let stitches = ring.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: dashes])
            let thread = colored(s.stitchColor ?? color.withLightness(0.92), alpha: stitches, extent: ext)
            let shadow = colored(RGBA(0, 0, 0, 0.45), alpha: stitches, extent: ext).transformed(by: CGAffineTransform(translationX: 0.8, y: -0.8))
            face = thread.composited(over: shadow.composited(over: face))
        }
        face = face.applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: alpha])

        // 5. Behind the face, back to front: long shadow, extrusion, glow, outlines.
        var behind = CIImage.empty().cropped(to: ext)
        var shape = alpha
        let o1 = CGFloat(s.outline) * size, o2 = CGFloat(s.outline2) * size
        let outer = o1 + o2 > 0 ? dilate(alpha, o1 + o2) : alpha
        let lightRad = s.lightAngle * .pi / 180
        if s.smokeTrail > 0 {
            let smoke = colored(s.smokeColor ?? color.withLightness(0.85).withAlpha(0.7), alpha: alpha, extent: ext)
                .clampedToExtent()
                .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: size * CGFloat(0.3 + 0.6 * s.smokeTrail), kCIInputAngleKey: Double.pi / 2])
                .cropped(to: ext)
            let rising = FX.displace(smoke.transformed(by: CGAffineTransform(translationX: 0, y: size * CGFloat(0.25 * s.smokeTrail))),
                                     by: FX.smoothNoise(ext, seed: seed &+ 21, cells: max(4, Int(ext.width / max(1, size * 0.4)))),
                                     scale: size * 0.35)
            behind = FX.blur(rising, size * 0.03).composited(over: behind)
        }
        if s.dropShadow > 0 {
            let d = size * CGFloat(0.03 + 0.06 * s.dropShadow)
            let cast = colored(RGBA(0, 0, 0, 0.35 + 0.3 * s.dropShadow), alpha: outer, extent: ext)
                .transformed(by: CGAffineTransform(translationX: -cos(lightRad) * d, y: -sin(lightRad) * d))
            behind = FX.blur(cast, size * CGFloat(0.015 + 0.04 * s.dropShadow)).composited(over: behind)
        }
        if s.echo > 0 {
            let copies = max(1, min(4, Int((s.echo * 4).rounded())))
            let step = size * 0.08
            let rad = s.extrudeAngle * .pi / 180
            let c1 = s.echoColor ?? ColorAdvisor.opposite(color), c2 = s.echoColor2 ?? color.withLightness(0.25)
            for k in stride(from: copies, through: 1, by: -1) {
                let copy = colored(k % 2 == 1 ? c1 : c2, alpha: outer, extent: ext)
                    .transformed(by: CGAffineTransform(translationX: cos(rad) * step * CGFloat(k), y: sin(rad) * step * CGFloat(k)))
                behind = copy.composited(over: behind)
            }
        }
        if s.longShadow > 0 {
            let base = o1 + o2 > 0 ? dilate(alpha, o1 + o2) : alpha
            behind = trail(base, color: s.longShadowColor ?? RGBA(0, 0, 0, 0.45), length: CGFloat(s.longShadow) * size * 2.5,
                           angle: s.extrudeAngle, fade: true, extent: ext).composited(over: behind)
        }
        if s.extrude > 0 {
            let base = o1 + o2 > 0 ? dilate(alpha, o1 + o2) : alpha
            behind = trail(base, color: s.extrudeColor ?? color.withLightness(max(0.08, color.hsl.l - 0.35)),
                           length: CGFloat(s.extrude) * size, angle: s.extrudeAngle, fade: false, extent: ext).composited(over: behind)
        }
        if s.outerGlow > 0 {
            let g = s.outerGlowColor ?? color
            let soft = FX.blur(colored(g, alpha: dilate(alpha, size * 0.02), extent: ext), size * CGFloat(0.12 + 0.35 * s.outerGlow))
            behind = soft.composited(over: soft.composited(over: behind))
        }
        if o2 > 0 {
            shape = dilate(alpha, o1 + o2)
            behind = colored(s.outline2Color ?? color.withLightness(0.95), alpha: shape, extent: ext).composited(over: behind)
        }
        if o1 > 0 {
            behind = colored(s.outlineColor ?? color.withLightness(max(0.06, color.hsl.l - 0.5)), alpha: dilate(alpha, o1), extent: ext).composited(over: behind)
        }
        var out = face.composited(over: behind)

        // 6. Misregistered color plates.
        if s.glitch > 0 {
            let d = size * CGFloat(0.035 * s.glitch)
            let r = FX.matrix(out, r: (1, 0, 0), g: (0, 0, 0), b: (0, 0, 0)).transformed(by: CGAffineTransform(translationX: -d, y: 0))
            let b = FX.matrix(out, r: (0, 0, 0), g: (0, 0, 0), b: (0, 0, 1)).transformed(by: CGAffineTransform(translationX: d, y: 0))
            out = FX.blend(b, over: FX.blend(r, over: out, mode: "CIScreenBlendMode"), mode: "CIScreenBlendMode")
        }
        return Gfx.render(out.cropped(to: ext), extent: ext)
    }

    /// Scene passes: the styled type meets the photo directly under it (`background`, same size).
    static func blendIntoScene(_ raster: CGImage, background: CGImage, style s: TextStyle, fontSize: CGFloat) -> CGImage? {
        let ext = CGRect(x: 0, y: 0, width: raster.width, height: raster.height)
        let size = max(4, fontSize)
        var r = CIImage(cgImage: raster)
        let bg = CIImage(cgImage: background).cropped(to: ext)
        let lum = FX.controls(FX.mono(bg), contrast: 1.3)

        if s.photoFill > 0 {
            let lit = FX.controls(bg, saturation: 1.15, brightness: 0.12, contrast: 1.25)
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: r])
            r = FX.mix(r, lit, s.photoFill)
        }
        if s.colorMatch > 0 {
            let mean = PixelSampler.stats(background, region: .full).mean
            let tinted = FX.blend(FX.solid(mean, ext), over: r, mode: "CISoftLightBlendMode")
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: r])
            r = FX.mix(r, tinted, s.colorMatch)
        }
        if s.photoTexture > 0 {
            let textured = FX.blend(lum, over: r, mode: "CIOverlayBlendMode")
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: r])
            r = FX.mix(r, textured, s.photoTexture)
        }
        if s.photoErode > 0 {
            // The photo's darks eat into the letters, as if the type sat in its shadows.
            let m = FX.mix(FX.solid(.white, ext), FX.controls(lum, brightness: 0.25, contrast: 2.5), s.photoErode)
            r = r.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: m])
        }
        if s.photoDisplace > 0 {
            r = FX.displace(r, by: FX.blur(lum, size * 0.04), scale: CGFloat(s.photoDisplace) * size * 0.18)
        }
        if s.lightWrap > 0 {
            let inner = r.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: size * 0.045])
            let band = r.applyingFilter("CISourceOutCompositing", parameters: [kCIInputBackgroundImageKey: inner])
            let light = FX.blur(bg, size * 0.1).applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: band])
            let wrapped = FX.blend(light, over: r, mode: "CIScreenBlendMode")
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: r])
            r = FX.mix(r, wrapped, s.lightWrap)
        }
        return Gfx.render(r.cropped(to: ext), extent: ext)
    }

    // MARK: Building blocks

    static func colored(_ c: RGBA, alpha: CIImage, extent: CGRect) -> CIImage {
        FX.solid(c, extent).applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(), kCIInputMaskImageKey: alpha
        ])
    }

    static func dilate(_ alpha: CIImage, _ r: CGFloat) -> CIImage {
        guard r > 0.4 else { return alpha }
        return alpha.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: r]).cropped(to: alpha.extent.insetBy(dx: -r, dy: -r))
    }

    static func invertedAlpha(_ alpha: CIImage, extent: CGRect) -> CIImage {
        alpha.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: -1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).cropped(to: extent)
    }

    /// Repeated offset copies: a solid 3D extrusion, or a fading long shadow.
    static func trail(_ alpha: CIImage, color: RGBA, length: CGFloat, angle: Double, fade: Bool, extent: CGRect) -> CIImage {
        let steps = max(1, min(fade ? 90 : 60, Int(length.rounded())))
        let rad = angle * .pi / 180
        let dx = cos(rad) * length / CGFloat(steps), dy = sin(rad) * length / CGFloat(steps)
        var out = CIImage.empty().cropped(to: extent)
        for i in stride(from: steps, through: 1, by: -1) {
            let t = Double(i) / Double(steps)
            var c = color
            if fade {
                c = color.withAlpha(color.a * (1 - t))
            } else {
                c = color.withLightness(max(0.02, color.hsl.l - 0.12 * t))
            }
            let copy = colored(c, alpha: alpha, extent: extent).transformed(by: CGAffineTransform(translationX: dx * CGFloat(i), y: dy * CGFloat(i)))
            out = copy.composited(over: out)
        }
        return out.cropped(to: extent)
    }

    private static func bevel(_ face: CIImage, grayMask: CIImage, style s: TextStyle, size: CGFloat, extent: CGRect) -> CIImage {
        let radius: CGFloat
        switch s.bevelStyle {
        case .chisel: radius = size * CGFloat(0.02 + 0.05 * s.bevel)
        case .smooth: radius = size * CGFloat(0.04 + 0.1 * s.bevel)
        case .pillow: radius = size * CGFloat(0.08 + 0.12 * s.bevel)
        case .inflated: radius = size * CGFloat(0.16 + 0.14 * s.bevel)
        }
        let ground = grayMask.composited(over: FX.solid(.black, extent)).cropped(to: extent)
        let height = ground.applyingFilter("CIHeightFieldFromMask", parameters: [kCIInputRadiusKey: radius]).cropped(to: extent)
        let gloss = s.bevelStyle == .inflated ? max(s.gloss, 0.7) : s.gloss
        let sphere = CIImage(cgImage: lightSphere(angle: s.lightAngle, gloss: gloss, chisel: s.bevelStyle == .chisel))
        let shaded = height.applyingFilter("CIShadedMaterial", parameters: [
            kCIInputShadingImageKey: sphere, kCIInputScaleKey: 6 + 14 * s.bevel
        ]).cropped(to: extent)
        var lit = FX.blend(shaded, over: face, mode: gloss > 0.4 ? "CIHardLightBlendMode" : "CIOverlayBlendMode")
        if gloss > 0 {
            let spec = FX.controls(FX.mono(shaded), brightness: -0.35, contrast: 3)
            lit = FX.mix(lit, FX.blend(spec, over: lit, mode: "CIScreenBlendMode"), gloss)
        }
        return FX.mix(face, lit, min(1, 0.4 + s.bevel))
    }

    /// Grows drips from the bottom edge of each letter.
    static func addDrips(_ m: CIImage, extent e: CGRect, size: CGFloat, amount: Double, seed: Int) -> CIImage? {
        let w = Int(e.width), h = Int(e.height)
        guard w > 2, h > 2, let rendered = Gfx.render(m, extent: e) else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h)
        let ok = buf.withUnsafeMutableBytes { ptr -> Bool in
            guard let g = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: Gfx.gray, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            g.draw(rendered, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok, let ctx = Gfx.grayContext(w, h) else { return nil }
        ctx.draw(rendered, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rng = SeededRNG(seed: seed &+ 99)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setLineCap(.round)
        let step = max(2, Int(size * 0.055))
        var x = step / 2
        while x < w {
            // Lowest inked pixel in this column (row 0 is the top of the buffer).
            var bottom = -1
            for row in stride(from: h - 1, through: 0, by: -1) where buf[row * w + x] > 140 { bottom = row; break }
            if bottom > 0 && rng.unit() < 0.25 + 0.45 * amount {
                let width = size * CGFloat(rng.range(0.035, 0.085))
                let length = size * CGFloat(rng.range(0.15, 0.25 + 0.75 * amount))
                let startY = CGFloat(h - bottom) + width * 0.4
                let endY = max(width, startY - length)
                ctx.setLineWidth(width)
                ctx.move(to: CGPoint(x: CGFloat(x), y: startY))
                ctx.addLine(to: CGPoint(x: CGFloat(x), y: endY))
                ctx.strokePath()
                let r = width * CGFloat(rng.range(0.6, 0.85))
                ctx.fillEllipse(in: CGRect(x: CGFloat(x) - r, y: endY - r * 1.2, width: 2 * r, height: 2.4 * r))
                ctx.fillEllipse(in: CGRect(x: CGFloat(x) - width, y: startY - width * 0.9, width: width * 2, height: width * 1.2))
            }
            x += step + rng.int(step)
        }
        return ctx.makeImage().map { CIImage(cgImage: $0) }
    }

    private static var sphereCache: [String: CGImage] = [:]
    private static let lock = NSLock()

    /// A lit ball used as the lighting environment for CIShadedMaterial. Mid gray faces read
    /// as neutral, so overlay blending adds light on one side and shade on the other.
    static func lightSphere(angle: Double, gloss: Double, chisel: Bool) -> CGImage {
        let key = "\(Int(angle))-\(Int(gloss * 10))-\(chisel)"
        lock.lock()
        if let c = sphereCache[key] { lock.unlock(); return c }
        lock.unlock()
        let n = 256
        let ctx = Gfx.context(n, n)!
        let c = CGPoint(x: n / 2, y: n / 2)
        let rad = angle * .pi / 180
        let hl = CGPoint(x: c.x + cos(rad) * 70, y: c.y + sin(rad) * 70)
        let sh = CGPoint(x: c.x - cos(rad) * 70, y: c.y - sin(rad) * 70)
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
        let shadowGrad = CGGradient(colorsSpace: Gfx.sRGB, colors: [CGColor(gray: 0.08, alpha: 1), CGColor(gray: 0.5, alpha: 0)] as CFArray, locations: nil)!
        ctx.drawRadialGradient(shadowGrad, startCenter: sh, startRadius: 0, endCenter: sh, endRadius: chisel ? 120 : 150, options: [])
        let hiTop: CGFloat = gloss > 0.4 ? 1 : 0.92
        let hiGrad = CGGradient(colorsSpace: Gfx.sRGB, colors: [CGColor(gray: hiTop, alpha: 1), CGColor(gray: 0.5, alpha: 0)] as CFArray, locations: nil)!
        ctx.drawRadialGradient(hiGrad, startCenter: hl, startRadius: 0, endCenter: hl, endRadius: chisel ? 110 : 140, options: [])
        if gloss > 0 {
            let spot = CGGradient(colorsSpace: Gfx.sRGB, colors: [CGColor(gray: 1, alpha: CGFloat(gloss)), CGColor(gray: 1, alpha: 0)] as CFArray, locations: nil)!
            ctx.drawRadialGradient(spot, startCenter: hl, startRadius: 0, endCenter: hl, endRadius: 34, options: [])
        }
        let img = ctx.makeImage()!
        lock.lock(); sphereCache[key] = img; lock.unlock()
        return img
    }

    /// Changes the glyph mask (gray, white inside) to show age and use.
    static func wear(_ m: CIImage, kind: WearKind, amount: Double, size: CGFloat, seed: Int, extent e: CGRect) -> CIImage {
        let a = amount.clamped01
        switch kind {
        case .none:
            return m
        case .distressed, .grunge:
            let fine = FX.noise(e, seed: seed, grainSize: max(1, size * 0.02), strength: 1)
            let specks = FX.controls(fine, brightness: 0.55 - 0.3 * a, contrast: 6)
            let blotch = FX.controls(FX.smoothNoise(e, seed: seed &+ 3, cells: max(5, Int(e.width / max(1, size * 0.5)))), brightness: kind == .grunge ? 0.4 - 0.3 * a : 0.3 - 0.25 * a, contrast: 4)
            return FX.blend(FX.blend(specks, over: blotch, mode: "CIMultiplyBlendMode"), over: m, mode: "CIMultiplyBlendMode")
        case .cracked:
            let cells = FX.noise(e, seed: seed, grainSize: 1, strength: 1)
                .applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: size * CGFloat(0.35 - 0.2 * a), kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)])
                .cropped(to: e)
            let lines = FX.controls(FX.mono(cells.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 10.0]).cropped(to: e)), contrast: 4)
                .applyingFilter("CIColorInvert")
            let crisp = FX.controls(lines, brightness: 0.3 - 0.2 * a, contrast: 6)
            return FX.blend(crisp, over: m, mode: "CIMultiplyBlendMode")
        case .scratched:
            let streaks = FX.noise(e, seed: seed, grainSize: 1, strength: 1).clampedToExtent()
                .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: size * 0.6, kCIInputAngleKey: 0.35]).cropped(to: e)
            let cuts = FX.controls(FX.mono(streaks), brightness: 0.55 - 0.25 * a, contrast: 12)
            return FX.blend(cuts, over: m, mode: "CIMultiplyBlendMode")
        case .shattered:
            let shards = FX.noise(e, seed: seed, grainSize: 1, strength: 1)
                .applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: size * CGFloat(0.4 - 0.2 * a), kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)])
                .cropped(to: e)
            let shifted = FX.displace(m, by: shards, scale: size * CGFloat(0.04 + 0.06 * a))
            let seams = FX.controls(FX.mono(shards.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 12.0]).cropped(to: e)), contrast: 5)
                .applyingFilter("CIColorInvert")
            return FX.blend(FX.controls(seams, brightness: 0.2, contrast: 8), over: shifted, mode: "CIMultiplyBlendMode")
        case .eroded, .inkBleed:
            let blurred = FX.blur(m, size * (kind == .inkBleed ? 0.045 : 0.03))
            let rough = FX.blend(FX.noise(e, seed: seed, grainSize: max(1, size * 0.015), strength: 0.6 * a), over: blurred, mode: "CIOverlayBlendMode")
            // A bleed grows past the edge (low threshold); erosion eats into it (high threshold).
            let bias = kind == .inkBleed ? 0.18 : -0.12
            return FX.controls(rough, brightness: bias, contrast: 8).cropped(to: e)
        }
    }
}

// MARK: - Materials

enum SurfaceGen {
    static func make(_ kind: SurfaceTexture, extent e: CGRect, size: CGFloat, seed: Int, a: RGBA = .nearWhite, b: RGBA = .ink) -> CIImage {
        let w = max(1, Int(e.width)), h = max(1, Int(e.height))
        func ramp(_ hex: [String], period: CGFloat) -> CIImage {
            guard let ctx = Gfx.context(w, h),
                  let g = CGGradient(colorsSpace: Gfx.sRGB, colors: hex.map { RGBA(hex: $0).cgColor } as CFArray, locations: nil) else { return FX.solid(.white, e) }
            var y: CGFloat = CGFloat(h)
            var flip = false
            while y > -period {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: flip ? y - period : y), end: CGPoint(x: 0, y: flip ? y : y - period), options: [])
                y -= period
                flip.toggle()
            }
            return ctx.makeImage().map { CIImage(cgImage: $0) } ?? FX.solid(.white, e)
        }
        func noiseMap(_ hex: [String], cells: Int, contrast: Double = 1.6) -> CIImage {
            FX.gradientMap(FX.controls(FX.smoothNoise(e, seed: seed, cells: cells), contrast: contrast), hex.map { RGBA(hex: $0) })
        }
        let cells = max(3, Int(e.width / max(8, size * 0.9)))
        let brushed = FX.noise(e, seed: seed, grainSize: 1, strength: 0.12).clampedToExtent()
            .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: size * 0.4, kCIInputAngleKey: 0.0]).cropped(to: e)

        switch kind {
        case .none:
            return FX.solid(.white, e)
        case .gold:
            return FX.blend(brushed, over: ramp(["5E4210", "B8862B", "F2D27A", "FFF1C1", "C99A3B", "8A6418", "D9B45A"], period: size * 1.05), mode: "CISoftLightBlendMode")
        case .goldLeaf:
            let base = ramp(["8A6418", "D9AE4E", "FFF0B8", "C9963A"], period: size * 0.9)
            let flakes = FX.noise(e, seed: seed, grainSize: 1, strength: 1)
                .applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: size * 0.12, kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)]).cropped(to: e)
            let leaf = FX.blend(FX.controls(FX.mono(flakes), brightness: 0.2, contrast: 0.6), over: base, mode: "CIOverlayBlendMode")
            let seams = FX.controls(FX.mono(flakes.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 4.0]).cropped(to: e)), contrast: 2).applyingFilter("CIColorInvert")
            return FX.blend(seams, over: leaf, mode: "CIMultiplyBlendMode")
        case .silver:
            return FX.blend(brushed, over: ramp(["4E5358", "A9AEB4", "F2F4F6", "FAFBFC", "8D9399", "C7CBCF"], period: size * 1.05), mode: "CISoftLightBlendMode")
        case .chrome:
            // Sky above a hard horizon, earth below: the classic airbrushed chrome.
            return ramp(["1B2B4A", "6E9BD6", "DCEBFF", "FFFFFF", "2A1C12", "8A5A2E", "E6B070", "FFF4D8"], period: size * 1.2)
        case .copper:
            return FX.blend(brushed, over: ramp(["4A230E", "A8592A", "F2B488", "FFD2AE", "B8693A", "D99060"], period: size * 1.05), mode: "CISoftLightBlendMode")
        case .bronze:
            let metal = ramp(["4A3214", "9A7034", "D9B06A", "7A5A26"], period: size)
            let patina = FX.controls(FX.smoothNoise(e, seed: seed &+ 11, cells: cells), brightness: -0.1, contrast: 3)
            let teal = FX.solid(RGBA(hex: "4FA38D"), e).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: metal, kCIInputMaskImageKey: patina])
            return FX.mix(metal, teal, 0.7)
        case .rust:
            let base = noiseMap(["2E1408", "6B2C10", "A8501F", "D08A45", "5A2A12"], cells: cells * 2, contrast: 2)
            return FX.grain(base, seed: seed, strength: 0.35, size: max(1, size * 0.02))
        case .stone:
            let base = noiseMap(["4A4A48", "7C7B76", "A9A79F", "C9C5BA"], cells: cells * 2)
            return FX.grain(base, seed: seed, strength: 0.3, size: max(1, size * 0.012))
        case .marble:
            let f = FillContent(style: .marble, colors: [RGBA(hex: "F2EFE9"), RGBA(hex: "B9B3A8"), RGBA(hex: "8C857A"), RGBA(hex: "E2DDD2")], seed: seed, intensity: 0.3)
            return Generators.render(f, size: e.size).map { CIImage(cgImage: $0) } ?? FX.solid(.white, e)
        case .wood:
            let f = FillContent(style: .stripes, colors: [RGBA(hex: "6B4423"), RGBA(hex: "8A5A2E"), RGBA(hex: "A7713E"), RGBA(hex: "7A4E28")], angle: 0, seed: seed, intensity: 0.15)
            let stripes = Generators.render(f, size: e.size).map { CIImage(cgImage: $0) } ?? FX.solid(RGBA(hex: "8A5A2E"), e)
            let grain = FX.displace(FX.blur(stripes, size * 0.01), by: FX.smoothNoise(e, seed: seed, cells: cells), scale: size * 0.6)
            return FX.grain(grain, seed: seed, strength: 0.15, size: 1)
        case .leather:
            let cellsImg = FX.noise(e, seed: seed, grainSize: 1, strength: 1)
                .applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: max(2, size * 0.035), kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)]).cropped(to: e)
            let pores = FX.controls(FX.mono(cellsImg), brightness: -0.1, contrast: 0.5)
            return FX.blend(pores, over: noiseMap(["3A2416", "5C3A22", "7A5032"], cells: cells), mode: "CIOverlayBlendMode")
        case .ice:
            let base = ramp(["4A8DB8", "9CD3F0", "F2FAFF", "7FB9DD"], period: size * 1.3)
            let facets = FX.noise(e, seed: seed, grainSize: 1, strength: 1)
                .applyingFilter("CICrystallize", parameters: [kCIInputRadiusKey: size * 0.07, kCIInputCenterKey: CIVector(x: e.midX, y: e.midY)]).cropped(to: e)
            let edges = FX.controls(FX.mono(facets.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 3.0]).cropped(to: e)), brightness: -0.1)
            return FX.blend(edges, over: FX.blend(FX.controls(FX.mono(facets), contrast: 0.5), over: base, mode: "CISoftLightBlendMode"), mode: "CIScreenBlendMode")
        case .fire:
            guard let ctx = Gfx.context(w, h) else { return FX.solid(RGBA(hex: "F28C28"), e) }
            Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: w, height: h),
                               ["4A0A04", "B5260E", "F2661C", "FFB43A", "FFF2B0"].map { RGBA(hex: $0) }, angle: 270)
            let grad = ctx.makeImage().map { CIImage(cgImage: $0) } ?? FX.solid(.white, e)
            return FX.displace(grad, by: FX.smoothNoise(e, seed: seed, cells: cells * 2), scale: size * 0.5)
        case .concrete:
            return FX.grain(noiseMap(["6E6C68", "8F8C86", "B0ADA6"], cells: cells * 3, contrast: 1.2), seed: seed, strength: 0.45, size: max(1, size * 0.01))
        case .paper:
            return FX.grain(FX.solid(RGBA(hex: "F1EBDD"), e), seed: seed, strength: 0.12, size: 1)
        case .galaxy:
            let stars = Generators.render(FillContent(style: .starfield, colors: [RGBA(hex: "120A2A"), RGBA(hex: "2A1458")], seed: seed, intensity: 0.4), size: e.size)
            let nebula = noiseMap(["120A2A", "4A1E78", "C0399A", "F2A9D8"], cells: cells, contrast: 2)
            let s = stars.map { CIImage(cgImage: $0) } ?? FX.solid(.black, e)
            return FX.blend(nebula, over: s, mode: "CIScreenBlendMode")
        case .smoke:
            return noiseMap(["1A1A1E", "4A4A52", "9A9AA2", "E6E6EA"], cells: cells, contrast: 1.8)
        case .glitter:
            let base = FX.solid(a.withLightness(max(0.25, a.hsl.l - 0.15)), e)
            let flecks = FX.controls(FX.noise(e, seed: seed, grainSize: max(1, size * 0.012), strength: 1), saturation: 0, brightness: -0.42, contrast: 10)
            let tinted = FX.blend(FX.solid(a.withLightness(0.85), e), over: flecks, mode: "CIMultiplyBlendMode")
            let big = FX.controls(FX.noise(e, seed: seed &+ 5, grainSize: max(1, size * 0.03), strength: 1), saturation: 0, brightness: -0.46, contrast: 14)
            return FX.blend(big, over: FX.blend(tinted, over: base, mode: "CIScreenBlendMode"), mode: "CIScreenBlendMode")
        case .thread:
            let lines = (CIFilter(name: "CIStripesGenerator", parameters: [
                "inputColor0": a.ciColor, "inputColor1": a.withLightness(max(0.1, a.hsl.l - 0.18)).ciColor,
                kCIInputWidthKey: max(1, size * 0.006), kCIInputSharpnessKey: 0.3
            ])?.outputImage ?? FX.solid(a, e)).transformed(by: CGAffineTransform(rotationAngle: .pi / 4)).cropped(to: e)
            return FX.grain(lines, seed: seed, strength: 0.18, size: 1)
        case .charred:
            let base = noiseMap(["0E0806", "2A1810", "4A2C17", "1A0F0A"], cells: cells * 2, contrast: 1.8)
            let embers = FX.controls(FX.noise(e, seed: seed, grainSize: max(1, size * 0.02), strength: 1), saturation: 0, brightness: -0.49, contrast: 14)
            let glow = FX.blend(FX.solid(RGBA(hex: "F2661C"), e), over: embers, mode: "CIMultiplyBlendMode")
            return FX.blend(glow, over: base, mode: "CIScreenBlendMode")
        case .chalk:
            let streaks = FX.noise(e, seed: seed, grainSize: 1, strength: 1).clampedToExtent()
                .applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: size * 0.12, kCIInputAngleKey: 0.25]).cropped(to: e)
            return FX.blend(FX.controls(FX.mono(streaks), brightness: 0.25, contrast: 2.5), over: FX.solid(RGBA(hex: "F4F4F0"), e), mode: "CIMultiplyBlendMode")
        case .stripes:
            return (CIFilter(name: "CIStripesGenerator", parameters: [
                "inputColor0": a.ciColor, "inputColor1": b.ciColor, kCIInputWidthKey: max(2, size * 0.09), kCIInputSharpnessKey: 1
            ])?.outputImage ?? FX.solid(a, e)).transformed(by: CGAffineTransform(rotationAngle: -.pi / 4)).cropped(to: e)
        case .checker:
            return (CIFilter(name: "CICheckerboardGenerator", parameters: [
                kCIInputCenterKey: CIVector(x: e.midX, y: e.midY), "inputColor0": a.ciColor, "inputColor1": b.ciColor,
                kCIInputWidthKey: max(3, size * 0.16), kCIInputSharpnessKey: 1
            ])?.outputImage ?? FX.solid(a, e)).cropped(to: e)
        case .plaid:
            func band(_ angle: CGFloat, _ c: RGBA, _ width: CGFloat) -> CIImage {
                (CIFilter(name: "CIStripesGenerator", parameters: [
                    "inputColor0": c.withAlpha(0.55).ciColor, "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
                    kCIInputWidthKey: width, kCIInputSharpnessKey: 1
                ])?.outputImage ?? CIImage.empty()).transformed(by: CGAffineTransform(rotationAngle: angle)).cropped(to: e)
            }
            let base = FX.solid(a, e)
            let w1 = max(2, size * 0.12), w2 = max(1, size * 0.03)
            let wide = band(0, b, w1).composited(over: band(.pi / 2, b, w1))
            let fine = band(0, b.withLightness(0.9), w2).composited(over: band(.pi / 2, b.withLightness(0.9), w2))
            return wide.composited(over: fine.composited(over: base))
        case .gradient:
            guard let ctx = Gfx.context(w, h) else { return FX.solid(a, e) }
            Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: w, height: h), [a, a.mixed(with: b, 0.5), b], angle: 90)
            return ctx.makeImage().map { CIImage(cgImage: $0) } ?? FX.solid(a, e)
        case .polkaDots:
            guard let ctx = Gfx.context(w, h) else { return FX.solid(a, e) }
            ctx.setFillColor(a.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setFillColor(b.cgColor)
            let gap = max(4, size * 0.16), r = gap * 0.28
            var row = 0
            var y: CGFloat = 0
            while y < CGFloat(h) + gap {
                var x: CGFloat = row % 2 == 0 ? 0 : gap / 2
                while x < CGFloat(w) + gap {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    x += gap
                }
                y += gap * 0.866
                row += 1
            }
            return ctx.makeImage().map { CIImage(cgImage: $0) } ?? FX.solid(a, e)
        }
    }
}

// MARK: - Presets

/// Named styles built from the cover's own palette, so a style always belongs to its cover.
struct TextStylePreset: Identifiable {
    let id: String
    let name: String
    let category: String
    /// Fonts that suit the style, tried in order when the user asks for "font too".
    let fonts: [String]
    /// Search words: materials, moods, colors and the genres the style suits.
    var tags: [String] = []
    let make: (PaletteRoles, RGBA) -> (TextStyle, RGBA?)

    func apply(to t: inout TextContent, palette: PaletteRoles) {
        let (style, color) = make(palette, t.color)
        var s = style
        s.presetName = name
        t.style = s
        if let color { t.color = color }
        t.texture = .none
    }

    static let categories = ["Metal", "Stone & Earth", "Elements", "Light", "Print & Paper", "Into the Photo", "Dimension", "Genre"]

    static let all: [TextStylePreset] = [
        // Metal
        TextStylePreset(id: "gilded", name: "Gilded Bevel", category: "Metal", fonts: ["Cinzel-Bold", "CinzelDecorative-Bold", "PlayfairDisplay-Black"]) { p, _ in
            var s = TextStyle(); s.surface = .gold; s.bevel = 0.6; s.gloss = 0.5; s.outline = 0.018; s.outlineColor = RGBA(hex: "3A2A0A"); s.outerGlow = 0.15; s.outerGlowColor = p.dark.withAlpha(0.8)
            return (s, nil)
        },
        TextStylePreset(id: "goldleaf", name: "Gold Leaf", category: "Metal", fonts: ["CormorantGaramond-Bold", "Cinzel-Bold"]) { _, _ in
            var s = TextStyle(); s.surface = .goldLeaf; s.bevel = 0.25; s.bevelStyle = .chisel; s.innerShadow = 0.3
            return (s, nil)
        },
        TextStylePreset(id: "silver", name: "Brushed Silver", category: "Metal", fonts: ["Michroma-Regular", "Syncopate-Bold", "Exo2-ExtraBold"]) { p, _ in
            var s = TextStyle(); s.surface = .silver; s.bevel = 0.5; s.bevelStyle = .chisel; s.gloss = 0.3; s.outline = 0.012; s.outlineColor = p.dark
            return (s, nil)
        },
        TextStylePreset(id: "chrome", name: "80s Chrome", category: "Metal", fonts: ["Audiowide-Regular", "Orbitron-Black", "Righteous-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .chrome; s.bevel = 0.7; s.gloss = 0.8; s.outline = 0.02; s.outlineColor = RGBA(hex: "F2F4FF")
            s.outline2 = 0.03; s.outline2Color = p.accent; s.extrude = 0.12; s.extrudeColor = p.dark
            return (s, nil)
        },
        TextStylePreset(id: "copper", name: "Copper Foil", category: "Metal", fonts: ["Prata-Regular", "BodoniModa-Bold"]) { _, _ in
            var s = TextStyle(); s.surface = .copper; s.bevel = 0.35; s.gloss = 0.35
            return (s, nil)
        },
        TextStylePreset(id: "bronze", name: "Oxidized Bronze", category: "Metal", fonts: ["MarcellusSC-Regular", "Cinzel-Bold"]) { _, _ in
            var s = TextStyle(); s.surface = .bronze; s.bevel = 0.55; s.bevelStyle = .chisel; s.innerShadow = 0.35; s.wear = .grunge; s.wearAmount = 0.25
            return (s, nil)
        },
        TextStylePreset(id: "rosegold", name: "Rose Gold Satin", category: "Metal", fonts: ["GreatVibes-Regular", "PlayfairDisplay-BoldItalic"]) { p, _ in
            var s = TextStyle(); s.surface = .copper; s.surfaceTint = 0.45; s.bevel = 0.3; s.bevelStyle = .pillow; s.gloss = 0.4; s.outerGlow = 0.2; s.outerGlowColor = p.light.withAlpha(0.7)
            return (s, RGBA(hex: "F0B8AE"))
        },
        // Stone & Earth
        TextStylePreset(id: "carved", name: "Carved Stone", category: "Stone & Earth", fonts: ["Cinzel-Bold", "MarcellusSC-Regular", "IM_FELL_English_SC"]) { _, _ in
            var s = TextStyle(); s.surface = .stone; s.bevel = 0.75; s.bevelStyle = .chisel; s.innerShadow = 0.45; s.photoTexture = 0.35
            return (s, nil)
        },
        TextStylePreset(id: "granite", name: "Weathered Granite", category: "Stone & Earth", fonts: ["Cinzel-Bold", "Anton-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .stone; s.bevel = 0.5; s.bevelStyle = .chisel; s.wear = .cracked; s.wearAmount = 0.5; s.innerShadow = 0.3
            return (s, nil)
        },
        TextStylePreset(id: "marble", name: "Marble Inlay", category: "Stone & Earth", fonts: ["BodoniModa-Black", "PlayfairDisplay-Black", "AbrilFatface-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .marble; s.bevel = 0.3; s.gloss = 0.3; s.outline = 0.015; s.outlineColor = p.accent.withLightness(0.6)
            return (s, nil)
        },
        TextStylePreset(id: "rusted", name: "Rusted Iron", category: "Stone & Earth", fonts: ["Anton-Regular", "BigShouldersDisplay-Black", "BebasNeue-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .rust; s.bevel = 0.45; s.wear = .eroded; s.wearAmount = 0.5; s.innerShadow = 0.3; s.photoTexture = 0.25
            return (s, nil)
        },
        TextStylePreset(id: "wood", name: "Wooden Sign", category: "Stone & Earth", fonts: ["Rye-Regular", "Oswald-Bold"]) { _, _ in
            var s = TextStyle(); s.surface = .wood; s.bevel = 0.4; s.extrude = 0.08; s.extrudeColor = RGBA(hex: "3A2412")
            return (s, nil)
        },
        TextStylePreset(id: "leather", name: "Embossed Leather", category: "Stone & Earth", fonts: ["CormorantGaramond-Bold", "Prata-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .leather; s.bevel = 0.35; s.bevelStyle = .pillow; s.innerShadow = 0.5
            return (s, nil)
        },
        // Elements
        TextStylePreset(id: "frozen", name: "Frozen", category: "Elements", fonts: ["Cinzel-Bold", "Orbitron-Black"]) { _, _ in
            var s = TextStyle(); s.surface = .ice; s.bevel = 0.55; s.bevelStyle = .chisel; s.gloss = 0.5; s.innerGlow = 0.4; s.outerGlow = 0.35; s.outerGlowColor = RGBA(hex: "9CD3F0", alpha: 0.8)
            return (s, nil)
        },
        TextStylePreset(id: "molten", name: "Molten", category: "Elements", fonts: ["Anton-Regular", "MetalMania-Regular", "PirataOne-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .fire; s.innerGlow = 0.5; s.innerGlowColor = RGBA(hex: "FFF2B0"); s.outerGlow = 0.6; s.outerGlowColor = RGBA(hex: "F2661C", alpha: 0.85)
            return (s, nil)
        },
        TextStylePreset(id: "smoke", name: "Smoke Wisps", category: "Elements", fonts: ["CormorantGaramond-SemiBold", "PoiretOne-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .smoke; s.surfaceTint = 0.3; s.photoErode = 0.4; s.lightWrap = 0.4; s.outerGlow = 0.25; s.outerGlowColor = p.light.withAlpha(0.5)
            return (s, nil)
        },
        TextStylePreset(id: "galaxy", name: "Galaxy", category: "Elements", fonts: ["Orbitron-Black", "Unbounded-ExtraBold", "Syne-ExtraBold"]) { _, _ in
            var s = TextStyle(); s.surface = .galaxy; s.outline = 0.012; s.outlineColor = RGBA(hex: "F2A9D8"); s.outerGlow = 0.3; s.outerGlowColor = RGBA(hex: "C0399A", alpha: 0.7)
            return (s, nil)
        },
        // Light
        TextStylePreset(id: "neon", name: "Neon Tube", category: "Light", fonts: ["Monoton-Regular", "Audiowide-Regular", "KaushanScript-Regular"]) { p, _ in
            var s = TextStyle(); s.innerGlow = 0.6; s.innerGlowColor = .white; s.outerGlow = 0.8; s.outerGlowColor = p.accent.withSaturation(0.9).withLightness(0.55)
            return (s, p.accent.withSaturation(0.9).withLightness(0.82))
        },
        TextStylePreset(id: "backlit", name: "Backlit", category: "Light", fonts: ["BebasNeue-Regular", "Anton-Regular", "Cinzel-Bold"]) { p, _ in
            var s = TextStyle(); s.outerGlow = 0.9; s.outerGlowColor = p.accent.withLightness(0.7); s.innerShadow = 0.2
            return (s, p.dark)
        },
        TextStylePreset(id: "softglow", name: "Soft Glow", category: "Light", fonts: ["PlayfairDisplay-Bold", "JosefinSans-Light"]) { p, c in
            var s = TextStyle(); s.outerGlow = 0.4; s.outerGlowColor = c.withAlpha(0.6); s.lightWrap = 0.3
            return (s, p.light)
        },
        TextStylePreset(id: "hologram", name: "Hologram", category: "Light", fonts: ["Orbitron-Black", "Michroma-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .chrome; s.surfaceTint = 0.35; s.glitch = 0.5; s.halftone = 0.25; s.outerGlow = 0.3; s.outerGlowColor = RGBA(hex: "48CAE4", alpha: 0.7)
            return (s, RGBA(hex: "B8F0FF"))
        },
        // Print & Paper
        TextStylePreset(id: "letterpress", name: "Letterpress", category: "Print & Paper", fonts: ["LibreCaslonDisplay-Regular", "CormorantGaramond-Bold", "Prata-Regular"]) { p, _ in
            var s = TextStyle(); s.innerShadow = 0.6; s.wear = .grunge; s.wearAmount = 0.25; s.photoTexture = 0.5
            return (s, p.dark)
        },
        TextStylePreset(id: "inkbleed", name: "Ink Bleed", category: "Print & Paper", fonts: ["SpecialElite-Regular", "IM_FELL_English_SC"]) { p, _ in
            var s = TextStyle(); s.wear = .inkBleed; s.wearAmount = 0.6; s.photoTexture = 0.4
            return (s, p.dark)
        },
        TextStylePreset(id: "woodcut", name: "Woodcut Print", category: "Print & Paper", fonts: ["UnifrakturMaguntia", "PirataOne-Regular", "Rye-Regular"]) { _, _ in
            var s = TextStyle(); s.wear = .distressed; s.wearAmount = 0.6; s.halftone = 0.3
            return (s, nil)
        },
        TextStylePreset(id: "halftone", name: "Halftone Pop", category: "Print & Paper", fonts: ["Bungee-Regular", "ArchivoBlack-Regular", "Anton-Regular"]) { p, _ in
            var s = TextStyle(); s.halftone = 0.6; s.outline = 0.035; s.outlineColor = p.dark; s.extrude = 0.15; s.extrudeColor = p.dark
            return (s, p.accent)
        },
        TextStylePreset(id: "riso", name: "Risograph", category: "Print & Paper", fonts: ["Syne-ExtraBold", "Unbounded-ExtraBold"]) { p, _ in
            var s = TextStyle(); s.glitch = 0.35; s.wear = .grunge; s.wearAmount = 0.35; s.halftone = 0.2
            return (s, p.accent)
        },
        TextStylePreset(id: "screenprint", name: "Worn Screen Print", category: "Print & Paper", fonts: ["BebasNeue-Regular", "LeagueGothic-Regular"]) { _, _ in
            var s = TextStyle(); s.wear = .scratched; s.wearAmount = 0.5; s.photoTexture = 0.3
            return (s, nil)
        },
        // Into the Photo
        TextStylePreset(id: "window", name: "Window to the Photo", category: "Into the Photo", fonts: ["Anton-Regular", "BebasNeue-Regular", "ArchivoBlack-Regular"]) { p, _ in
            var s = TextStyle(); s.photoFill = 1; s.outline = 0.02; s.outlineColor = p.light; s.outerGlow = 0.3; s.outerGlowColor = RGBA(0, 0, 0, 0.6)
            return (s, nil)
        },
        TextStylePreset(id: "lightwrap", name: "Light Wrapped", category: "Into the Photo", fonts: ["PlayfairDisplay-Bold", "Cinzel-Bold"]) { _, _ in
            var s = TextStyle(); s.lightWrap = 0.75; s.colorMatch = 0.4; s.photoTexture = 0.3
            return (s, nil)
        },
        TextStylePreset(id: "painted", name: "Painted On", category: "Into the Photo", fonts: ["PermanentMarker-Regular", "Oswald-Bold", "Anton-Regular"]) { _, _ in
            var s = TextStyle(); s.photoDisplace = 0.6; s.photoTexture = 0.65; s.wear = .grunge; s.wearAmount = 0.2
            return (s, nil)
        },
        TextStylePreset(id: "fog", name: "In the Fog", category: "Into the Photo", fonts: ["CormorantGaramond-SemiBold", "Cinzel-Regular", "JosefinSans-Light"]) { p, _ in
            var s = TextStyle(); s.photoErode = 0.45; s.lightWrap = 0.5; s.colorMatch = 0.3; s.outerGlow = 0.3; s.outerGlowColor = p.light.withAlpha(0.45)
            return (s, p.light)
        },
        TextStylePreset(id: "shadowed", name: "Lives in the Shadows", category: "Into the Photo", fonts: ["BebasNeue-Regular", "SixCaps", "Antonio-Bold"]) { _, _ in
            var s = TextStyle(); s.photoErode = 0.75; s.photoTexture = 0.4; s.colorMatch = 0.25
            return (s, nil)
        },
        // Dimension
        TextStylePreset(id: "block3d", name: "3D Block", category: "Dimension", fonts: ["Bungee-Regular", "ArchivoBlack-Regular", "Anton-Regular"]) { p, _ in
            var s = TextStyle(); s.extrude = 0.28; s.extrudeColor = p.dark.withLightness(0.18); s.bevel = 0.2
            return (s, nil)
        },
        TextStylePreset(id: "longshadow", name: "Long Shadow", category: "Dimension", fonts: ["Montserrat-Black", "BebasNeue-Regular"]) { p, _ in
            var s = TextStyle(); s.longShadow = 0.6; s.longShadowColor = p.dark.withAlpha(0.6)
            return (s, nil)
        },
        TextStylePreset(id: "stacked", name: "Stacked Outlines", category: "Dimension", fonts: ["BungeeInline-Regular", "Righteous-Regular", "Monoton-Regular"]) { p, _ in
            var s = TextStyle(); s.outline = 0.03; s.outlineColor = p.dark; s.outline2 = 0.04; s.outline2Color = p.accent; s.extrude = 0.1; s.extrudeColor = p.dark
            return (s, p.light)
        },
        TextStylePreset(id: "deco", name: "Art Deco Inline", category: "Dimension", fonts: ["Limelight-Regular", "PoiretOne-Regular", "BungeeShade-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .gold; s.outline = 0.015; s.outlineColor = p.dark; s.outline2 = 0.02; s.outline2Color = RGBA(hex: "E7C877")
            return (s, nil)
        },
        // Genre
        TextStylePreset(id: "bloodrust", name: "Blood Rust", category: "Genre", fonts: ["Creepster-Regular", "Nosifer-Regular", "MetalMania-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .rust; s.surfaceTint = 0.6; s.wear = .eroded; s.wearAmount = 0.65; s.innerShadow = 0.4; s.outerGlow = 0.25; s.outerGlowColor = RGBA(hex: "3A0000", alpha: 0.8)
            return (s, RGBA(hex: "8E1020"))
        },
        TextStylePreset(id: "bone", name: "Cracked Bone", category: "Genre", fonts: ["Butcherman-Regular", "Cinzel-Bold", "Creepster-Regular"]) { _, _ in
            var s = TextStyle(); s.surface = .stone; s.surfaceTint = 0.5; s.bevel = 0.35; s.wear = .cracked; s.wearAmount = 0.7; s.innerShadow = 0.4
            return (s, RGBA(hex: "E9E0C8"))
        },
        TextStylePreset(id: "haunted", name: "Haunted", category: "Genre", fonts: ["IM_FELL_English_SC", "SpecialElite-Regular", "CormorantGaramond-Bold"]) { p, _ in
            var s = TextStyle(); s.photoErode = 0.5; s.lightWrap = 0.5; s.photoTexture = 0.35; s.outerGlow = 0.3; s.outerGlowColor = RGBA(hex: "C8E6E0", alpha: 0.5); s.wear = .scratched; s.wearAmount = 0.3
            return (s, p.light.withLightness(0.9))
        },
        TextStylePreset(id: "steel", name: "Thriller Steel", category: "Genre", fonts: ["BebasNeue-Regular", "Antonio-Bold", "BigShouldersDisplay-Black"]) { _, _ in
            var s = TextStyle(); s.surface = .silver; s.bevel = 0.3; s.bevelStyle = .chisel; s.wear = .scratched; s.wearAmount = 0.45; s.photoTexture = 0.3
            return (s, nil)
        },
        TextStylePreset(id: "noir", name: "Noir Fade", category: "Genre", fonts: ["SixCaps", "BebasNeue-Regular", "LeagueGothic-Regular"]) { p, _ in
            var s = TextStyle(); s.photoErode = 0.55; s.colorMatch = 0.3; s.wear = .grunge; s.wearAmount = 0.3
            return (s, p.light)
        },
        TextStylePreset(id: "epic", name: "Epic Fantasy", category: "Genre", fonts: ["CinzelDecorative-Black", "Cinzel-Bold", "UncialAntiqua-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .gold; s.bevel = 0.65; s.gloss = 0.45; s.extrude = 0.1; s.extrudeColor = RGBA(hex: "2A1A06"); s.outerGlow = 0.35; s.outerGlowColor = p.accent.withAlpha(0.6)
            return (s, nil)
        },
        TextStylePreset(id: "romance", name: "Romance Satin", category: "Genre", fonts: ["PinyonScript-Regular", "GreatVibes-Regular", "Allura-Regular"]) { p, _ in
            var s = TextStyle(); s.bevel = 0.25; s.bevelStyle = .pillow; s.gloss = 0.35; s.outerGlow = 0.3; s.outerGlowColor = p.light.withAlpha(0.6); s.lightWrap = 0.3
            return (s, p.light)
        },
        TextStylePreset(id: "scifiplate", name: "Sci-Fi Plate", category: "Genre", fonts: ["Orbitron-Black", "Exo2-ExtraBold", "Michroma-Regular"]) { p, _ in
            var s = TextStyle(); s.surface = .silver; s.bevel = 0.6; s.bevelStyle = .chisel; s.innerGlow = 0.35; s.innerGlowColor = p.accent.withLightness(0.7); s.glitch = 0.12
            return (s, nil)
        },
        TextStylePreset(id: "yapop", name: "YA Pop", category: "Genre", fonts: ["Montserrat-Black", "Unbounded-ExtraBold", "Bungee-Regular"]) { p, _ in
            var s = TextStyle(); s.outline = 0.04; s.outlineColor = .nearWhite; s.extrude = 0.18; s.extrudeColor = p.accent.withLightness(0.35)
            return (s, p.accent)
        },
        TextStylePreset(id: "cozy", name: "Cozy Painted", category: "Genre", fonts: ["KaushanScript-Regular", "Sacramento-Regular", "Righteous-Regular"]) { p, _ in
            var s = TextStyle(); s.outline = 0.03; s.outlineColor = RGBA(hex: "FFF6E6"); s.extrude = 0.08; s.extrudeColor = p.dark.withLightness(0.3); s.wear = .grunge; s.wearAmount = 0.15
            return (s, p.accent)
        },
        TextStylePreset(id: "literary", name: "Literary Ink", category: "Genre", fonts: ["CormorantGaramond-MediumItalic", "LibreCaslonDisplay-Regular", "DMSerifDisplay-Italic"]) { _, _ in
            var s = TextStyle(); s.photoTexture = 0.55; s.colorMatch = 0.3; s.wear = .grunge; s.wearAmount = 0.15
            return (s, nil)
        }
    ]

    static func preset(_ id: String) -> TextStylePreset? { StyleLibrary.shared.preset(id) }

    /// Styles that suit each genre's titles, used by the cover generator.
    static func forGenre(_ g: Genre) -> [String] {
        switch g {
        case .thriller: return ["steel", "noir", "shadowed", "screenprint", "lightwrap"]
        case .mystery: return ["letterpress", "fog", "noir", "lightwrap"]
        case .horror: return ["bloodrust", "haunted", "bone", "shadowed"]
        case .romance: return ["romance", "rosegold", "softglow", "lightwrap"]
        case .fantasy: return ["epic", "gilded", "carved", "goldleaf", "frozen"]
        case .scienceFiction: return ["scifiplate", "chrome", "neon", "hologram", "galaxy"]
        case .literary: return ["literary", "letterpress", "lightwrap", "inkbleed"]
        case .historical: return ["goldleaf", "carved", "bronze", "letterpress"]
        case .youngAdult: return ["yapop", "neon", "stacked", "halftone"]
        case .cozy: return ["cozy", "softglow", "wood", "rosegold"]
        case .nonfiction: return ["block3d", "longshadow", "halftone"]
        case .memoir: return ["literary", "fog", "letterpress"]
        }
    }
}
