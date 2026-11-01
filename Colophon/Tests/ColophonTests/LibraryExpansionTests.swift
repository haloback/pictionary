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
            let t = try XCTUnwrap(lib.search("", genre: g, photoOnly: false).filter { !$0.isSignature }.dropFirst(5).first, g.rawValue)
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

    private func strokeLine(_ tool: PaintTool, _ c: RGBA, x0: Double, x1: Double, y: Double, size: Double = 0.2, strength: Double = 0.8, wet: Double = 0.2) -> PaintStroke {
        PaintStroke(tool: tool, color: c, size: size, strength: strength, wetness: wet,
                    points: stride(from: x0, through: x1, by: 0.02).map { NPoint(x: $0, y: y) })
    }

    func testPaintMixesAndSmudges() throws {
        // Yellow, then a translucent blue glaze over it: the overlap must read green, like paint.
        var p = PaintContent()
        p.strokes = [strokeLine(.paint, RGBA(hex: "F7D917"), x0: 0.1, x1: 0.9, y: 0.5, strength: 1),
                     strokeLine(.paint, RGBA(hex: "2A3B9E"), x0: 0.1, x1: 0.9, y: 0.5, strength: 0.5)]
        var doc = CoverDocument()
        doc.canvas = CanvasSpec(width: 400, height: 400)
        let img = try XCTUnwrap(PaintEngine.shared.render(p, size: CGSize(width: 400, height: 400), layerID: UUID(), doc: doc))
        let px = PixelSampler.pixels(img, maxSide: 400)
        let i = (px.h / 2 * px.w + px.w / 2) * 4
        let r = Int(px.data[i]), g = Int(px.data[i + 1]), b = Int(px.data[i + 2])
        XCTAssertGreaterThan(g, r, "blue over yellow should be green, got \(r),\(g),\(b)")
        XCTAssertGreaterThan(g, b, "blue over yellow should be green, got \(r),\(g),\(b)")
        // Nothing painted at the corner.
        XCTAssertLessThan(px.data[3], 10)
        // Smudging drags color sideways into empty space.
        var q = PaintContent()
        q.strokes = [strokeLine(.paint, RGBA(hex: "D7263D"), x0: 0.1, x1: 0.3, y: 0.5),
                     strokeLine(.smudge, .white, x0: 0.2, x1: 0.8, y: 0.5, size: 0.15, strength: 0.9)]
        let img2 = try XCTUnwrap(PaintEngine.shared.render(q, size: CGSize(width: 400, height: 400), layerID: UUID(), doc: doc))
        let p2 = PixelSampler.pixels(img2, maxSide: 400)
        let j = (p2.h / 2 * p2.w + Int(0.55 * Double(p2.w))) * 4
        XCTAssertGreaterThan(p2.data[j + 3], 20, "smudge should carry paint into the empty area")
    }

    func testIncrementalPaintMatchesFullReplay() throws {
        var doc = CoverDocument()
        doc.canvas = CanvasSpec(width: 300, height: 300)
        var p = PaintContent()
        p.strokes = [strokeLine(.paint, RGBA(hex: "0B6E5A"), x0: 0.2, x1: 0.8, y: 0.3)]
        let id = UUID()
        _ = PaintEngine.shared.render(p, size: CGSize(width: 300, height: 300), layerID: id, doc: doc)
        p.strokes.append(strokeLine(.paint, RGBA(hex: "D8457A"), x0: 0.2, x1: 0.8, y: 0.6))
        p.strokes.append(strokeLine(.blend, .white, x0: 0.2, x1: 0.8, y: 0.45, size: 0.3))
        let a = try XCTUnwrap(PaintEngine.shared.render(p, size: CGSize(width: 300, height: 300), layerID: id, doc: doc))
        let b = try XCTUnwrap(PaintEngine.shared.render(p, size: CGSize(width: 300, height: 300), layerID: UUID(), doc: doc))
        let pa = PixelSampler.pixels(a, maxSide: 300), pb = PixelSampler.pixels(b, maxSide: 300)
        var diff = 0
        for k in 0..<min(pa.data.count, pb.data.count) { diff = max(diff, abs(Int(pa.data[k]) - Int(pb.data[k]))) }
        XCTAssertLessThanOrEqual(diff, 2)
    }

    func testWatercolorSimulationShowsPaperAndMixes() throws {
        let img = try XCTUnwrap(Watercolor.simulate(size: CGSize(width: 320, height: 480), pigments: [RGBA(hex: "2A3B9E"), RGBA(hex: "F7D917")],
                                                    paper: RGBA(hex: "FBF7EE"), seed: 5))
        let p = PixelSampler.pixels(img, maxSide: 320)
        var light = 0, painted = 0
        for k in stride(from: 0, to: p.w * p.h * 4, by: 4) {
            let l = (Int(p.data[k]) + Int(p.data[k + 1]) + Int(p.data[k + 2])) / 3
            if l > 235 { light += 1 } else if l < 200 { painted += 1 }
        }
        XCTAssertGreaterThan(light, p.w * p.h / 50, "some bare paper should show")
        XCTAssertGreaterThan(painted, p.w * p.h / 20, "there should be paint")
    }

    func testTemplatesByGenreAndTag() {
        let lib = TemplateLibrary.shared
        XCTAssertGreaterThanOrEqual(lib.templates.count, 4000)
        for tag in TemplateLibrary.tagChips {
            XCTAssertFalse(lib.search("", genre: nil, tags: [tag.lowercased()]).isEmpty, tag)
        }
        XCTAssertFalse(lib.search("", genre: .romance, tags: ["elegant", "light"]).isEmpty)
    }

    func testSmartRandomizeHonorsLocks() throws {
        var base = book()
        base = TemplateLibrary.shared.apply(TemplateLibrary.shared.search("", genre: .fantasy, photoOnly: false).filter { !$0.isSignature }[3], to: base)
        // Lock the title layer and the colors.
        let ti = try XCTUnwrap(base.layers.firstIndex { $0.textContent?.role == .title })
        base.layers[ti].isLocked = true
        base.layers[ti].textContent?.text = "MY OWN TITLE"
        var opts = SmartRandomizer.Options()
        opts.locks = [.colors]
        var recent: [Int] = []
        var signatures = Set<Int>()
        for k in 0..<10 {
            let out = SmartRandomizer.randomize(base, options: opts, recent: recent, seed: 100 + k)
            let r = try XCTUnwrap(out.recipe)
            XCTAssertEqual(r.palette, base.recipe?.palette, "colors were locked")
            XCTAssertEqual(out.textLayer(role: .title)?.textContent?.text, "MY OWN TITLE", "locked title layer kept")
            XCTAssertTrue(out.textLayer(role: .title)?.isLocked ?? false)
            XCTAssertNotNil(out.textLayer(role: .author))
            recent.append(r.signature)
            signatures.insert(r.signature)
        }
        XCTAssertGreaterThanOrEqual(signatures.count, 9, "randomize should not repeat itself")
        // Everything locked except the layout: only the archetype changes.
        opts.locks = Set(RandomAspect.allCases).subtracting([.layout])
        let out = SmartRandomizer.randomize(base, options: opts, recent: [], seed: 7)
        XCTAssertNotEqual(out.recipe?.archetype, base.recipe?.archetype)
        XCTAssertEqual(out.recipe?.pairing, base.recipe?.pairing)
        XCTAssertEqual(out.recipe?.styleID, base.recipe?.styleID)
        XCTAssertNotNil(CoverRenderer.shared.render(out, size: CGSize(width: 200, height: 320)))
    }

    func testRandomizeInfersRecipeForHandMadeCovers() {
        var d = CoverDocument()
        d.book = BookInfo(title: "Night Ferry", author: "A. Reader", genre: .thriller)
        d.layers = [.fill(.smoke, colors: [.ink, .paper]), .text("NIGHT FERRY", role: .title, frame: NRect(0.1, 0.1, 0.8, 0.3), font: "Anton-Regular", color: .nearWhite)]
        let out = SmartRandomizer.randomize(d, options: SmartRandomizer.Options(), recent: [], seed: 3)
        XCTAssertNotNil(out.recipe)
        XCTAssertNotNil(out.textLayer(role: .title))
    }

    func testSaveApplyAndDeleteUserTemplates() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("colophon-templates-\(UUID().uuidString)")
        let store = UserTemplateStore(directory: dir)
        var original = TemplateLibrary.shared.apply(TemplateLibrary.shared.search("", genre: .romance, photoOnly: false).filter { !$0.isSignature }[2], to: book())
        original.book.title = "The Salt Orchard"
        let t = try store.save(original, name: "Rose Design", includePictures: false)
        XCTAssertEqual(store.templates.count, 1)
        XCTAssertNotNil(store.thumbnail(t.id))
        // Survives a relaunch.
        let again = UserTemplateStore(directory: dir)
        XCTAssertEqual(again.templates.first?.name, "Rose Design")
        // On another book, that book's title replaces the template's.
        var other = CoverDocument()
        other.book = BookInfo(title: "Winter Lanterns", subtitle: "", author: "M. Okafor", genre: .romance)
        let applied = UserTemplateStore.apply(t, to: other)
        XCTAssertEqual(applied.book.title, "Winter Lanterns")
        let titleText = applied.textLayer(role: .title)?.textContent?.text.replacingOccurrences(of: "\n", with: " ") ?? ""
        XCTAssertTrue(titleText.lowercased().contains("winter"), titleText)
        XCTAssertNil(applied.textLayer(role: .subtitle), "the other book has no subtitle")
        XCTAssertNotNil(CoverRenderer.shared.render(applied, size: CGSize(width: 200, height: 320)))
        again.delete(t.id)
        XCTAssertTrue(again.templates.isEmpty)
        XCTAssertTrue(UserTemplateStore(directory: dir).templates.isEmpty)
    }
}
