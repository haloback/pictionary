import CoreGraphics
import CoreImage
import XCTest
@testable import Colophon

final class CompositorTests: XCTestCase {
    /// Full-resolution RGBA8 pixel at (x, y), top-left origin.
    private func pixel(_ img: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let p = PixelSampler.pixels(img, maxSide: 4000)
        let i = (y * p.w + x) * 4
        return (Int(p.data[i]), Int(p.data[i + 1]), Int(p.data[i + 2]), Int(p.data[i + 3]))
    }

    private func gray(_ v: Double) -> RGBA { RGBA(v, v, v) }

    func testKnockoutRevealsBackgroundColor() throws {
        var doc = CoverDocument()
        doc.background = RGBA(hex: "E4572E")
        doc.layers = [Layer.fill(.solid, colors: [RGBA(hex: "1B2A4A")])]
        var hole = Layer.shape(.rectangle, fill: .white, frame: NRect(0.3, 0.3, 0.4, 0.4))
        hole.knockout = true
        doc.layers.append(hole)

        let img = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 100, height: 160)))
        let center = pixel(img, 50, 80)
        XCTAssertEqual(Double(center.r), 0xE4, accuracy: 3)
        XCTAssertEqual(Double(center.g), 0x57, accuracy: 3)
        XCTAssertEqual(Double(center.b), 0x2E, accuracy: 3)
        XCTAssertEqual(center.a, 255, "the export must stay opaque")
        let corner = pixel(img, 5, 5)
        XCTAssertEqual(Double(corner.r), 0x1B, accuracy: 3)
        XCTAssertEqual(Double(corner.b), 0x4A, accuracy: 3)
        XCTAssertEqual(corner.a, 255)
    }

    func testLinearMultiplyIsDarkerThanGammaMultiply() throws {
        func render(linear: Bool) throws -> Int {
            var doc = CoverDocument()
            doc.background = .white
            doc.layers = [Layer.fill(.solid, colors: [gray(0.4)])]
            var top = Layer.fill(.solid, colors: [gray(0.4)])
            top.blend = .multiply
            top.linearBlend = linear
            doc.layers.append(top)
            let img = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 80, height: 80)))
            let p = pixel(img, 40, 40)
            XCTAssertEqual(p.a, 255)
            return p.r
        }
        let gamma = try render(linear: false)
        let linear = try render(linear: true)
        // 0.4 * 0.4 in sRGB is 0.16 (41); in linear light it is 0.133^2, back to sRGB about 0.14 (36).
        XCTAssertEqual(Double(gamma), 41, accuracy: 3)
        XCTAssertLessThan(linear, gamma - 2, "linear-light multiply should land darker")
        XCTAssertGreaterThan(linear, 20)
    }

    func testLinearBlendOnlyTouchesItsRegion() throws {
        var doc = CoverDocument()
        doc.background = RGBA(hex: "E4572E")
        var top = Layer.fill(.solid, colors: [gray(0.5)], frame: NRect(0.5, 0, 0.5, 1))
        top.blend = .multiply
        top.linearBlend = true
        doc.layers = [top]
        let img = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 100, height: 100)))
        let left = pixel(img, 20, 50)
        XCTAssertEqual(Double(left.r), 0xE4, accuracy: 2)
        XCTAssertEqual(Double(left.g), 0x57, accuracy: 2)
        let right = pixel(img, 80, 50)
        XCTAssertLessThan(right.r, 0xE4 - 40)
        XCTAssertEqual(right.a, 255)
    }

    func testGradientMapRunsFirstStopToLast() throws {
        let doc = CoverDocument()
        var layer = Layer.fill(.linear, colors: [.black, .white], angle: 90)
        layer.gradientMap = [RGBA(1, 0, 0), RGBA(0, 0, 1)]
        let canvas = CGSize(width: 100, height: 160)
        let r = try XCTUnwrap(CoverRenderer.shared.rasterize(layer, doc: doc, canvas: canvas, quality: .preview))
        let top = pixel(r.image, 50, 1)
        XCTAssertGreaterThan(top.r, 200, "dark end maps to the first color")
        XCTAssertLessThan(top.b, 80)
        let bottom = pixel(r.image, 50, r.image.height - 2)
        XCTAssertGreaterThan(bottom.b, 200, "light end maps to the last color")
        XCTAssertLessThan(bottom.r, 80)
        XCTAssertEqual(top.a, 255)
    }

    func testFeatherSoftensTheEdge() throws {
        let doc = CoverDocument()
        let canvas = CGSize(width: 200, height: 200)
        let frame = NRect(0.25, 0.25, 0.5, 0.5)
        let crisp = try XCTUnwrap(CoverRenderer.shared.rasterize(Layer.shape(.rectangle, fill: .white, frame: frame), doc: doc, canvas: canvas, quality: .preview))
        XCTAssertGreaterThan(pixel(crisp.image, 0, 50).a, 240)

        var soft = Layer.shape(.rectangle, fill: .white, frame: frame)
        soft.feather = 0.5
        let r = try XCTUnwrap(CoverRenderer.shared.rasterize(soft, doc: doc, canvas: canvas, quality: .preview))
        let edge = pixel(r.image, 0, 50)
        XCTAssertLessThan(edge.a, 200, "feathered edge is partly transparent")
        XCTAssertGreaterThan(edge.a, 10)
        XCTAssertGreaterThan(pixel(r.image, 50, 50).a, 240, "the middle stays solid")
    }

    func testInnerShadowDarkensTopEdge() throws {
        let doc = CoverDocument()
        let canvas = CGSize(width: 200, height: 200)
        var layer = Layer.shape(.rectangle, fill: .white, frame: .full)
        layer.innerShadow = ShadowStyle(color: RGBA(0, 0, 0, 0.9), radius: 0.04, dx: 0, dy: 0.06)
        let r = try XCTUnwrap(CoverRenderer.shared.rasterize(layer, doc: doc, canvas: canvas, quality: .preview))
        let top = pixel(r.image, 100, 3)
        let center = pixel(r.image, 100, 100)
        let bottom = pixel(r.image, 100, r.image.height - 4)
        XCTAssertGreaterThan(center.r, 240)
        XCTAssertLessThan(top.r, center.r - 60, "the top edge sits in shadow")
        XCTAssertGreaterThan(bottom.r, top.r + 40, "the shadow is offset downward, so the bottom edge is lighter")
        XCTAssertEqual(top.a, 255, "the shadow stays inside the shape")
    }

    func testAutoContrastBackingIsNilOnPlainHighContrastGround() throws {
        let ctx = try XCTUnwrap(Gfx.context(200, 200))
        ctx.setFillColor(RGBA.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        let bg = try XCTUnwrap(ctx.makeImage())
        let text = Layer.text("TITLE", role: .title, frame: NRect(0.1, 0.4, 0.8, 0.2), font: "Didot", color: .white)
        XCTAssertNil(Compositor.autoContrastBacking(for: text, background: bg, canvas: CGSize(width: 200, height: 200)))
    }

    func testAutoContrastBackingAppearsOnBusyGround() throws {
        let ctx = try XCTUnwrap(Gfx.context(200, 200))
        for y in stride(from: 0, to: 200, by: 8) {
            for x in stride(from: 0, to: 200, by: 8) {
                ctx.setFillColor(((x / 8 + y / 8) % 2 == 0 ? RGBA.black : RGBA.white).cgColor)
                ctx.fill(CGRect(x: x, y: y, width: 8, height: 8))
            }
        }
        let bg = try XCTUnwrap(ctx.makeImage())
        let frame = NRect(0.1, 0.4, 0.8, 0.2)
        let text = Layer.text("TITLE", role: .title, frame: frame, font: "Didot", color: .white)
        let backing = try XCTUnwrap(Compositor.autoContrastBacking(for: text, background: bg, canvas: CGSize(width: 200, height: 200)))
        XCTAssertEqual(backing.fade, .vignette)
        XCTAssertEqual(backing.fadeAmount, 0.85, accuracy: 0.001)
        XCTAssertGreaterThan(backing.opacity, 0.05)
        XCTAssertLessThanOrEqual(backing.opacity, 0.6)
        XCTAssertEqual(backing.fillContent?.style, .solid)
        XCTAssertTrue(backing.fillContent?.colors.first?.isDark ?? false, "white type gets a dark backing")
        XCTAssertLessThanOrEqual(backing.frame.x, frame.x)
        XCTAssertGreaterThanOrEqual(backing.frame.maxX, frame.maxX)
        XCTAssertNotNil(backing.fillContent)
        XCTAssertNil(backing.textContent)
    }

    func testNewLayerFieldsRoundTripAndDefault() throws {
        var layer = Layer.fill(.solid, colors: [.black])
        layer.knockout = true
        layer.linearBlend = true
        layer.gradientMap = [.black, .white]
        layer.feather = 0.3
        layer.innerShadow = ShadowStyle()
        let data = try JSONEncoder().encode(layer)
        let back = try JSONDecoder().decode(Layer.self, from: data)
        XCTAssertEqual(back, layer)

        // Older documents carry none of the new keys and open with the defaults.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["knockout", "linearBlend", "gradientMap", "feather", "innerShadow"] { json[key] = nil }
        let old = try JSONDecoder().decode(Layer.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(old.knockout)
        XCTAssertFalse(old.linearBlend)
        XCTAssertNil(old.gradientMap)
        XCTAssertEqual(old.feather, 0)
        XCTAssertNil(old.innerShadow)
    }
}
