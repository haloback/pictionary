import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

final class CutoutTests: XCTestCase {
    private let background = (r: 182, g: 170, b: 148)
    /// The dark square, in top-left pixel coordinates of the 400×400 picture.
    private let square = CGRect(x: 170, y: 170, width: 60, height: 60)

    /// 400×400 flat background with a sharp dark square in the middle.
    private func squareImage() throws -> CGImage {
        let w = 400, h = 400
        let ctx = try XCTUnwrap(Gfx.context(w, h))
        ctx.setFillColor(CGColor(red: CGFloat(background.r) / 255, green: CGFloat(background.g) / 255, blue: CGFloat(background.b) / 255, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(red: 0.08, green: 0.05, blue: 0.1, alpha: 1))
        // Bottom-left context; the square is centered so the flip does not matter.
        ctx.fill(square)
        return try XCTUnwrap(ctx.makeImage())
    }

    /// Gray mask: white inside `rect` (top-left coordinates), black elsewhere.
    private func rectMask(_ rect: CGRect, w: Int = 400, h: Int = 400) throws -> CGImage {
        let ctx = try XCTUnwrap(Gfx.grayContext(w, h))
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: rect.minX, y: CGFloat(h) - rect.maxY, width: rect.width, height: rect.height))
        return try XCTUnwrap(ctx.makeImage())
    }

    /// RGB at a top-left pixel position, read at the image's own size.
    private func rgb(_ img: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        let p = PixelSampler.pixels(img, maxSide: max(img.width, img.height))
        let sx = x * p.w / img.width, sy = y * p.h / img.height
        let i = (sy * p.w + sx) * 4
        return (Int(p.data[i]), Int(p.data[i + 1]), Int(p.data[i + 2]))
    }

    // MARK: Inpainting

    func testInpaintFillsSquareWithBackground() throws {
        let img = try squareImage()
        let mask = try rectMask(square)
        let start = Date()
        let out = try XCTUnwrap(Inpainter.remove(from: img, mask: mask))
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5, "inpainting a 400 px picture took \(elapsed) s")
        XCTAssertEqual(out.width, 400)
        XCTAssertEqual(out.height, 400)
        // The ground as it actually landed in the picture (CGColor(red:green:blue:) is generic RGB, not sRGB).
        let ground = rgb(img, 20, 20)
        let c = rgb(out, 200, 200)
        XCTAssertLessThanOrEqual(abs(c.r - ground.r), 12, "center red \(c.r) vs \(ground.r)")
        XCTAssertLessThanOrEqual(abs(c.g - ground.g), 12, "center green \(c.g) vs \(ground.g)")
        XCTAssertLessThanOrEqual(abs(c.b - ground.b), 12, "center blue \(c.b) vs \(ground.b)")
        // Far from the hole nothing changes.
        let corner = rgb(out, 20, 20)
        XCTAssertEqual(corner.r, ground.r)
        XCTAssertEqual(corner.g, ground.g)
        XCTAssertEqual(corner.b, ground.b)
    }

    func testInpaintWithEmptyMaskReturnsPicture() throws {
        let img = try squareImage()
        let mask = try rectMask(.zero)
        let out = try XCTUnwrap(Inpainter.remove(from: img, mask: mask))
        let c = rgb(out, 200, 200)
        XCTAssertLessThan(c.r, 40, "the square must still be there when nothing is masked")
    }

    func testStrokeMaskPaintsWhiteWherePainted() throws {
        let stroke = MaskStroke(restore: false, radius: 0.05, points: [NPoint(x: 0.5, y: 0.5)])
        let m = try XCTUnwrap(Inpainter.strokeMask([stroke], width: 200, height: 200))
        XCTAssertGreaterThan(rgb(m, 100, 100).r, 250)
        XCTAssertLessThan(rgb(m, 10, 10).r, 5)
    }

    // MARK: Matting

    func testRefineKeepsHardMask() throws {
        let img = try squareImage()
        let mask = try rectMask(CGRect(x: 100, y: 100, width: 200, height: 200))
        for amount in [0.0, 0.5, 1.0] {
            let out = try XCTUnwrap(SubjectSegmentation.refine(mask: mask, guide: img, amount: amount))
            XCTAssertEqual(out.width, 400)
            XCTAssertEqual(out.height, 400)
            XCTAssertGreaterThanOrEqual(rgb(out, 200, 200).r, 250, "interior at amount \(amount)")
            XCTAssertLessThanOrEqual(rgb(out, 20, 20).r, 5, "exterior at amount \(amount)")
            XCTAssertLessThanOrEqual(rgb(out, 380, 380).r, 5, "far corner at amount \(amount)")
        }
    }

    func testBoxMeanOfConstantIsConstant() {
        let w = 20, h = 15
        let src = [Float](repeating: 0.4, count: w * h)
        let m = SubjectSegmentation.boxMean(src, w, h, 5)
        XCTAssertEqual(m.count, w * h)
        for v in m { XCTAssertEqual(v, 0.4, accuracy: 1e-5) }
    }

    // MARK: Model

    func testKeptSubjectsRoundTrip() throws {
        var ic = ImageContent(assetID: UUID())
        ic.keptSubjects = [1, 3]
        ic.edgeRefine = 0.4
        ic.cutout = .subject
        let data = try JSONEncoder().encode(ic)
        let back = try JSONDecoder().decode(ImageContent.self, from: data)
        XCTAssertEqual(back, ic)
        XCTAssertEqual(back.keptSubjects, [1, 3])
        XCTAssertEqual(back.edgeRefine, 0.4, accuracy: 1e-9)

        var none = ImageContent(assetID: UUID())
        none.keptSubjects = nil
        let back2 = try JSONDecoder().decode(ImageContent.self, from: JSONEncoder().encode(none))
        XCTAssertNil(back2.keptSubjects)
    }

    func testOldImageContentJSONDecodes() throws {
        let id = UUID()
        let json = "{\"assetID\":\"\(id.uuidString)\",\"cutout\":\"subject\",\"zoom\":1.5}"
        let ic = try JSONDecoder().decode(ImageContent.self, from: Data(json.utf8))
        XCTAssertEqual(ic.assetID, id)
        XCTAssertEqual(ic.cutout, .subject)
        XCTAssertNil(ic.keptSubjects)
        XCTAssertEqual(ic.edgeRefine, 0)
        XCTAssertTrue(ic.maskEdits.isEmpty)
    }

    // MARK: Vision

    func testSubjectsRunOnSyntheticImage() throws {
        let img = try squareImage()
        let found = SubjectSegmentation.subjects(in: img)
        // Vision may or may not call a flat square a subject; what matters is a sane answer.
        for s in found.subjects {
            XCTAssertGreaterThan(s.id, 0)
            XCTAssertGreaterThan(s.area, 0)
            XCTAssertLessThanOrEqual(s.area, 1)
            XCTAssertGreaterThanOrEqual(s.bounds.x, 0)
            XCTAssertLessThanOrEqual(s.bounds.maxX, 1.0001)
            XCTAssertLessThanOrEqual(s.bounds.maxY, 1.0001)
        }
        if let labels = found.labels {
            XCTAssertGreaterThan(labels.width, 0)
            _ = SubjectSegmentation.instance(at: 0.5, 0.5, labels: labels)
        }
        if let first = found.subjects.first {
            let m = SubjectSegmentation.mask(for: IndexSet(integer: first.id), in: img)
            XCTAssertNotNil(m)
        }
    }
}
