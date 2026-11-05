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

        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: out.appendingPathComponent("engine.json"))
    }
}
