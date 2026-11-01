import CoreGraphics
import CoreText
import XCTest
@testable import Colophon

final class LibraryExpansionTests: XCTestCase {
    private func book() -> CoverDocument {
        var d = CoverDocument()
        d.book = BookInfo(title: "The Salt Orchard", subtitle: "A Novel of the Drowned Coast", author: "Ines Valcourt",
                          series: "The Tidewater Books", tagline: "Some debts are paid in water.", genre: .fantasy)
        return d
    }

    func testThousandsOfTemplates() throws {
        let lib = TemplateLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.templates.count, 2000)
        XCTAssertEqual(Set(lib.templates.map(\.id)).count, lib.templates.count)
        for g in Genre.allCases { XCTAssertGreaterThanOrEqual(lib.search("", genre: g).count, 150, g.rawValue) }
        XCTAssertFalse(lib.search("ember medallion", genre: nil).isEmpty)
        // One template per genre, rendered with real book details.
        let base = book()
        for g in Genre.allCases {
            let t = try XCTUnwrap(lib.search("", genre: g, photoOnly: false).dropFirst(5).first, g.rawValue)
            let doc = lib.apply(t, to: base)
            XCTAssertEqual(doc.templateID, t.id)
            XCTAssertNotNil(doc.textLayer(role: .title), t.id)
            XCTAssertNotNil(doc.textLayer(role: .subtitle), "subtitle missing in \(t.id)")
            XCTAssertNotNil(doc.textLayer(role: .tagline), "tagline missing in \(t.id)")
            XCTAssertNotNil(CoverRenderer.shared.render(doc, size: CGSize(width: 200, height: 320)), t.id)
        }
    }

    func testSupportingLinesFollowTheBrief() {
        var d = CoverDocument()
        d.book = BookInfo(title: "Night Ferry", author: "A. Reader", genre: .thriller)
        d.layers = [.text("NIGHT FERRY", role: .title, frame: NRect(0.1, 0.1, 0.8, 0.3), font: "Anton-Regular", color: .nearWhite),
                    .text("A. Reader", role: .author, frame: NRect(0.1, 0.88, 0.8, 0.05), font: "Oswald-Bold", color: .nearWhite)]
        var b = d.book
        b.tagline = "Nobody gets off at midnight."
        b.subtitle = "A Thriller"
        let old = d.book
        BookSync.apply(b, old: old, to: &d)
        XCTAssertEqual(d.textLayer(role: .tagline)?.textContent?.text, "Nobody gets off at midnight.")
        XCTAssertNotNil(d.textLayer(role: .subtitle))
        // Supporting lines don't land on the title.
        let title = d.textLayer(role: .title)!.frame
        XCTAssertLessThan(d.textLayer(role: .subtitle)!.frame.intersectionArea(title), 0.01)
        var c = d.book
        c.tagline = ""
        BookSync.apply(c, old: d.book, to: &d)
        XCTAssertNil(d.textLayer(role: .tagline))
        // Every idea the composer makes carries them too.
        var base = CoverDocument()
        base.book = BookInfo(title: "Night Ferry", subtitle: "A Thriller", author: "A. Reader", tagline: "Nobody gets off at midnight.", genre: .thriller)
        for doc in CoverComposer.variations(base: base, count: 8, seed: 3) {
            XCTAssertNotNil(doc.textLayer(role: .tagline), doc.archetypeName)
            XCTAssertNotNil(doc.textLayer(role: .subtitle), doc.archetypeName)
        }
    }

    func testFlourishesAndOutlinesRender() {
        for f in TextFlourish.allCases {
            var t = TextContent(text: "A Novel", role: .subtitle, fontName: "Cinzel-Bold", color: RGBA(hex: "F2ECDF"))
            t.flourish = f
            XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 700, height: 90), canvasHeight: 2560), f.rawValue)
        }
        let outlineStyles = StyleLibrary.shared.all.filter { $0.id.hasPrefix("gen.outline") }
        XCTAssertGreaterThanOrEqual(outlineStyles.count, 100)
        var t = TextContent(text: "OUTLINE", role: .title, fontName: "Anton-Regular", color: RGBA(hex: "E4572E"))
        for s in [0.02, 0.06] {
            t.style = TextStyle(); t.style.hollow = s
            XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 600, height: 200), canvasHeight: 2560))
        }
        t.style = TextStyle(); t.style.outline = 0.02; t.style.outline2 = 0.02; t.style.outline3 = 0.02; t.style.outlineDash = 0.05
        t.style.innerOutline = 0.01
        XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 600, height: 200), canvasHeight: 2560))
    }

    func testHollowLettersAreSeeThrough() throws {
        var t = TextContent(text: "O", role: .title, fontName: "Anton-Regular", color: .white)
        t.style.hollow = 0.02
        let (img, _) = try XCTUnwrap(TextRenderer.render(t, box: CGSize(width: 300, height: 300), canvasHeight: 2560))
        let p = PixelSampler.pixels(img, maxSide: 4000)
        var opaque = 0
        for i in stride(from: 3, to: p.w * p.h * 4, by: 4) where p.data[i] > 200 { opaque += 1 }
        // A filled O covers far more of its box than its outline does.
        var filled = TextContent(text: "O", role: .title, fontName: "Anton-Regular", color: .white)
        filled.style = TextStyle()
        let (img2, _) = try XCTUnwrap(TextRenderer.render(filled, box: CGSize(width: 300, height: 300), canvasHeight: 2560))
        let q = PixelSampler.pixels(img2, maxSide: 4000)
        var opaque2 = 0
        for i in stride(from: 3, to: q.w * q.h * 4, by: 4) where q.data[i] > 200 { opaque2 += 1 }
        XCTAssertLessThan(Double(opaque), Double(opaque2) * 0.8)
    }

    func testThousandsOfDecorItems() throws {
        let lib = DecorLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.items.count, 3000)
        XCTAssertEqual(Set(lib.items.map(\.id)).count, lib.items.count)
        XCTAssertGreaterThanOrEqual(lib.search("", kind: .border).count, 2000)
        let palette = PaletteRoles([RGBA(hex: "1B2A4A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")])
        for kind in DecorLibrary.Kind.allCases {
            let items = lib.search("", kind: kind)
            XCTAssertFalse(items.isEmpty, kind.rawValue)
            for item in items.enumerated().filter({ $0.offset % max(1, items.count / 12) == 0 }).map(\.element) {
                let (a, b) = lib.colors(for: item, palette: palette)
                let c = DecorContent(itemID: item.id, color: a, color2: b)
                XCTAssertNotNil(lib.render(c, size: CGSize(width: 320, height: 512), canvasHeight: 2560), item.id)
            }
        }
        var d = CoverDocument()
        let first = try XCTUnwrap(lib.search("", kind: .badge).first)
        d.layers = [.decor(first.id, color: .white, frame: first.defaultFrame)]
        let back = try JSONDecoder().decode(CoverDocument.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(back.layers, d.layers)
    }

    func testGoogleFontsCatalog() throws {
        let lib = FontLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.families.count, 1800)
        XCTAssertFalse(lib.search("lobster", category: nil).isEmpty)
        XCTAssertFalse(lib.search("", category: .handwriting).isEmpty)
        let fam = try XCTUnwrap(lib.families.first { $0.styles.contains { $0.file.contains("[") } })
        XCTAssertNotNil(FontLibrary.remoteURL(commit: "abc", path: fam.path, file: fam.styles[0].file))
    }

    func testPaintMixesLikePigment() {
        let blue = RGBA(hex: "2A3B9E"), yellow = RGBA(hex: "F7D917")
        let green = PigmentMixer.mix(blue, yellow, 0.5)
        XCTAssertGreaterThan(green.g, green.r, "blue + yellow should be green")
        XCTAssertGreaterThan(green.g, green.b, "blue + yellow should be green")
        // Light mixing (RGB average) gives a gray instead.
        let orange = PigmentMixer.mix(RGBA(hex: "D7263D"), RGBA(hex: "F7D917"), 0.5)
        XCTAssertGreaterThan(orange.r, orange.g)
        XCTAssertGreaterThan(orange.g, orange.b)
        let same = PigmentMixer.mix(RGBA(hex: "E4572E"), RGBA(hex: "E4572E"), 0.5)
        XCTAssertEqual(same.r, RGBA(hex: "E4572E").r, accuracy: 0.01)
        XCTAssertEqual(same.g, RGBA(hex: "E4572E").g, accuracy: 0.01)
        let tint = PigmentMixer.mix(blue, .white, 0.5)
        XCTAssertGreaterThan(tint.luminance, blue.luminance)
        XCTAssertEqual(PigmentMixer.ramp(blue, yellow, steps: 9).count, 9)
    }

    func testNewStyleFamiliesRender() throws {
        let lib = StyleLibrary.shared
        for prefix in ["gen.emboss", "gen.watercolor", "gen.paintmix", "gen.overprint"] {
            let fam = lib.all.filter { $0.id.hasPrefix(prefix) }
            XCTAssertGreaterThanOrEqual(fam.count, 100, prefix)
        }
        XCTAssertGreaterThanOrEqual(lib.all.count, 2900)
        // Emboss reads the ground, so render it on a real cover with a photo-like fill below.
        for id in [lib.all.first { $0.id.hasPrefix("gen.emboss") }!.id, lib.all.first { $0.id.hasPrefix("gen.watercolor") }!.id,
                   lib.all.first { $0.id.hasPrefix("gen.overprint") }!.id, lib.all.first { $0.id.hasPrefix("gen.paintmix") }!.id] {
            let p = try XCTUnwrap(lib.preset(id))
            var doc = CoverDocument()
            doc.canvas = CanvasSpec(width: 600, height: 400)
            var title = Layer.text("SALT", role: .title, frame: NRect(0.1, 0.2, 0.8, 0.6), font: "Anton-Regular", color: .nearWhite)
            if var t = title.textContent { p.apply(to: &t, palette: PaletteRoles([.ink, .paper])); title.textContent = t }
            doc.layers = [Layer.fill(.wetInWet, colors: [RGBA(hex: "2A3B9E"), RGBA(hex: "F7D917"), .paper]), title]
            XCTAssertNotNil(CoverRenderer.shared.render(doc, size: CGSize(width: 600, height: 400), quality: .full), id)
        }
    }
}
