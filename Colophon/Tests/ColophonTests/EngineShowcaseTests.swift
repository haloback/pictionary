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

    func testRenderEngineShowcase() throws {
        guard let dir = ProcessInfo.processInfo.environment["COLOPHON_SAMPLES"] else { throw XCTSkip("COLOPHON_SAMPLES not set") }
        let out = URL(fileURLWithPath: dir).appendingPathComponent("engine", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let cell = CGSize(width: 300, height: 480)
        func shot(_ d: CoverDocument) -> CGImage? { CoverRenderer.shared.render(d, size: cell, quality: .full) }
        let portrait = loadPhoto(["sig/portrait.jpg", "b-monalisa.jpg"])
        let landscape = loadPhoto(["sig/landscape.jpg", "c-earth.jpg"])
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
            else { d.layers.append(Layer.fill(.splatter, colors: [RGBA(hex: "5A5A5A"), RGBA(hex: "B0B0B0"), RGBA(hex: "202020")], frame: .full, seed: 9, intensity: 0.9)) }
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

        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: out.appendingPathComponent("engine.json"))
    }
}
