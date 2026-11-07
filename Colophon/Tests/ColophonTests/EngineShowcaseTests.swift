import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import Colophon

/// Contact sheets for the engine upgrades (CI only): the critic's before/after, the typesetter, grades and blends.
extension SampleRenderTests {
    private func loadPhoto(_ names: [String]) -> Data? {
        guard let pdir = ProcessInfo.processInfo.environment["COLOPHON_PHOTOS"] else { return nil }
        for n in names {
            let url = URL(fileURLWithPath: pdir).appendingPathComponent(n)
            if let d = try? Data(contentsOf: url), d.count > 10_000 { return d }
        }
        return nil
    }

    private func sheet(_ imgs: [CGImage], cols: Int, cell: CGSize, labels: [String], to url: URL) {
        let rows = (imgs.count + cols - 1) / cols
        let pad: CGFloat = 14, labelH: CGFloat = 22
        let W = Int(CGFloat(cols) * (cell.width + pad) + pad), H = Int(CGFloat(rows) * (cell.height + pad + labelH) + pad)
        guard rows > 0, let ctx = Gfx.context(W, H) else { return }
        ctx.setFillColor(RGBA(hex: "1C1C1E").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        for (i, img) in imgs.enumerated() {
            let x = pad + CGFloat(i % cols) * (cell.width + pad)
            let yTop = pad + CGFloat(i / cols) * (cell.height + pad + labelH)
            let y = CGFloat(H) - yTop - cell.height
            ctx.draw(img, in: CGRect(x: x, y: y, width: cell.width, height: cell.height))
            if i < labels.count {
                var t = TextContent(text: labels[i])
                t.fontName = "Montserrat-Black"
                t.color = RGBA(hex: "ECECEE")
                t.autoFit = false
                t.fontSize = 0.6
                t.alignment = .left
                if let li = TextRenderer.render(t, box: CGSize(width: cell.width, height: 16), canvasHeight: 20) {
                    ctx.draw(li.0, in: CGRect(x: x, y: y - labelH + 2, width: cell.width, height: 16))
                }
            }
        }
        if let cg = ctx.makeImage() { _ = Exporter.write(cg, to: url, format: .png, quality: 1) }
    }

    func testRenderEngineShowcase() async throws {
        guard let dir = ProcessInfo.processInfo.environment["COLOPHON_SAMPLES"] else { throw XCTSkip("COLOPHON_SAMPLES not set") }
        let out = URL(fileURLWithPath: dir).appendingPathComponent("engine", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let cell = CGSize(width: 300, height: 480)
        func shot(_ d: CoverDocument) -> CGImage? { CoverRenderer.shared.render(d, size: cell, quality: .full) }
        let portrait = loadPhoto(["sig/portrait.jpg", "b-monalisa.jpg"])
        let landscape = loadPhoto(["sig/landscape.jpg", "c-earth.jpg"])
        var photos: [String: Data] = [:]
        if let portrait { photos["portrait"] = portrait }
        if let landscape { photos["landscape"] = landscape; photos["space"] = landscape }
        var manifest: [[String: Any]] = []

        // 1. The critic: deliberately flawed covers, then what it makes of them.
        var imgs: [CGImage] = []
        var labels: [String] = []
        func pair(_ name: String, _ make: () -> CoverDocument) {
            var d = make()
            let before = Critic.review(d)
            if let i = shot(d) { imgs.append(i); labels.append("\(name): before, score \(Int(before.score))") }
            let after = Critic.repair(&d)
            if let i = shot(d) { imgs.append(i); labels.append("after, score \(Int(after.score)) \(after.grade)") }
        }
        pair("Pale type on pale ground") {
            var d = CoverDocument()
            d.book = BookInfo(title: "The Salt Orchard", author: "Ines Valcourt", tagline: "Some debts are paid in water.", genre: .literary)
            d.palette = [RGBA(hex: "121212"), RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
            d.background = RGBA(hex: "DCD6C8")
            d.layers = [Layer.fill(.solid, colors: [RGBA(hex: "DCD6C8")], frame: .full),
                        Layer.text("The Salt\nOrchard", role: .title, frame: NRect(0.08, 0.12, 0.84, 0.4), font: "PlayfairDisplay-Black", color: RGBA(hex: "EDE8DC")),
                        Layer.text("Ines Valcourt", role: .author, frame: NRect(0.15, 0.85, 0.7, 0.04), font: "Montserrat-Black", color: RGBA(hex: "EDE8DC"))]
            return d
        }
        pair("Type over a busy photo and a face") {
            var d = CoverDocument()
            d.book = BookInfo(title: "No One Leaves", author: "Mara Kellen", tagline: "Some doors only open one way", genre: .thriller)
            d.palette = [RGBA(hex: "000000"), RGBA(hex: "E2231A"), RGBA(hex: "F2F2F2")]
            if let portrait { _ = d.addAsset(portrait) }
            let photos = d.assetOrder
            if let p = photos.first { d.layers.append(Layer.image(p, frame: .full)) }
            else { d.layers.append(Layer.fill(.halftone, colors: [RGBA(hex: "5A5A5A"), RGBA(hex: "B0B0B0"), RGBA(hex: "202020")], frame: .full, seed: 9, intensity: 0.9)) }
            d.layers.append(Layer.text("NO ONE\nLEAVES", role: .title, frame: NRect(0.08, 0.2, 0.84, 0.3), font: "Anton-Regular", color: RGBA(hex: "8A8A8A")))
            d.layers.append(Layer.text("Mara Kellen", role: .author, frame: NRect(0.1, 0.4, 0.8, 0.05), font: "BebasNeue-Regular", color: RGBA(hex: "9A9A9A")))
            d.layers.append(Layer.text("Some doors only open one way", role: .tagline, frame: NRect(0.1, 0.44, 0.8, 0.025), font: "Montserrat-Black", color: RGBA(hex: "A0A0A0")))
            return d
        }
        pair("Lines colliding, tagline off the trim") {
            var d = CoverDocument()
            d.book = BookInfo(title: "Where the Water Turns", subtitle: "A Novel", author: "Tobias Wren", tagline: "Every river remembers.", genre: .literary)
            d.palette = [RGBA(hex: "1B2A4A"), RGBA(hex: "C8553D"), RGBA(hex: "F2ECDF")]
            d.background = RGBA(hex: "F2ECDF")
            d.layers = [Layer.fill(.solid, colors: [RGBA(hex: "F2ECDF")], frame: .full),
                        Layer.text("Where the\nWater Turns", role: .title, frame: NRect(0.08, 0.3, 0.84, 0.3), font: "LibreCaslonDisplay-Regular", color: RGBA(hex: "1B2A4A")),
                        Layer.text("A Novel", role: .subtitle, frame: NRect(0.3, 0.55, 0.4, 0.03), font: "Montserrat-Black", color: RGBA(hex: "C8553D")),
                        Layer.text("Tobias Wren", role: .author, frame: NRect(0.15, 0.57, 0.7, 0.045), font: "Montserrat-Black", color: RGBA(hex: "1B2A4A")),
                        Layer.text("Every river remembers.", role: .tagline, frame: NRect(0.1, 0.99, 0.8, 0.025), font: "Montserrat-Black", color: RGBA(hex: "1B2A4A"))]
            return d
        }
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("01-critic.png"))
        manifest.append(["file": "01-critic.png", "name": "The critic: measured legibility, collisions, trim and faces; then its repairs", "family": "Critic"])

        // 2. Smart randomize, now best-of-three by score.
        imgs = []; labels = []
        var base = CoverDocument()
        base.book = BookInfo(title: "The Long Quiet", subtitle: "A Novel", author: "Ada Merrow", tagline: "She counted the days. Then she stopped.", genre: .mystery)
        if let landscape { _ = base.addAsset(landscape) }
        for s in 1...6 {
            let d = SmartRandomizer.randomize(base, options: .init(), recent: [], seed: 300 + s)
            let r = Critic.review(d)
            if let i = shot(d) { imgs.append(i); labels.append("\(d.archetypeName): \(Int(r.score)) \(r.grade)") }
        }
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("02-randomize.png"))
        manifest.append(["file": "02-randomize.png", "name": "Smart randomize: three directions sketched per roll, the best-scoring kept", "family": "Critic"])

        // 3. Recommended for this book.
        imgs = []; labels = []
        var rec = CoverDocument()
        rec.book = BookInfo(title: "Grace Under Glass", subtitle: "A Novel", author: "Julien Achterberg", genre: .literary)
        if let portrait { _ = rec.addAsset(portrait) }
        for pick in TemplateRecommender.rank(for: rec, keep: 6) {
            let d = TemplateLibrary.shared.apply(pick.template, to: rec)
            if let i = shot(d) { imgs.append(i); labels.append("\(pick.template.name): \(Int(pick.score))") }
        }
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("03-recommended.png"))
        manifest.append(["file": "03-recommended.png", "name": "Recommended for your book: templates judged with the author's own title and photo", "family": "Critic"])

        // 4. Typesetting: count-based vs measured breaks, uniform vs block fit, small caps, hanging quotes.
        imgs = []; labels = []
        func typeCover(_ title: String, font: String, fit: TextFit, letterCase: LetterCase, breaksMeasured: Bool, label: String) {
            var d = CoverDocument()
            d.book = BookInfo(title: title, author: "Ines Valcourt", genre: .literary)
            d.palette = [RGBA(hex: "121212"), RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
            d.background = RGBA(hex: "F1EBDD")
            var t = TextContent(text: title, role: .title, fontName: font, color: RGBA(hex: "121212"))
            t.letterCase = letterCase
            t.fit = fit
            t.lineHeight = 0.9
            t.alignment = fit == .block ? .left : .center
            t.opticalTracking = true
            let box = NRect(0.08, 0.1, 0.84, 0.5)
            let px = box.pixels(in: CGSize(width: cell.width, height: cell.height))
            if fit == .block {
                t.text = title.split(separator: " ").joined(separator: "\n")
            } else if breaksMeasured {
                t.text = TextRenderer.bestBreaks(t, box: px.size)
            } else {
                t.text = TitleBreaker.auto(title, stacked: false)
            }
            var tl = Layer(name: "Title", content: .text(t), frame: box)
            tl.name = "Title"
            var au = TextContent(text: "Ines Valcourt", role: .author, fontName: "CormorantGaramond-SemiBold", color: RGBA(hex: "121212"))
            au.letterCase = letterCase == .smallCaps ? .smallCaps : .upper
            au.tracking = 0.18
            d.layers = [Layer.fill(.solid, colors: [RGBA(hex: "F1EBDD")], frame: .full), tl,
                        Layer(name: "Author", content: .text(au), frame: NRect(0.15, 0.86, 0.7, 0.045))]
            if let i = shot(d) { imgs.append(i); labels.append(label) }
        }
        typeCover("The Edge of Everything", font: "PlayfairDisplay-Black", fit: .uniform, letterCase: .asTyped, breaksMeasured: false, label: "Count-based breaks")
        typeCover("The Edge of Everything", font: "PlayfairDisplay-Black", fit: .uniform, letterCase: .asTyped, breaksMeasured: true, label: "Measured breaks, no connective at line end")
        typeCover("The Salt Orchard", font: "Anton-Regular", fit: .uniform, letterCase: .upper, breaksMeasured: true, label: "Uniform fit")
        typeCover("The Salt Orchard", font: "Anton-Regular", fit: .block, letterCase: .upper, breaksMeasured: true, label: "Block fit: every line fills the width")
        typeCover("“Quiet” Hours", font: "DMSerifDisplay-Regular", fit: .uniform, letterCase: .asTyped, breaksMeasured: true, label: "Hanging quotes, small-caps author")
        typeCover("Grace Under Glass", font: "LibreCaslonDisplay-Regular", fit: .uniform, letterCase: .smallCaps, breaksMeasured: true, label: "Small caps title and author")
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("04-typesetting.png"))
        manifest.append(["file": "04-typesetting.png", "name": "Typesetting: measured breaks, block fit, hanging punctuation, small caps, optical tracking", "family": "Typography"])

        // 5. Color grades on one photo.
        imgs = []; labels = []
        if let landscape {
            var gd = CoverDocument()
            gd.book = BookInfo(title: "Grades", author: "", genre: .literary)
            let id = gd.addAsset(landscape)
            let grades = Array(ColorGrade.all.prefix(12))
            for g in grades {
                var d = gd
                var l = Layer.image(id, frame: .full)
                l.adjust = g.adjust
                d.layers = [l]
                if let i = CoverRenderer.shared.render(d, size: CGSize(width: 240, height: 384), quality: .full) { imgs.append(i); labels.append(g.name) }
            }
            sheet(imgs, cols: 6, cell: CGSize(width: 240, height: 384), labels: labels, to: out.appendingPathComponent("05-grades.png"))
            manifest.append(["file": "05-grades.png", "name": "Color grades: lift, gamma, gain, split toning, vibrance, fade, grain and vignette as one-click looks", "family": "Image"])
        }

        // 6. Compositing: knockout, gradient map, inner shadow, feather, linear-light blend, harmony.
        imgs = []; labels = []
        func blendCover(_ label: String, _ make: (inout CoverDocument, UUID?) -> Void) {
            var d = CoverDocument()
            d.book = BookInfo(title: "Undertow", author: "Maren Solberg", genre: .thriller)
            d.palette = [RGBA(hex: "0B1D3A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")]
            d.background = RGBA(hex: "F2ECDF")
            var id: UUID?
            if let portrait { id = d.addAsset(portrait) }
            make(&d, id)
            if let i = shot(d) { imgs.append(i); labels.append(label) }
        }
        blendCover("Knockout: the title cuts through to the ground") { d, id in
            if let id { d.layers.append(Layer.image(id, frame: .full)) } else { d.layers.append(Layer.fill(.smoke, colors: [RGBA(hex: "0B1D3A"), RGBA(hex: "23308C"), RGBA(hex: "7B83EB")], frame: .full)) }
            var t = Layer.text("UNDER\nTOW", role: .title, frame: NRect(0.06, 0.3, 0.88, 0.4), font: "Anton-Regular", color: .white)
            t.knockout = true
            d.layers.append(t)
        }
        blendCover("Gradient map: duotone on any layer") { d, id in
            if let id { var l = Layer.image(id, frame: .full); l.gradientMap = [RGBA(hex: "0B1D3A"), RGBA(hex: "E4572E"), RGBA(hex: "F2ECDF")]; d.layers.append(l) }
            d.layers.append(Layer.text("UNDERTOW", role: .title, frame: NRect(0.06, 0.78, 0.88, 0.12), font: "Anton-Regular", color: RGBA(hex: "F2ECDF")))
        }
        blendCover("Inner shadow: pressed type") { d, _ in
            d.layers.append(Layer.fill(.solid, colors: [RGBA(hex: "E4572E")], frame: .full))
            var t = Layer.text("UNDER\nTOW", role: .title, frame: NRect(0.06, 0.3, 0.88, 0.4), font: "Anton-Regular", color: RGBA(hex: "D14A24"))
            t.innerShadow = ShadowStyle(color: RGBA(0, 0, 0, 0.7), radius: 0.012, dx: 0, dy: 0.006)
            d.layers.append(t)
        }
        blendCover("Feathered edge on a clipped photo") { d, id in
            d.layers.append(Layer.fill(.solid, colors: [RGBA(hex: "0B1D3A")], frame: .full))
            if let id { var l = Layer.image(id, frame: NRect(0.12, 0.1, 0.76, 0.55)); l.clipShape = .ellipse; l.feather = 0.5; d.layers.append(l) }
            d.layers.append(Layer.text("UNDERTOW", role: .title, frame: NRect(0.06, 0.74, 0.88, 0.12), font: "Anton-Regular", color: RGBA(hex: "F2ECDF")))
        }
        blendCover("Linear-light multiply wash") { d, id in
            if let id { d.layers.append(Layer.image(id, frame: .full)) }
            var w = Layer.fill(.linear, colors: [RGBA(hex: "E4572E"), RGBA(hex: "0B1D3A")], frame: .full, angle: 90)
            w.blend = .multiply
            w.linearBlend = true
            w.opacity = 0.85
            d.layers.append(w)
            d.layers.append(Layer.text("UNDERTOW", role: .title, frame: NRect(0.06, 0.78, 0.88, 0.12), font: "Anton-Regular", color: RGBA(hex: "F2ECDF")))
        }
        blendCover("Harmonized to the palette") { d, id in
            if let id {
                let l = Layer.image(id, frame: .full)
                d.layers.append(l)
                d.layers.append(Harmonizer.layer(for: l, palette: PaletteRoles(d.palette), strength: 0.8, mean: nil))
            }
            d.layers.append(Layer.text("UNDERTOW", role: .title, frame: NRect(0.06, 0.78, 0.88, 0.12), font: "Anton-Regular", color: RGBA(hex: "F2ECDF")))
        }
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("06-compositing.png"))
        manifest.append(["file": "06-compositing.png", "name": "Compositing: knockout, gradient map, inner shadow, feather, linear-light blend, palette harmony", "family": "Blending"])

        // 7. The taste model, when CI installed it: genre fit, mood and professionalism per cover, then a search by description.
        if ProcessInfo.processInfo.environment["COLOPHON_TASTE"] != nil && !TasteEngine.shared.isReady {
            try? await TasteEngine.shared.install()
        }
        if TasteEngine.shared.isReady {
            imgs = []; labels = []
            let ids = ["literary-the-grid", "thriller-brand-name", "horror-unblinking", "romance-venn", "cozy-awning", "sciencefiction-planet-limb"]
            for id in ids {
                guard let d = SignatureLibrary.design(id) else { continue }
                var base = SignatureLibrary.sampleDocument(d)
                if d.usesPhoto, let data = photos[d.sample.photo] ?? portrait { _ = base.addAsset(data) }
                let doc = SignatureLibrary.build(d, palette: 0, base: base)
                guard let t = TasteEngine.shared.taste(of: doc), let i = shot(doc) else { continue }
                let top = t.genreFit.prefix(2).map { "\($0.genre.label) \(Int($0.score * 100))%" }.joined(separator: ", ")
                imgs.append(i)
                labels.append("\(top) · pro \(Int(t.professionalism * 100)) · " + t.moodTags.prefix(3).joined(separator: ", "))
            }
            sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("07-taste.png"))
            manifest.append(["file": "07-taste.png", "name": "Taste model (CLIP, local): what genre each cover reads as, how professional it looks, its mood", "family": "Taste"])

            imgs = []; labels = []
            let query = "a quiet, foggy literary novel"
            for hit in TasteEngine.shared.search(query, in: SignatureLibrary.all, limit: 6) {
                let d = hit.design
                var base = SignatureLibrary.sampleDocument(d)
                if d.usesPhoto, let data = photos[d.sample.photo] ?? portrait { _ = base.addAsset(data) }
                if let i = shot(SignatureLibrary.build(d, palette: 0, base: base)) { imgs.append(i); labels.append("\(d.name) · \(String(format: "%.2f", hit.score))") }
            }
            sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("08-describe.png"))
            manifest.append(["file": "08-describe.png", "name": "Search by description: “\(query)” across the Signature designs", "family": "Taste"])
        }

        // 9. Type on a path and warped type.
        imgs = []; labels = []
        for path in TextPath.allCases where path != .none {
            var d = CoverDocument()
            d.book = BookInfo(title: "Undertow", author: "Maren Solberg", genre: .thriller)
            d.background = RGBA(hex: "0B1D3A")
            var t = TextContent(text: path == .circle ? "THE SALT ORCHARD • A NOVEL •" : "UNDERTOW", role: .title, fontName: "Anton-Regular", color: RGBA(hex: "F2ECDF"))
            t.path = path
            t.pathAmount = path == .circle ? 1 : 0.7
            t.letterCase = .upper
            d.layers = [Layer.fill(.solid, colors: [RGBA(hex: "0B1D3A")], frame: .full),
                        Layer(name: "Title", content: .text(t), frame: path == .circle ? NRect(0.1, 0.2, 0.8, 0.5) : NRect(0.06, 0.3, 0.88, 0.3))]
            if let i = shot(d) { imgs.append(i); labels.append(path.label) }
        }
        sheet(imgs, cols: 8, cell: CGSize(width: 225, height: 360), labels: labels, to: out.appendingPathComponent("09-type-paths.png"))
        manifest.append(["file": "09-type-paths.png", "name": "Type on a path and warped type: circle, wave, flag, bulge, pinch, rise, fall, perspective", "family": "Typography"])

        // 10. Subjects, cutouts and object removal on a real picture.
        if let landscape, let src = AssetStore.decode(landscape, maxPixel: 1200) {
            imgs = []; labels = []
            let cell2 = CGSize(width: 300, height: 300 * CGFloat(src.height) / CGFloat(src.width))
            imgs.append(src); labels.append("Original")
            let found = SubjectSegmentation.subjects(in: src)
            if let first = found.subjects.first, let m = SubjectSegmentation.mask(for: IndexSet(integer: first.id), in: src) {
                imgs.append(m); labels.append("Subject \(first.id) (\(first.kind == .person ? "person" : "object")), \(found.subjects.count) found")
                if let cut = VisionServices.applyMask(m, to: src, invert: false) {
                    // On a flat ground so the cutout edge reads.
                    if let ctx = Gfx.context(src.width, src.height) {
                        ctx.setFillColor(RGBA(hex: "E4572E").cgColor); ctx.fill(CGRect(x: 0, y: 0, width: src.width, height: src.height))
                        ctx.draw(cut, in: CGRect(x: 0, y: 0, width: src.width, height: src.height))
                        if let i = ctx.makeImage() { imgs.append(i); labels.append("Cutout of that subject only") }
                    }
                }
                if let refined = SubjectSegmentation.refine(mask: m, guide: src, amount: 0.8) { imgs.append(refined); labels.append("Edge refined") }
                let t0 = Date()
                if let removed = Inpainter.remove(from: src, mask: m) {
                    imgs.append(removed); labels.append(String(format: "Removed from the photo (%.1f s)", Date().timeIntervalSince(t0)))
                }
            }
            sheet(imgs, cols: 5, cell: cell2, labels: labels, to: out.appendingPathComponent("10-cutouts.png"))
            manifest.append(["file": "10-cutouts.png", "name": "Subjects, precise cutouts, edge refinement and object removal", "family": "Image"])
        }

        // 12. Shelf test: the cover among the genre's covers at Amazon thumbnail size.
        imgs = []; labels = []
        func shelfCover(_ title: String, author: String, genre: Genre, titleColor: RGBA, ground: RGBA, titleFrame: NRect, font: String) -> CoverDocument {
            var d = CoverDocument()
            d.book = BookInfo(title: title, author: author, genre: genre)
            d.palette = [ground, titleColor, RGBA(hex: "E8562A")]
            d.background = ground
            d.layers = [Layer.fill(.solid, colors: [ground], frame: .full),
                        Layer.text(title, role: .title, frame: titleFrame, font: font, color: titleColor),
                        Layer.text(author, role: .author, frame: NRect(0.15, 0.88, 0.7, 0.035), font: "Montserrat-Black", color: titleColor)]
            return d
        }
        let shelfCases: [(String, CoverDocument)] = [
            ("Big warm title on a cold shelf", shelfCover("Ash Year", author: "Oren Halvorsen", genre: .thriller, titleColor: RGBA(hex: "F2ECDF"), ground: RGBA(hex: "C8553D"), titleFrame: NRect(0.06, 0.2, 0.88, 0.45), font: "Anton-Regular")),
            ("Small gray title on gray", shelfCover("The Long Quiet Afternoon", author: "Ada Merrow", genre: .thriller, titleColor: RGBA(hex: "6A6A6A"), ground: RGBA(hex: "2A2A2E"), titleFrame: NRect(0.25, 0.45, 0.5, 0.06), font: "CormorantGaramond-SemiBold")),
        ]
        for (name, d) in shelfCases {
            if let r = ShelfTest.run(d, seed: 3) {
                imgs.append(r.grid)
                labels.append("\(name): standout \(Int(r.standout)). " + (r.notes.first ?? ""))
            }
        }
        if !imgs.isEmpty {
            let gw = CGFloat(imgs[0].width), gh = CGFloat(imgs[0].height)
            sheet(imgs, cols: 2, cell: CGSize(width: 640, height: 640 * gh / gw), labels: labels, to: out.appendingPathComponent("12-shelf.png"))
            manifest.append(["file": "12-shelf.png", "name": "Shelf test: your cover among the genre's covers at Amazon thumbnail size, with a standout score", "family": "Critic"])
        }

        // 13. Make it a 90: weak covers, then what the improver makes of them, with the scores.
        imgs = []; labels = []
        func weakCover(_ title: String, author: String, genre: Genre, photo: Data?, titleColor: RGBA, ground: RGBA, titleFrame: NRect) -> CoverDocument {
            var d = CoverDocument()
            d.book = BookInfo(title: title, subtitle: "A Novel", author: author, tagline: "Nothing stays buried.", genre: genre)
            d.palette = [ground, titleColor, RGBA(hex: "E8562A")]
            d.background = ground
            d.layers = [Layer.fill(.solid, colors: [ground], frame: .full)]
            if let photo { let id = d.addAsset(photo); d.layers.append(Layer.image(id, frame: .full)) }
            d.layers.append(Layer.text(title, role: .title, frame: titleFrame, font: "PlayfairDisplay-Black", color: titleColor))
            d.layers.append(Layer.text(author, role: .author, frame: NRect(0.2, 0.9, 0.6, 0.03), font: "Montserrat-Black", color: titleColor))
            return d
        }
        let weakCases: [(String, CoverDocument)] = [
            ("Pale on pale, tiny title", weakCover("The Salt Orchard", author: "Ines Valcourt", genre: .literary, photo: nil, titleColor: RGBA(hex: "E6E0D2"), ground: RGBA(hex: "D9D4C7"), titleFrame: NRect(0.3, 0.42, 0.4, 0.05))),
            ("Gray title over a busy photo", weakCover("No One Leaves", author: "Mara Kellen", genre: .thriller, photo: landscape, titleColor: RGBA(hex: "8A8A8A"), ground: RGBA(hex: "000000"), titleFrame: NRect(0.1, 0.4, 0.8, 0.14))),
            ("Mid-gray on a mid-gray ground", weakCover("Grace Under Glass", author: "Julien Achterberg", genre: .literary, photo: nil, titleColor: RGBA(hex: "7A7A7A"), ground: RGBA(hex: "8C8C8C"), titleFrame: NRect(0.08, 0.3, 0.84, 0.2))),
        ]
        for (name, d) in weakCases {
            let outcome = AutoImprover.run(d, target: 90, maxSteps: 12)
            if let before = shot(d) { imgs.append(before); labels.append("\(name): \(Int(outcome.start.score))") }
            if let after = shot(outcome.document) { imgs.append(after); labels.append("after \(outcome.steps) step\(outcome.steps == 1 ? "" : "s"): \(Int(outcome.report.score)) \(outcome.report.grade)") }
        }
        sheet(imgs, cols: 6, cell: cell, labels: labels, to: out.appendingPathComponent("13-improve.png"))
        manifest.append(["file": "13-improve.png", "name": "Make it a 90: repairs, then targeted edits kept only when the score rises", "family": "Critic"])

        // 11. Where readers look first.
        imgs = []; labels = []
        for id in ["literary-the-grid", "thriller-brand-name", "memoir-close", "fantasy-the-gate"] {
            guard let d = SignatureLibrary.design(id) else { continue }
            var base = SignatureLibrary.sampleDocument(d)
            if d.usesPhoto, let data = photos[d.sample.photo] ?? portrait { _ = base.addAsset(data) }
            let doc = SignatureLibrary.build(d, palette: 0, base: base)
            guard let full = shot(doc), let att = VisionServices.attention(for: full) else { continue }
            imgs.append(full); labels.append(d.name)
            if let ctx = Gfx.context(full.width, full.height) {
                ctx.draw(full, in: CGRect(x: 0, y: 0, width: full.width, height: full.height))
                ctx.setAlpha(0.85)
                ctx.interpolationQuality = .high
                ctx.draw(att.heat, in: CGRect(x: 0, y: 0, width: full.width, height: full.height))
                let r = Critic.review(doc)
                let note = r.issues.first { $0.kind == .attention }?.message ?? "eyes land on the title"
                if let i = ctx.makeImage() { imgs.append(i); labels.append(note) }
            }
        }
        sheet(imgs, cols: 8, cell: CGSize(width: 225, height: 360), labels: labels, to: out.appendingPathComponent("11-attention.png"))
        manifest.append(["file": "11-attention.png", "name": "Where readers look first: Apple's attention model over the finished cover, and the critic's note", "family": "Critic"])

        // 14. The physical book: the full wrap with guides, then the paperback mockups.
        imgs = []; labels = []
        if let design = SignatureLibrary.design("thriller-brand-name") {
            var base = SignatureLibrary.sampleDocument(design)
            if design.usesPhoto, let data = photos["portrait"] ?? portrait { _ = base.addAsset(data) }
            var doc = SignatureLibrary.build(design, palette: 0, base: base)
            doc.paperback.pageCount = 320
            doc.paperback.quote = "“Impossible to put down.” — a reviewer"
            doc.paperback.blurb = Array(repeating: "Nobody in Harrow Bay talks about the winter the ferry stopped running, least of all the man who sold the tickets.", count: 6).joined(separator: " ")
            doc.paperback.isbn = "978-0-306-40615-7"
            doc.paperback.priceCode = "51499"
            doc.paperback.category = "FICTION / THRILLER"
            doc.paperback.publisher = "Harrow Bay Press"
            doc.paperback.authorBio = "Mara Kellen grew up on the coast and worked the ferries for a decade before writing about them. She lives in Maine."
            doc.paperback.authorPhotoAssetID = doc.assetOrder.first
            let square = CGSize(width: 600, height: 600)
            if let wrap = PrintWrap.render(doc, dpi: 60, guides: true), let ctx = Gfx.context(600, 600) {
                // Letterbox the wide wrap into the square cell.
                ctx.setFillColor(RGBA(hex: "2A2A2E").cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
                let ww: CGFloat = 580, wh = ww * CGFloat(wrap.height) / CGFloat(wrap.width)
                ctx.draw(wrap, in: CGRect(x: 10, y: (600 - wh) / 2, width: ww, height: wh))
                if let i = ctx.makeImage() { imgs.append(i); labels.append("Full wrap, \(doc.paperback.pageCount) pages, with trim and bleed guides") }
            }
            if let i = MockupRenderer.physicalFront(doc, size: square) { imgs.append(i); labels.append("Paperback, front") }
            if let i = MockupRenderer.physicalBack(doc, size: square) { imgs.append(i); labels.append("Paperback, back") }
            if let i = MockupRenderer.physicalFlat(doc, size: square) { imgs.append(i); labels.append("Cover wrap, flat") }
            if let i = MockupRenderer.physicalStack(doc, size: square) { imgs.append(i); labels.append("Stack of three") }
        }
        if !imgs.isEmpty {
            sheet(imgs, cols: 5, cell: CGSize(width: 600, height: 600), labels: labels, to: out.appendingPathComponent("14-physical.png"))
            manifest.append(["file": "14-physical.png", "name": "The physical book: the full wrap with guides, and the paperback mockups front, back, flat and stacked", "family": "Print"])
        }

        // 15. The back cover up close, in its three layouts, with a real barcode.
        imgs = []; labels = []
        if let design = SignatureLibrary.design("thriller-brand-name") {
            var base = SignatureLibrary.sampleDocument(design)
            if design.usesPhoto, let data = photos["portrait"] ?? portrait { _ = base.addAsset(data) }
            var doc = SignatureLibrary.build(design, palette: 0, base: base)
            doc.paperback.pageCount = 320
            doc.paperback.quote = "“Impossible to put down.” — a reviewer"
            doc.paperback.blurb = Array(repeating: "Nobody in Harrow Bay talks about the winter the ferry stopped running, least of all the man who sold the tickets.", count: 6).joined(separator: " ")
            doc.paperback.isbn = "978-0-306-40615-7"
            doc.paperback.priceCode = "51499"
            doc.paperback.category = "FICTION / THRILLER"
            doc.paperback.publisher = "Harrow Bay Press"
            doc.paperback.authorBio = "Mara Kellen grew up on the coast and worked the ferries for a decade before writing about them. She lives in Maine."
            doc.paperback.authorPhotoAssetID = doc.assetOrder.first
            for layout in PrintSettings.BackLayout.allCases {
                doc.paperback.backLayout = layout
                guard let parts = MockupRenderer.wrapParts(doc, dpi: 100) else { continue }
                imgs.append(parts.back)
                labels.append("Back cover, \(layout.label)")
            }
            if let parts = MockupRenderer.wrapParts(doc, dpi: 100) { imgs.append(parts.spine); labels.append("Spine") }
        }
        if !imgs.isEmpty {
            let cellB = CGSize(width: 400, height: 600)
            sheet(imgs, cols: 4, cell: cellB, labels: labels, to: out.appendingPathComponent("15-back-cover.png"))
            manifest.append(["file": "15-back-cover.png", "name": "The back cover up close: classic, quote first and minimal layouts, with a real ISBN barcode, category, publisher and author photo", "family": "Print"])
        }

        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: out.appendingPathComponent("engine.json"))
    }
}
