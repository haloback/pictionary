import CoreImage
import XCTest
@testable import Colophon

final class ColorScienceTests: XCTestCase {
    func testContrastExtremes() {
        XCTAssertEqual(RGBA.white.contrast(with: .black), 21, accuracy: 0.01)
        XCTAssertEqual(RGBA.white.contrast(with: .white), 1, accuracy: 0.001)
    }

    func testHexRoundTrip() {
        XCTAssertEqual(RGBA(hex: "E4572E").hex, "#E4572E")
        XCTAssertEqual(RGBA(hex: "#0b1d3a").hex, "#0B1D3A")
    }

    func testHSLRoundTrip() {
        for hex in ["3A7BD5", "E4572E", "1E3D2F", "F2ECDF", "808080"] {
            let c = RGBA(hex: hex)
            let h = c.hsl
            XCTAssertLessThan(c.distance(to: RGBA(h: h.h, s: h.s, l: h.l)), 1, hex)
        }
    }

    func testComplementIsAcrossTheWheel() {
        let c = RGBA(h: 30, s: 0.7, l: 0.5)
        XCTAssertEqual(c.complement.hsl.h, 210, accuracy: 1)
    }

    func testOppositeHasUsableContrast() {
        for hex in ["1B2A4A", "F2A541", "D7263D", "F7F4EE"] {
            let c = RGBA(hex: hex)
            XCTAssertGreaterThan(ColorAdvisor.opposite(c).contrast(with: c), 2.0, hex)
        }
    }

    func testBestTextMeetsMinimumWhenPossible() {
        let bg = RGBA(hex: "2B2D31")
        let pick = ColorAdvisor.bestText(on: bg, candidates: [RGBA(hex: "3A3D42"), RGBA(hex: "F2ECDF")], minimum: 4.5)
        XCTAssertGreaterThanOrEqual(pick.contrast(with: bg), 4.5)
    }

    func testHarmoniesProduceColors() {
        for h in Harmony.allCases { XCTAssertGreaterThanOrEqual(h.colors(from: RGBA(hex: "E4572E")).count, 3) }
    }

    func testPaletteRolesAreOrdered() {
        let p = PaletteRoles([RGBA(hex: "F2ECDF"), RGBA(hex: "1B2A4A"), RGBA(hex: "E4572E")])
        XCTAssertLessThan(p.dark.luminance, p.light.luminance)
        XCTAssertGreaterThan(p.light.contrast(with: p.dark), 7)
    }

    func testPaletteExtraction() throws {
        let ctx = try XCTUnwrap(Gfx.context(100, 100))
        ctx.setFillColor(RGBA(hex: "1B2A4A").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        ctx.setFillColor(RGBA(hex: "F2A541").cgColor)
        ctx.fill(CGRect(x: 0, y: 60, width: 100, height: 40))
        let img = try XCTUnwrap(ctx.makeImage())
        let pal = PaletteExtractor.extract(img)
        XCTAssertTrue(pal.contains { $0.distance(to: RGBA(hex: "1B2A4A")) < 5 })
        XCTAssertTrue(pal.contains { $0.distance(to: RGBA(hex: "F2A541")) < 5 })
    }
}

final class EffectLibraryTests: XCTestCase {
    func testMoreThanTwoThousandUniqueEffects() {
        let lib = EffectLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.presets.count, 2000)
        XCTAssertEqual(Set(lib.presets.map(\.id)).count, lib.presets.count)
    }

    func testEveryFamilyIsPopulated() {
        for f in EffectFamily.allCases {
            XCTAssertFalse(EffectLibrary.shared.search("", family: f).isEmpty, f.rawValue)
        }
    }

    func testGenreEffectReferencesResolve() {
        for g in Genre.allCases {
            for id in GenreStyle.of(g).effects {
                XCTAssertNotNil(EffectLibrary.shared.preset(id), "\(g): \(id)")
            }
        }
        for id in ["tone.vignette.3", "tone.background-blur.4", "tone.background-blur.3", "tone.darken.2", "tone.fine-grain.3", "print.dot-screen.1.color"] {
            XCTAssertNotNil(EffectLibrary.shared.preset(id), id)
        }
    }

    func testEffectsRenderAcrossFamilies() throws {
        let ctx = try XCTUnwrap(Gfx.context(64, 96))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: 64, height: 96), [RGBA(hex: "1B2A4A"), RGBA(hex: "F2A541")], angle: 45)
        let base = CIImage(cgImage: try XCTUnwrap(ctx.makeImage()))
        let presets = EffectLibrary.shared.presets
        for p in stride(from: 0, to: presets.count, by: 23).map({ presets[$0] }) {
            let out = p.apply(base, EffectContext(scale: 0.1, seed: 1)).cropped(to: base.extent)
            XCTAssertNotNil(Gfx.render(out, extent: base.extent), p.id)
        }
    }
}

final class TypographyTests: XCTestCase {
    func testBalancedBreaks() {
        XCTAssertEqual(TitleBreaker.balanced("The House at the End of Hollow Lane", lines: 2), "The House at the\nEnd of Hollow Lane")
        XCTAssertEqual(TitleBreaker.balanced("Salt", lines: 3), "Salt")
    }

    func testStackedTitles() {
        XCTAssertEqual(TitleBreaker.auto("Cold Black River", stacked: true), "Cold\nBlack\nRiver")
    }

    func testAutoFitStaysInsideBox() {
        let t = TextContent(text: "THE SALT\nORCHARD", role: .title, fontName: "Didot")
        let box = CGSize(width: 1200, height: 600)
        let size = TextRenderer.fittedSize(t, box: box)
        let m = TextRenderer.measure(t, size: size, wrapWidth: nil)
        XCTAssertLessThanOrEqual(m.width, box.width + 1)
        XCTAssertLessThanOrEqual(m.height, box.height + 1)
        XCTAssertGreaterThan(m.width, box.width * 0.8)
    }

    func testTextRenders() throws {
        var t = TextContent(text: "Night Ferry", role: .title, fontName: "Futura-Bold")
        t.glowColor = RGBA(hex: "F2A541")
        t.strokeColor = .nearBlack
        t.gradientTo = RGBA(hex: "E4572E")
        let (img, pad) = try XCTUnwrap(TextRenderer.render(t, box: CGSize(width: 800, height: 200), canvasHeight: 2560))
        XCTAssertGreaterThan(pad, 0)
        XCTAssertGreaterThan(img.width, 800)
    }
}

final class RenderingTests: XCTestCase {
    func testEveryFillStyleRenders() {
        for s in FillStyle.allCases {
            let f = FillContent(style: s, colors: [RGBA(hex: "1B2A4A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")])
            XCTAssertNotNil(Generators.render(f, size: CGSize(width: 120, height: 192)), s.rawValue)
        }
    }

    func testEveryShapeRenders() {
        for k in ShapeKind.allCases {
            let s = ShapeContent(kind: k, fill: .nearWhite, stroke: RGBA(hex: "E4572E"))
            XCTAssertNotNil(ShapeRenderer.render(s, size: CGSize(width: 100, height: 100), canvasWidth: 1600), k.rawValue)
        }
    }

    func testDocumentRoundTripsThroughJSON() throws {
        var doc = CoverDocument()
        doc.book.title = "The Salt Orchard"
        doc.layers = [.fill(.meshBlend, colors: [.ink, .paper]), .text("Salt", role: .title, frame: NRect(0.1, 0.1, 0.8, 0.2), font: "Didot", color: .nearWhite)]
        doc.layers[1].effects = [EffectInstance(presetID: "tone.noir.2")]
        let data = try JSONEncoder().encode(doc)
        let back = try JSONDecoder().decode(CoverDocument.self, from: data)
        XCTAssertEqual(back.layers, doc.layers)
        XCTAssertEqual(back.book, doc.book)
    }

    func testTypographicCoversWithoutPhotos() {
        var base = CoverDocument()
        base.book = BookInfo(title: "A Map of Quiet Things", subtitle: "", author: "Ines Valcourt", genre: .literary)
        let docs = CoverComposer.variations(base: base, count: 10, seed: 42)
        XCTAssertEqual(docs.count, 10)
        XCTAssertGreaterThan(Set(docs.map(\.archetypeName)).count, 4, "variations should be diverse")
        for d in docs {
            XCTAssertNotNil(d.textLayer(role: .title))
            XCTAssertNotNil(d.textLayer(role: .author))
            XCTAssertNotNil(CoverRenderer.shared.render(d, size: CGSize(width: 160, height: 256)))
        }
    }

    func testPhotoCoversForEveryGenre() throws {
        let ctx = try XCTUnwrap(Gfx.context(400, 600))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: 400, height: 600), [RGBA(hex: "13404A"), RGBA(hex: "F2A541")], angle: 90)
        ctx.setFillColor(RGBA(hex: "121417").cgColor)
        ctx.fillEllipse(in: CGRect(x: 120, y: 120, width: 160, height: 300))
        let data = try XCTUnwrap(AssetStore.encode(try XCTUnwrap(ctx.makeImage())))
        var base = CoverDocument()
        _ = base.addAsset(data)
        for g in Genre.allCases {
            base.book = BookInfo(title: "Cold Black River", author: "Dara Okonkwo", genre: g)
            let docs = CoverComposer.variations(base: base, count: 4, seed: 7)
            for d in docs {
                XCTAssertNotNil(CoverRenderer.shared.render(d, size: CGSize(width: 120, height: 192)), "\(g) \(d.archetypeName)")
            }
        }
    }

    func testPreflightFlagsMissingTitle() {
        let doc = CoverDocument()
        let issues = Preflight.run(doc, spec: StoreSpec.all[0], background: nil, full: nil)
        XCTAssertTrue(issues.contains { $0.severity == .fail })
    }
}

final class FeatureTests: XCTestCase {
    private func sampleDoc() -> CoverDocument {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Salt Orchard", author: "Ines Valcourt", series: "Orchard Cycle", genre: .literary)
        return CoverComposer.variations(base: base, count: 1, seed: 3)[0]
    }

    func testMockupsRender() {
        let doc = sampleDoc()
        for k in MockupKind.allCases {
            let img = MockupRenderer.render(k, doc: doc)
            XCTAssertNotNil(img, k.rawValue)
            XCTAssertEqual(img?.width, Int(k.pixelSize.width), k.rawValue)
        }
    }

    func testSeriesRetitleKeepsDesign() {
        let doc = sampleDoc()
        let next = SeriesKit.retitle(doc, title: "Winter Graft", number: 2)
        XCTAssertEqual(next.book.title, "Winter Graft")
        XCTAssertEqual(next.layers.count, doc.layers.count)
        let title = next.textLayer(role: .title)?.textContent?.text.replacingOccurrences(of: "\n", with: " ")
        XCTAssertEqual(title?.lowercased(), "winter graft")
        XCTAssertEqual(next.book.series, "Orchard Cycle, Book 2")
        XCTAssertNotNil(SeriesKit.lineup([doc, next], coverHeight: 160))
    }

    func testAdjustmentsRender() {
        var doc = CoverDocument()
        var l = Layer.fill(.meshBlend, colors: [RGBA(hex: "1B2A4A"), RGBA(hex: "F2A541")])
        l.adjust = Adjustments(exposure: 0.4, contrast: 0.3, saturation: -0.5, warmth: 0.6, sharpness: 0.5, blur: 0.2)
        doc.layers = [l]
        XCTAssertNotNil(CoverRenderer.shared.render(doc, size: CGSize(width: 100, height: 160)))
    }

    func testOlderProjectsStillOpen() throws {
        // A layer and document missing newer keys (adjust, fonts) must still decode.
        let json = """
        {"book":{"title":"Old","subtitle":"","author":"A","series":"","tagline":"","genre":"literary"},
         "layers":[{"name":"T","content":{"text":{"_0":{"text":"Old","role":"title","fontName":"Didot","fontSize":0.05,"autoFit":true,"tracking":0,"lineHeight":1,"alignment":"center","letterCase":"upper","color":{"r":1,"g":1,"b":1,"a":1},"strokeWidth":0.02,"glowRadius":0.2,"behindSubject":false}}},"frame":{"x":0.1,"y":0.1,"w":0.8,"h":0.2}}]}
        """
        let doc = try JSONDecoder().decode(CoverDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.layers.count, 1)
        XCTAssertTrue(doc.layers[0].adjust.isIdentity)
        XCTAssertTrue(doc.fonts.isEmpty)
    }
}

final class PrintAndRemixTests: XCTestCase {
    private func sampleDoc() -> CoverDocument {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Salt Orchard", author: "Ines Valcourt", genre: .literary)
        return CoverComposer.variations(base: base, count: 1, seed: 5)[0]
    }

    func testSpineWidthFollowsPageCount() {
        var s = PrintSettings()
        s.pageCount = 300
        s.paper = .cream
        XCTAssertEqual(s.spineWidth, 0.75, accuracy: 0.0001)
        XCTAssertEqual(s.fullWidth, 6 * 2 + 0.75 + 0.25, accuracy: 0.0001)
        XCTAssertEqual(s.fullHeight, 9.25, accuracy: 0.0001)
        s.pageCount = 60
        XCTAssertFalse(s.spineHasText)
    }

    func testWrapRendersAtSheetSize() throws {
        var doc = sampleDoc()
        doc.paperback.blurb = "A woman inherits an orchard by the sea and learns why nothing there has ever been allowed to bloom."
        doc.paperback.quote = "Luminous and unsettling."
        let img = try XCTUnwrap(PrintWrap.render(doc, dpi: 40, guides: true))
        XCTAssertEqual(img.width, Int((doc.paperback.fullWidth * 40).rounded()))
        XCTAssertEqual(img.height, Int((doc.paperback.fullHeight * 40).rounded()))
        XCTAssertTrue(PrintWrap.blurbFits(doc))
    }

    func testPDFExport() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("colophon-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(PrintWrap.exportPDF(sampleDoc(), to: url))
        let size = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertGreaterThan(size, 10_000)
    }

    func testRemixKeepsStructureAndVaries() {
        let doc = sampleDoc()
        let remixes = Remixer.remix(doc, count: 6, seed: 9)
        XCTAssertEqual(remixes.count, 6)
        for r in remixes {
            XCTAssertNotNil(r.textLayer(role: .title))
            XCTAssertFalse(r.archetypeName.isEmpty)
            XCTAssertNotNil(CoverRenderer.shared.render(r, size: CGSize(width: 100, height: 160)))
        }
        XCTAssertGreaterThan(Set(remixes.map(\.archetypeName)).count, 2)
    }

    func testEraseBrushClearsPixels() throws {
        let ctx = try XCTUnwrap(Gfx.context(100, 100))
        ctx.setFillColor(RGBA(hex: "E4572E").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        let img = try XCTUnwrap(ctx.makeImage())
        let stroke = MaskStroke(restore: false, radius: 0.2, points: [NPoint(x: 0.5, y: 0.5)])
        let out = try XCTUnwrap(MaskPainter.apply([stroke], to: img, base: nil, invertBase: false))
        let center = PixelSampler.pixels(out, maxSide: 100)
        let i = (50 * center.w + 50) * 4
        XCTAssertLessThan(center.data[i + 3], 20, "center should be erased")
        XCTAssertGreaterThan(center.data[3], 240, "corner should remain")
    }
}

final class FinishAndPromoTests: XCTestCase {
    private func sampleDoc() -> CoverDocument {
        var base = CoverDocument()
        base.book = BookInfo(title: "Cold Black River", author: "Dara Okonkwo", tagline: "Some debts run deep.", genre: .thriller)
        return CoverComposer.variations(base: base, count: 1, seed: 11)[0]
    }

    func testEveryTextFinishRenders() {
        for tex in TextTexture.allCases {
            var t = TextContent(text: "Night Ferry", role: .title, fontName: "Futura-Bold", color: RGBA(hex: "F2A541"))
            t.texture = tex
            XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 600, height: 160), canvasHeight: 2560), tex.rawValue)
        }
    }

    func testArchedTextFitsItsBox() {
        for arc in [-1.0, -0.4, 0.35, 1.0] {
            var t = TextContent(text: "THE SALT ORCHARD", role: .title, fontName: "Didot")
            t.arc = arc
            let box = CGSize(width: 900, height: 300)
            let size = TextRenderer.fittedSize(t, box: box)
            let m = TextRenderer.measure(t, size: size, wrapWidth: nil)
            XCTAssertLessThanOrEqual(m.height + m.width * TextRenderer.sagFactor(arc), box.height + 1, "arc \(arc)")
            XCTAssertNotNil(TextRenderer.render(t, box: box, canvasHeight: 2560))
        }
    }

    func testAdsRenderAtTheirSizes() {
        let doc = sampleDoc()
        for kind in AdKind.allCases {
            let img = AdRenderer.render(kind, doc: doc, headline: AdRenderer.defaultHeadline(doc), cta: "Read now")
            XCTAssertEqual(img?.width, Int(kind.pixelSize.width), kind.rawValue)
            XCTAssertEqual(img?.height, Int(kind.pixelSize.height), kind.rawValue)
        }
        XCTAssertEqual(AdRenderer.defaultHeadline(doc), "Some debts run deep.")
    }

    func testSpineArtComesFromTheWrap() throws {
        let spine = try XCTUnwrap(MockupRenderer.spineImage(sampleDoc(), coverHeight: 900))
        XCTAssertGreaterThan(spine.height, spine.width * 5)
    }

    func testTextureSurvivesSaveAndOpen() throws {
        var t = TextContent(text: "Gilded", role: .title)
        t.texture = .gold
        t.arc = 0.3
        let back = try JSONDecoder().decode(TextContent.self, from: JSONEncoder().encode(t))
        XCTAssertEqual(back, t)
    }
}

final class StyleEngineTests: XCTestCase {
    func testBundledFontsRegister() {
        XCTAssertGreaterThanOrEqual(BundledFonts.entries.count, 60)
        for name in ["Cinzel-Bold", "BebasNeue-Regular", "Creepster-Regular", "Orbitron-Black", "GreatVibes-Regular", "PlayfairDisplay-Black"] {
            XCTAssertTrue(FontCatalog.isAvailable(name), name)
        }
        XCTAssertEqual(Set(BundledFonts.entries.map(\.id)).count, BundledFonts.entries.count)
    }

    func testPresetsAreUniqueAndGenreReferencesResolve() {
        XCTAssertGreaterThanOrEqual(TextStylePreset.all.count, 40)
        XCTAssertEqual(Set(TextStylePreset.all.map(\.id)).count, TextStylePreset.all.count)
        for g in Genre.allCases {
            for id in TextStylePreset.forGenre(g) { XCTAssertNotNil(TextStylePreset.preset(id), "\(g) \(id)") }
        }
        for p in TextStylePreset.all {
            XCTAssertTrue(p.fonts.contains(where: FontCatalog.isAvailable), "\(p.name) has no available font")
        }
    }

    func testEveryPresetRendersOverAPhoto() throws {
        let palette = PaletteRoles([RGBA(hex: "13404A"), RGBA(hex: "F2A541"), RGBA(hex: "F2ECDF")])
        let bgCtx = try XCTUnwrap(Gfx.context(300, 170))
        Gfx.linearGradient(bgCtx, CGRect(x: 0, y: 0, width: 300, height: 170), [RGBA(hex: "0C2229"), RGBA(hex: "F1B15A")], angle: 90)
        let bg = try XCTUnwrap(bgCtx.makeImage())
        for p in TextStylePreset.all {
            var t = TextContent(text: "Salt Orchard", role: .title, fontName: p.fonts.first(where: FontCatalog.isAvailable) ?? "Didot", color: palette.light)
            p.apply(to: &t, palette: palette)
            let (img, _) = try XCTUnwrap(TextRenderer.render(t, box: CGSize(width: 260, height: 90), canvasHeight: 1000), p.name)
            if t.style.needsScene {
                let patch = try XCTUnwrap(bg.cropping(to: CGRect(x: 0, y: 0, width: min(300, img.width), height: min(170, img.height))))
                let sized = try XCTUnwrap(Gfx.context(img.width, img.height))
                sized.draw(patch, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
                XCTAssertNotNil(TextStyler.blendIntoScene(img, background: try XCTUnwrap(sized.makeImage()), style: t.style, fontSize: 70), p.name)
            }
        }
    }

    func testEverySurfaceAndWearRenders() {
        let e = CGRect(x: 0, y: 0, width: 120, height: 60)
        for s in SurfaceTexture.allCases {
            XCTAssertNotNil(Gfx.render(SurfaceGen.make(s, extent: e, size: 40, seed: 3), extent: e), s.rawValue)
        }
        let mask = CIImage(color: .white).cropped(to: e)
        for w in WearKind.allCases {
            XCTAssertNotNil(Gfx.render(TextStyler.wear(mask, kind: w, amount: 0.5, size: 40, seed: 2, extent: e), extent: e), w.rawValue)
        }
    }

    func testStyledTitleRendersOnFullCover() {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Salt Orchard", author: "Ines Valcourt", genre: .fantasy)
        let docs = CoverComposer.variations(base: base, count: 6, seed: 4)
        XCTAssertTrue(docs.contains { $0.textLayer(role: .title)?.textContent?.style.isActive == true }, "genre styles should be applied")
        for d in docs { XCTAssertNotNil(CoverRenderer.shared.render(d, size: CGSize(width: 200, height: 320))) }
    }

    func testStyleSurvivesSaveAndOpen() throws {
        var t = TextContent(text: "Gilt", role: .title)
        TextStylePreset.preset("epic")!.apply(to: &t, palette: PaletteRoles([]))
        let back = try JSONDecoder().decode(TextContent.self, from: JSONEncoder().encode(t))
        XCTAssertEqual(back.style, t.style)
    }
}

final class StyleLibraryTests: XCTestCase {
    func testThousandsOfUniqueStyles() {
        let lib = StyleLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.all.count, 2000)
        XCTAssertEqual(Set(lib.all.map(\.id)).count, lib.all.count, "style ids must be unique")
        for f in lib.families {
            XCTAssertFalse(lib.search("", family: f.id, genre: nil).isEmpty, f.name)
        }
    }

    func testSearchAndSimilar() {
        let lib = StyleLibrary.shared
        XCTAssertFalse(lib.search("gold", family: nil, genre: nil).isEmpty)
        XCTAssertFalse(lib.search("neon magenta", family: nil, genre: nil).isEmpty)
        XCTAssertFalse(lib.search("drips", family: nil, genre: .horror).isEmpty)
        let first = lib.search("", family: "metal", genre: nil)[0]
        XCTAssertFalse(lib.similar(to: first.id).isEmpty)
        for g in Genre.allCases { XCTAssertFalse(lib.search("", family: nil, genre: g).isEmpty, g.rawValue) }
    }

    func testGeneratedStylesRender() throws {
        let palette = PaletteRoles([RGBA(hex: "1B2A4A"), RGBA(hex: "F2A541"), RGBA(hex: "F2ECDF")])
        let lib = StyleLibrary.shared.all
        for p in stride(from: 0, to: lib.count, by: 37).map({ lib[$0] }) {
            var t = TextContent(text: "Salt", role: .title, fontName: p.fonts.first(where: FontCatalog.isAvailable) ?? "Didot", color: palette.light)
            p.apply(to: &t, palette: palette)
            XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 160, height: 70), canvasHeight: 600), p.id)
        }
    }

    func testDripsRunBelowTheLetters() throws {
        var t = TextContent(text: "DRIP", role: .title, fontName: "Anton-Regular", color: RGBA(hex: "8E1020"))
        let (plain, plainPad) = try XCTUnwrap(TextRenderer.render(t, box: CGSize(width: 300, height: 120), canvasHeight: 1000))
        t.style.drips = 0.9
        let (dripped, pad) = try XCTUnwrap(TextRenderer.render(t, box: CGSize(width: 300, height: 120), canvasHeight: 1000))
        XCTAssertGreaterThan(pad, plainPad)
        // How far below the top of the text box the ink reaches, in pixels.
        func lowestInk(_ img: CGImage, pad: CGFloat) -> Double {
            let p = PixelSampler.pixels(img, maxSide: 4000)
            for row in stride(from: p.h - 1, through: 0, by: -1) {
                for x in 0..<p.w where p.data[(row * p.w + x) * 4 + 3] > 40 { return Double(row) - Double(pad) }
            }
            return 0
        }
        XCTAssertGreaterThan(lowestInk(dripped, pad: pad), lowestInk(plain, pad: plainPad) + 4)
    }

    func testNewSurfacesUsePatternColors() throws {
        let e = CGRect(x: 0, y: 0, width: 80, height: 80)
        for s in [SurfaceTexture.stripes, .checker, .polkaDots] {
            let img = try XCTUnwrap(Gfx.render(SurfaceGen.make(s, extent: e, size: 40, seed: 1, a: RGBA(hex: "E4572E"), b: RGBA(hex: "1B2A4A")), extent: e))
            let pal = PaletteExtractor.extract(img)
            XCTAssertTrue(pal.contains { $0.distance(to: RGBA(hex: "E4572E")) < 20 }, s.rawValue)
        }
    }
}

/// Renders a gallery of real style samples when COLOPHON_SAMPLES names an output folder (used by CI).
final class SampleRenderTests: XCTestCase {
    func testRenderStyleSamples() throws {
        guard let dir = ProcessInfo.processInfo.environment["COLOPHON_SAMPLES"] else { throw XCTSkip("COLOPHON_SAMPLES not set") }
        let out = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let lib = StyleLibrary.shared
        let curated = ["gilded", "epic", "chrome", "carved", "rusted", "frozen", "molten", "neon", "letterpress", "window",
                       "fog", "bloodrust", "haunted", "romance", "scifiplate", "yapop", "block3d", "deco", "goldleaf", "galaxy"]
        let searches = ["ink drawing black bold", "engraving sepia medium", "pencil sketch", "blood drips long", "molten gold drips", "embroidery puffy", "balloon glossy", "sticker glitter", "triple stack",
                        "exploded glass", "smoke column", "polka dots sticker", "plaid outlined", "broken glitch halftone", "wood burn scorched",
                        "chalk smudged", "to glow", "outline neon wide", "backlit eclipse", "marble carved", "towering 3d chrome",
                        "gold leaf inflated", "rust eroded", "ice blazing", "copper chiseled raised", "letterpress heavy", "painted on full"]
        var picks: [TextStylePreset] = curated.compactMap { lib.preset($0) }
        for q in searches { if let p = lib.search(q, family: nil, genre: nil).first, !picks.contains(where: { $0.id == p.id }) { picks.append(p) } }

        let grounds: [(FillStyle, [RGBA])] = [
            (.smoke, [RGBA(hex: "0B1D3A"), RGBA(hex: "23308C"), RGBA(hex: "7B83EB")]),
            (.meshBlend, [RGBA(hex: "1E3D2F"), RGBA(hex: "0B4A33"), RGBA(hex: "D4A017")]),
            (.starfield, [RGBA(hex: "0B0C10"), RGBA(hex: "3A1F6B")]),
            (.watercolor, [RGBA(hex: "F2ECDF"), RGBA(hex: "C8553D"), RGBA(hex: "1B2A4A")]),
            (.radial, [RGBA(hex: "F2A541"), RGBA(hex: "7A2E12"), RGBA(hex: "1A0C05")]),
            (.bokeh, [RGBA(hex: "121417"), RGBA(hex: "D81E5B"), RGBA(hex: "48CAE4")])
        ]
        var manifest: [[String: String]] = []
        for (i, p) in picks.enumerated() {
            let g = grounds[i % grounds.count]
            var doc = CoverDocument()
            doc.canvas = CanvasSpec(width: 1200, height: 675)
            doc.palette = g.1 + [RGBA(hex: "F2ECDF"), RGBA(hex: "E4572E")]
            let palette = PaletteRoles(doc.palette)
            var bg = Layer.fill(g.0, colors: g.1, seed: 40 + i, intensity: 0.5)
            bg.name = "Ground"
            var title = Layer.text("The Salt\nOrchard", role: .title, frame: NRect(0.08, 0.14, 0.84, 0.66),
                                   font: p.fonts.first(where: FontCatalog.isAvailable) ?? "Didot", color: palette.light)
            if var t = title.textContent {
                p.apply(to: &t, palette: palette)
                if t.fontName.lowercased().contains("script") || t.fontName.contains("Vibes") || t.fontName.contains("Allura") {
                    t.letterCase = .asTyped
                } else {
                    t.letterCase = .upper
                }
                title.textContent = t
            }
            doc.layers = [bg, title]
            let img = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 1200, height: 675), quality: .full), p.id)
            let file = String(format: "%02d-%@.png", i, p.id.replacingOccurrences(of: ".", with: "-"))
            XCTAssertTrue(Exporter.write(img, to: out.appendingPathComponent(file), format: .png, quality: 1))
            manifest.append(["file": file, "name": p.name, "family": p.category, "font": FontCatalog.displayName(title.textContent?.fontName ?? "")])
        }
        // Diagnostics: each raw material on its own, so texture problems can be told apart from relief and finish.
        var n = picks.count
        for surf in SurfaceTexture.allCases where surf != .none {
            let e = CGRect(x: 0, y: 0, width: 600, height: 338)
            let img = SurfaceGen.make(surf, extent: e, size: 160, seed: 7, a: RGBA(hex: "E4572E"), b: RGBA(hex: "1B998B"))
            if let cg = Gfx.render(img, extent: e) {
                let file = String(format: "%02d-material-%@.png", n, surf.rawValue)
                _ = Exporter.write(cg, to: out.appendingPathComponent(file), format: .png, quality: 1)
                manifest.append(["file": file, "name": "Raw material: " + surf.label, "family": "Diagnostic", "font": ""])
                n += 1
            }
        }
        // Ink & line art effects applied to a photo-like scene.
        let scene = try XCTUnwrap(Gfx.context(1200, 675))
        Gfx.linearGradient(scene, CGRect(x: 0, y: 0, width: 1200, height: 675), [RGBA(hex: "13404A"), RGBA(hex: "C9884A"), RGBA(hex: "F1B15A")], angle: 90)
        scene.setFillColor(RGBA(hex: "1E2E22").cgColor)
        for k in 0..<7 { scene.fillEllipse(in: CGRect(x: CGFloat(k) * 190 - 40, y: 120, width: 200, height: 170)) }
        scene.setFillColor(RGBA(hex: "121417").cgColor)
        scene.fillEllipse(in: CGRect(x: 540, y: 330, width: 120, height: 150))
        scene.fill(CGRect(x: 500, y: 0, width: 200, height: 340))
        let base = CIImage(cgImage: try XCTUnwrap(scene.makeImage()))
        for id in ["ink.ink-drawing.black.1", "ink.engraving.sepia.1", "ink.pencil-sketch.black.1", "ink.crosshatch.navy.1",
                   "ink.linocut.black.2", "ink.ink-wash.black.1", "ink.graphic-novel.black.1", "ink.screen-print.palette.1",
                   "ink.stipple.black.1", "ink.blueprint.black.1", "ink.cyanotype.black.1", "ink.vector-poster.black.1"] {
            guard let p = EffectLibrary.shared.preset(id) else { continue }
            let ctx = EffectContext(scale: 0.675, seed: 5, palette: [RGBA(hex: "1B2A4A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")])
            if let cg = Gfx.render(p.apply(base, ctx).cropped(to: base.extent), extent: base.extent) {
                let file = String(format: "%02d-%@.png", n, id.replacingOccurrences(of: ".", with: "-"))
                _ = Exporter.write(cg, to: out.appendingPathComponent(file), format: .png, quality: 1)
                manifest.append(["file": file, "name": p.name, "family": "Ink & Line Art (photo effect)", "font": ""])
                n += 1
            }
        }
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: out.appendingPathComponent("manifest.json"))
    }
}

final class MaskingTests: XCTestCase {
    private func photoData() throws -> Data {
        let ctx = try XCTUnwrap(Gfx.context(300, 450))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: 300, height: 450), [RGBA(hex: "13404A"), RGBA(hex: "F2A541")], angle: 90)
        ctx.setFillColor(RGBA(hex: "121417").cgColor)
        ctx.fillEllipse(in: CGRect(x: 90, y: 90, width: 120, height: 240))
        return try XCTUnwrap(AssetStore.encode(try XCTUnwrap(ctx.makeImage())))
    }

    private func alphaAt(_ img: CGImage, _ x: Double, _ y: Double) -> UInt8 {
        let p = PixelSampler.pixels(img, maxSide: 4000)
        let px = min(p.w - 1, Int(x * Double(p.w))), py = min(p.h - 1, Int(y * Double(p.h)))
        return p.data[(py * p.w + px) * 4 + 3]
    }

    func testGradientMaskFadesTheLayer() throws {
        let ctx = try XCTUnwrap(Gfx.context(100, 200))
        ctx.setFillColor(RGBA.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        var m = LayerMask()
        m.gradient = .linear
        m.angle = 90
        m.start = 0.3
        m.end = 0.7
        let out = try XCTUnwrap(Masking.applyLocal(m, to: try XCTUnwrap(ctx.makeImage())))
        XCTAssertGreaterThan(alphaAt(out, 0.5, 0.1), 240)
        XCTAssertLessThan(alphaAt(out, 0.5, 0.95), 15)
    }

    func testBlendIfKeepsDarks() throws {
        let ctx = try XCTUnwrap(Gfx.context(100, 100))
        ctx.setFillColor(RGBA.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
        ctx.setFillColor(RGBA.white.cgColor)
        ctx.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        var m = LayerMask()
        m.keepDarks = 0.5
        let out = try XCTUnwrap(Masking.applyLocal(m, to: try XCTUnwrap(ctx.makeImage())))
        XCTAssertGreaterThan(alphaAt(out, 0.25, 0.5), 240)
        XCTAssertLessThan(alphaAt(out, 0.75, 0.5), 15)
    }

    func testClipToBelowPutsAPhotoInsideTheTitle() throws {
        var doc = CoverDocument()
        doc.canvas = CanvasSpec(width: 400, height: 640)
        doc.background = .white
        let id = doc.addAsset(try photoData())
        var title = Layer.text("SALT", role: .title, frame: NRect(0.1, 0.1, 0.8, 0.3), font: "Anton-Regular", color: .nearBlack)
        title.name = "Title"
        var photo = Layer.image(id, frame: .full)
        photo.clipToBelow = true
        doc.layers = [title, photo]
        let img = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 400, height: 640)))
        // Far below the title the photo is clipped away, so the white backdrop shows.
        let p = PixelSampler.pixels(img, maxSide: 4000)
        let i = (Int(0.85 * Double(p.h)) * p.w + p.w / 2) * 4
        XCTAssertGreaterThan(p.data[i], 240)
    }

    func testDoubleExposureAndBlendedPairCovers() throws {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Salt Orchard", author: "Ines Valcourt", genre: .literary)
        _ = base.addAsset(try photoData())
        _ = base.addAsset(try photoData())
        for a in [Archetype.doubleExposure, .blendedPair] {
            let docs = CoverComposer.variations(base: base, count: 2, seed: 3, only: a)
            for d in docs {
                XCTAssertNotNil(CoverRenderer.shared.render(d, size: CGSize(width: 200, height: 320)), a.rawValue)
                if a == .doubleExposure { XCTAssertTrue(d.layers.contains { $0.mask.subjectOf != nil }) }
            }
        }
    }

    func testInkEffectsRender() throws {
        let ctx = try XCTUnwrap(Gfx.context(96, 128))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: 96, height: 128), [RGBA(hex: "1B2A4A"), RGBA(hex: "F2A541")], angle: 45)
        ctx.setFillColor(RGBA.black.cgColor)
        ctx.fillEllipse(in: CGRect(x: 30, y: 30, width: 36, height: 60))
        let base = CIImage(cgImage: try XCTUnwrap(ctx.makeImage()))
        let inks = EffectLibrary.shared.search("", family: .ink)
        XCTAssertGreaterThanOrEqual(inks.count, 150)
        for p in inks where p.id.hasSuffix(".1") {
            let out = p.apply(base, EffectContext(scale: 0.12, seed: 2, palette: [RGBA(hex: "1B2A4A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")]))
            XCTAssertNotNil(Gfx.render(out.cropped(to: base.extent), extent: base.extent), p.id)
        }
    }

    func testMaskSurvivesSaveAndOpen() throws {
        var l = Layer.image(UUID())
        l.mask.gradient = .radial
        l.mask.subjectOf = UUID()
        l.clipToBelow = true
        let back = try JSONDecoder().decode(Layer.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back, l)
    }
}
