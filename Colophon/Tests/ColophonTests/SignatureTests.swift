import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import Colophon

final class SignatureTests: XCTestCase {
    private func photoData() throws -> Data {
        let ctx = try XCTUnwrap(Gfx.context(300, 480))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: 300, height: 480), [RGBA(hex: "13404A"), RGBA(hex: "F2A541")], angle: 90)
        ctx.setFillColor(RGBA(hex: "121417").cgColor)
        ctx.fillEllipse(in: CGRect(x: 90, y: 120, width: 120, height: 240))
        return try XCTUnwrap(AssetStore.encode(try XCTUnwrap(ctx.makeImage())))
    }

    func testCollectionHasAHundredUniqueDesigns() {
        let all = SignatureLibrary.all
        XCTAssertGreaterThanOrEqual(all.count, 100)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        for g in Genre.allCases {
            XCTAssertGreaterThanOrEqual(all.filter { $0.genre == g }.count, 6, g.rawValue)
        }
        for d in all {
            XCTAssertTrue((1...5).contains(d.palettes.count), d.id)
            XCTAssertFalse(d.idea.isEmpty, d.id)
            XCTAssertFalse(d.id.contains("."), d.id)
            let hasTitle = d.elements.contains { if case .text(.title, _, _) = $0 { return true }; return false }
            XCTAssertTrue(hasTitle, "\(d.id) has no title")
        }
    }

    func testDesignsUseBundledFonts() {
        let bundled = Set(BundledFonts.entries.map(\.id))
        for d in SignatureLibrary.all {
            for e in d.elements {
                guard case .text(_, _, let t) = e, let first = t.fonts.first else { continue }
                XCTAssertTrue(bundled.contains(first), "\(d.id) uses \(first)")
            }
        }
    }

    func testEveryDesignBuildsWithAndWithoutAPhoto() throws {
        let photo = try photoData()
        for d in SignatureLibrary.all {
            let bare = SignatureLibrary.sampleDocument(d)
            var withPhoto = bare
            _ = withPhoto.addAsset(photo)
            for base in [bare, withPhoto] {
                let doc = SignatureLibrary.build(d, palette: 0, base: base)
                XCTAssertNotNil(doc.textLayer(role: .title), d.id)
                XCTAssertEqual(doc.templateID, "sig.\(d.id).0")
                if d.usesPhoto && !base.assetOrder.isEmpty {
                    XCTAssertTrue(doc.layers.contains { $0.imageContent != nil }, d.id)
                }
                XCTAssertNotNil(CoverRenderer.shared.render(doc, size: CGSize(width: 100, height: 160), quality: .preview), d.id)
            }
        }
    }

    func testSignatureTemplatesAreListedFirstAndApply() throws {
        let lib = TemplateLibrary.shared
        let sigs = lib.templates.filter(\.isSignature)
        XCTAssertEqual(sigs.count, SignatureLibrary.all.reduce(0) { $0 + $1.palettes.count })
        XCTAssertTrue(lib.templates.first?.isSignature ?? false)
        let found = lib.search("", genre: nil, tags: ["signature"])
        XCTAssertEqual(found.count, sigs.count)
        let t = try XCTUnwrap(sigs.last)
        var base = CoverDocument()
        base.book = BookInfo(title: "Paper Lanterns", author: "Wren Abara", genre: t.genre)
        let doc = lib.apply(t, to: base)
        XCTAssertEqual(doc.templateID, t.id)
        XCTAssertEqual(doc.book.title, "Paper Lanterns")
        XCTAssertEqual(doc.textLayer(role: .title)?.textContent?.text.replacingOccurrences(of: "\n", with: " "), "Paper Lanterns")
    }

    func testRandomizerKeepsASignatureLayoutAndChangesItsPalette() throws {
        let d = try XCTUnwrap(SignatureLibrary.all.first { $0.palettes.count > 1 })
        let start = SignatureLibrary.build(d, palette: 0, base: SignatureLibrary.sampleDocument(d))
        var o = SmartRandomizer.Options()
        o.locks = [.layout]
        let out = SmartRandomizer.randomize(start, options: o, recent: [], seed: 42)
        let sig = try XCTUnwrap(SmartRandomizer.signatureOf(out))
        XCTAssertEqual(sig.0.id, d.id)
        XCTAssertNotEqual(sig.1, 0)
    }

    func testRandomizerSometimesPicksSignatureDesigns() {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Long Quiet", author: "Ada Merrow", genre: .literary)
        var hits = 0
        for s in 1...30 {
            let out = SmartRandomizer.randomize(base, options: .init(), recent: [], seed: s)
            if SmartRandomizer.signatureOf(out) != nil { hits += 1 }
        }
        XCTAssertGreaterThan(hits, 0)
        XCTAssertLessThan(hits, 30)
    }
}

extension SampleRenderTests {
    /// Every Signature design, in its hero palette with a matching public-domain photo, plus its other palettes
    /// and (for photo designs) the painted version used before the author adds a photo.
    func testRenderSignatureCollection() throws {
        guard let dir = ProcessInfo.processInfo.environment["COLOPHON_SAMPLES"] else { throw XCTSkip("COLOPHON_SAMPLES not set") }
        let out = URL(fileURLWithPath: dir).appendingPathComponent("signature", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var photos: [String: Data] = [:]
        if let pdir = ProcessInfo.processInfo.environment["COLOPHON_PHOTOS"] {
            let root = URL(fileURLWithPath: pdir)
            let picks: [(String, [String])] = [("portrait", ["sig/portrait.jpg", "b-monalisa.jpg"]),
                                                ("landscape", ["sig/landscape.jpg", "c-earth.jpg"]),
                                                ("space", ["c-earth.jpg", "a-aldrin.jpg"])]
            for (hint, files) in picks {
                for f in files {
                    if let data = try? Data(contentsOf: root.appendingPathComponent(f)), data.count > 10_000 { photos[hint] = data; break }
                }
            }
        }
        var manifest: [[String: Any]] = []
        for (i, d) in SignatureLibrary.all.enumerated() {
            let bare = SignatureLibrary.sampleDocument(d)
            var withPhoto = bare
            if d.usesPhoto, let data = photos[d.sample.photo] ?? photos["portrait"] ?? photos.values.first {
                _ = withPhoto.addAsset(data)
            }
            let stem = String(format: "%03d-%@", i, d.id)
            var files: [String] = []
            func shoot(_ doc: CoverDocument, _ name: String, _ h: CGFloat) {
                guard let img = CoverRenderer.shared.render(doc, size: CGSize(width: (h / 1.6).rounded(), height: h), quality: .full) else { return }
                if Exporter.write(img, to: out.appendingPathComponent(name), format: .jpeg, quality: 0.86) { files.append(name) }
            }
            shoot(SignatureLibrary.build(d, palette: 0, base: withPhoto), stem + ".jpg", 960)
            for k in 1..<d.palettes.count {
                shoot(SignatureLibrary.build(d, palette: k, base: withPhoto), stem + "-p\(k).jpg", 576)
            }
            if d.usesPhoto { shoot(SignatureLibrary.build(d, palette: 0, base: bare), stem + "-nophoto.jpg", 576) }
            manifest.append(["id": d.id, "name": d.name, "genre": d.genre.label, "idea": d.idea, "tags": d.tags,
                             "palettes": d.palettes.map(\.name), "files": files])
        }
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: out.appendingPathComponent("signature.json"))
    }
}
