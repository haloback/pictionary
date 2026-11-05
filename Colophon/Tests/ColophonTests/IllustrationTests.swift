import AppKit
import CoreGraphics
import XCTest
@testable import Colophon

final class IllustrationTests: XCTestCase {
    private typealias Item = IllustrationLibrary.Item

    private func fakeItems() -> [Item] {
        [
            Item(id: "test.outline.sword", name: "Sword", pack: "test", path: "sword.svg",
                 tags: IllustrationLibrary.tags(forSlug: "sword"), style: .outline),
            Item(id: "test.filled.shield", name: "Shield", pack: "test", path: "shield.svg",
                 tags: ["shield", "sword", "knight"], style: .filled),
            Item(id: "test.filled.teacup", name: "Teacup", pack: "test", path: "teacup.svg",
                 tags: IllustrationLibrary.tags(forSlug: "teacup"), style: .filled)
        ]
    }

    func testSynonymMapIsLarge() {
        XCTAssertGreaterThanOrEqual(IllustrationLibrary.synonyms.count, 150)
        XCTAssertTrue(IllustrationLibrary.synonyms["sword"]?.contains("fantasy") ?? false)
        XCTAssertTrue(IllustrationLibrary.synonyms["skull"]?.contains("horror") ?? false)
        XCTAssertTrue(IllustrationLibrary.synonyms["teapot"]?.contains("cozy") ?? false)
        // Name words, their singular form and the motifs they map to all become tags.
        let tags = IllustrationLibrary.tags(forSlug: "two-swords")
        XCTAssertTrue(tags.contains("sword"))
        XCTAssertTrue(tags.contains("fantasy"))
        XCTAssertTrue(tags.contains("two"))
    }

    func testSearchRanksNameAboveTag() {
        let lib = IllustrationLibrary.shared
        lib.register(items: fakeItems())
        let hits = lib.search("sword", pack: "test").map(\.id)
        XCTAssertEqual(hits.first, "test.outline.sword")
        XCTAssertTrue(hits.contains("test.filled.shield"))
        XCTAssertFalse(hits.contains("test.filled.teacup"))
        // Synonyms: "cozy" finds the teacup through its tags; style filters apply.
        XCTAssertEqual(lib.search("cozy", pack: "test").map(\.id), ["test.filled.teacup"])
        XCTAssertEqual(lib.search("sword", pack: "test", style: .filled).map(\.id), ["test.filled.shield"])
        XCTAssertEqual(lib.search("", pack: "test").count, 3)
        XCTAssertEqual(lib.search("", pack: "test", limit: 2).count, 2)
        XCTAssertTrue(lib.search("sword teacup", pack: "test").isEmpty)
    }

    func testClassifyPackFiles() {
        let t = IllustrationLibrary.classify(packID: "tabler", relativePath: "svg/outline/sword.svg")
        XCTAssertEqual(t?.id, "tabler.outline.sword")
        XCTAssertEqual(t?.style, .outline)
        XCTAssertNil(IllustrationLibrary.classify(packID: "tabler", relativePath: "readme/sword.svg"))
        let p = IllustrationLibrary.classify(packID: "phosphor", relativePath: "core-main/assets/fill/sword-fill.svg")
        XCTAssertEqual(p?.id, "phosphor.filled.sword")
        XCTAssertEqual(p?.name, "Sword")
        XCTAssertNil(IllustrationLibrary.classify(packID: "phosphor", relativePath: "core-main/assets/thin/sword-thin.svg"))
        let g = IllustrationLibrary.classify(packID: "gameicons", relativePath: "icons/000000/transparent/lorc/broadsword.svg")
        XCTAssertEqual(g?.id, "gameicons.lorc.broadsword")
        XCTAssertEqual(g?.artist, "lorc")
        XCTAssertEqual(g?.style, .filled)
    }

    func testRenderTintsSVGAlpha() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10"><path d="M0 0h10v10H0z"/></svg>
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("colophon-illustration-\(UUID().uuidString).svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let red = RGBA(1, 0, 0, 1)
        let img = try XCTUnwrap(IllustrationLibrary.render(svg: url, size: CGSize(width: 64, height: 64), color: red))
        XCTAssertEqual(img.width, 64)
        XCTAssertEqual(img.height, 64)
        let px = try XCTUnwrap(pixel(img, 32, 32))
        XCTAssertEqual(px.a, 255)
        XCTAssertGreaterThan(px.r, 240)
        XCTAssertLessThan(px.g, 15)
        XCTAssertLessThan(px.b, 15)
        // A horizontal stripe: flipping mirrors it.
        let half = """
        <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10"><path d="M0 0h5v10H0z"/></svg>
        """
        try half.write(to: url, atomically: true, encoding: .utf8)
        let left = try XCTUnwrap(IllustrationLibrary.render(svg: url, size: CGSize(width: 64, height: 64), color: red))
        XCTAssertEqual(pixel(left, 8, 32)?.a, 255)
        XCTAssertEqual(pixel(left, 56, 32)?.a, 0)
        let flipped = try XCTUnwrap(IllustrationLibrary.render(svg: url, size: CGSize(width: 64, height: 64), color: red, flipped: true))
        XCTAssertEqual(pixel(flipped, 8, 32)?.a, 0)
        XCTAssertEqual(pixel(flipped, 56, 32)?.a, 255)
    }

    func testContentCoding() throws {
        var c = IllustrationContent(itemID: "tabler.outline.sword", color: RGBA(hex: "112233"))
        c.color2 = RGBA(hex: "445566")
        c.flipped = true
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(IllustrationContent.self, from: data)
        XCTAssertEqual(back, c)
        // Old JSON without the newer fields still decodes with defaults.
        let old = #"{"itemID":"tabler.outline.sword","color":{"r":1,"g":0,"b":0,"a":1}}"#
        let legacy = try JSONDecoder().decode(IllustrationContent.self, from: Data(old.utf8))
        XCTAssertEqual(legacy.itemID, "tabler.outline.sword")
        XCTAssertNil(legacy.color2)
        XCTAssertFalse(legacy.flipped)
        // The layer enum round-trips, and documents made before illustrations existed still open.
        let layer = Layer.illustration("tabler.outline.sword", color: .nearWhite, frame: NRect(0.35, 0.35, 0.3, 0.2))
        let layerBack = try JSONDecoder().decode(Layer.self, from: try JSONEncoder().encode(layer))
        XCTAssertEqual(layerBack.illustrationContent?.itemID, "tabler.outline.sword")
        XCTAssertEqual(layerBack.kindSymbol, "leaf")
        var doc = CoverDocument()
        doc.layers = [Layer.fill(.solid, colors: [.ink]), Layer.decor("x", color: .nearWhite, frame: .full)]
        let docBack = try JSONDecoder().decode(CoverDocument.self, from: try JSONEncoder().encode(doc))
        XCTAssertEqual(docBack.layers.count, 2)
        XCTAssertNotNil(docBack.layers[1].decorContent)
    }

    func testCreditsNameGameIconsArtists() {
        let lib = IllustrationLibrary.shared
        lib.register(items: [
            Item(id: "gameicons.lorc.broadsword", name: "Broadsword", pack: "gameicons", path: "icons/lorc/broadsword.svg",
                 tags: ["broadsword", "sword"], style: .filled, artist: "lorc"),
            Item(id: "tabler.outline.sword", name: "Sword", pack: "tabler", path: "svg/outline/sword.svg",
                 tags: ["sword"], style: .outline)
        ])
        var doc = CoverDocument()
        doc.layers = [Layer.illustration("tabler.outline.sword", color: .nearWhite, frame: .full)]
        XCTAssertEqual(lib.credits(for: doc), "")
        doc.layers.append(Layer.illustration("gameicons.lorc.broadsword", color: .nearWhite, frame: .full))
        doc.layers.append(Layer.illustration("gameicons.lorc.broadsword", color: .ink, frame: .full))
        let text = lib.credits(for: doc)
        XCTAssertTrue(text.contains("Lorc"))
        XCTAssertTrue(text.contains("game-icons.net, CC BY 3.0"))
        XCTAssertEqual(text.components(separatedBy: "Lorc —").count, 2, "each artist is credited once")
        XCTAssertEqual(doc.layers[1].name, "Broadsword")
    }

    private func pixel(_ img: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int)? {
        guard let data = img.dataProvider?.data, let p = CFDataGetBytePtr(data) else { return nil }
        let bpr = img.bytesPerRow
        let i = y * bpr + x * 4
        return (Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3]))
    }
}
