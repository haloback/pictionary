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
