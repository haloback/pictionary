import XCTest
import CoreGraphics
import Foundation
@testable import Colophon

/// Type on a path (circle) and warped type (wave, flag, bulge, pinch, rise, fall, perspective).
final class TextPathTests: XCTestCase {
    private let sample = "The Salt Orchard"

    private func content(_ path: TextPath, amount: Double = 0.5) -> TextContent {
        var t = TextContent(text: sample, role: .title, fontName: "Didot")
        t.path = path
        t.pathAmount = amount
        t.opticalTracking = false
        return t
    }

    /// Alpha plane of a rendered text image at full resolution.
    private func alpha(_ img: CGImage) -> (data: [UInt8], w: Int, h: Int) {
        let p = PixelSampler.pixels(img, maxSide: 4000)
        var a = [UInt8](repeating: 0, count: p.w * p.h)
        for i in 0..<(p.w * p.h) { a[i] = p.data[i * 4 + 3] }
        return (a, p.w, p.h)
    }

    private func inkCount(_ img: CGImage) -> Int {
        let a = alpha(img)
        return a.data.filter { $0 > 40 }.count
    }

    /// Topmost and bottommost rows carrying ink.
    private func inkRows(_ img: CGImage) -> (top: Int, bottom: Int) {
        let a = alpha(img)
        var top = a.h, bottom = -1
        for y in 0..<a.h {
            for x in 0..<a.w where a.data[y * a.w + x] > 40 {
                top = min(top, y); bottom = max(bottom, y)
                break
            }
        }
        return (top, bottom)
    }

    /// Vertical ink extent (in rows) of every column, left to right.
    private func columnHeights(_ img: CGImage) -> [Int] {
        let a = alpha(img)
        var out: [Int] = []
        for x in 0..<a.w {
            var top = a.h, bottom = -1
            for y in 0..<a.h where a.data[y * a.w + x] > 40 {
                top = min(top, y); bottom = max(bottom, y)
            }
            out.append(bottom >= top ? bottom - top + 1 : 0)
        }
        return out
    }

    func testEveryPathRendersInk() throws {
        let box = CGSize(width: 300, height: 200)
        for path in TextPath.allCases {
            let (img, pad) = try XCTUnwrap(TextRenderer.render(content(path), box: box, canvasHeight: 1000), path.label)
            XCTAssertGreaterThanOrEqual(img.width, Int(box.width), path.label)
            XCTAssertGreaterThanOrEqual(pad, 2, path.label)
            XCTAssertGreaterThan(inkCount(img), 200, "\(path.label) leaves ink")
        }
    }

    func testCircleAtFullAmountCoversEveryQuadrant() throws {
        let box = CGSize(width: 240, height: 240)
        let t = content(.circle, amount: 1)
        let (img, _) = try XCTUnwrap(TextRenderer.render(t, box: box, canvasHeight: 1000))
        let a = alpha(img)
        var quadrants = [Int](repeating: 0, count: 4)
        for y in 0..<a.h {
            for x in 0..<a.w where a.data[y * a.w + x] > 40 {
                let q = (x < a.w / 2 ? 0 : 1) + (y < a.h / 2 ? 0 : 2)
                quadrants[q] += 1
            }
        }
        for (q, n) in quadrants.enumerated() {
            XCTAssertGreaterThan(n, 50, "quadrant \(q) carries ink")
        }
        // The fitted size keeps the glyphs no taller than the radius.
        let size = TextRenderer.fittedSize(t, box: box)
        XCTAssertGreaterThan(size, 2)
        XCTAssertLessThanOrEqual(size, box.height / 2)
        // Less of the circle means smaller type.
        var half = t
        half.pathAmount = 0.5
        XCTAssertLessThan(TextRenderer.fittedSize(half, box: box), size)
    }

    func testWaveReachesAboveAndBelowTheStraightBand() throws {
        let box = CGSize(width: 300, height: 200)
        var straight = content(.none)
        straight.autoFit = false
        straight.fontSize = 0.03
        var wave = straight
        wave.path = .wave
        wave.pathAmount = 1
        let (flat, _) = try XCTUnwrap(TextRenderer.render(straight, box: box, canvasHeight: 1000))
        let (waved, _) = try XCTUnwrap(TextRenderer.render(wave, box: box, canvasHeight: 1000))
        XCTAssertEqual(flat.width, waved.width)
        XCTAssertEqual(flat.height, waved.height)
        let f = inkRows(flat), w = inkRows(waved)
        XCTAssertLessThan(w.top, f.top, "wave rises above the straight band")
        XCTAssertGreaterThan(w.bottom, f.bottom, "wave dips below the straight band")
        // Fitting makes room for the amplitude.
        let fittedWave = TextRenderer.fittedSize(wave, box: box)
        XCTAssertLessThanOrEqual(fittedWave, TextRenderer.fittedSize(straight, box: box))
    }

    func testRiseIsTallerOnTheRight() throws {
        let box = CGSize(width: 300, height: 200)
        let (img, _) = try XCTUnwrap(TextRenderer.render(content(.rise, amount: 1), box: box, canvasHeight: 1000))
        let heights = columnHeights(img)
        let inked = heights.indices.filter { heights[$0] > 0 }
        let first = try XCTUnwrap(inked.first), last = try XCTUnwrap(inked.last)
        let span = max(1, (last - first) / 6)
        let left = heights[first...(first + span)].max() ?? 0
        let right = heights[(last - span)...last].max() ?? 0
        XCTAssertGreaterThan(right, left, "rise: right ink \(right) taller than left ink \(left)")

        let (fallen, _) = try XCTUnwrap(TextRenderer.render(content(.fall, amount: 1), box: box, canvasHeight: 1000))
        let fh = columnHeights(fallen)
        let fi = fh.indices.filter { fh[$0] > 0 }
        let ff = try XCTUnwrap(fi.first), fl = try XCTUnwrap(fi.last)
        let fspan = max(1, (fl - ff) / 6)
        XCTAssertGreaterThan(fh[ff...(ff + fspan)].max() ?? 0, fh[(fl - fspan)...fl].max() ?? 0, "fall is taller on the left")
    }

    func testStraightRenderIsDeterministicAndUnchangedForOldDocuments() throws {
        let box = CGSize(width: 300, height: 200)
        let t = TextContent(text: sample, role: .title, fontName: "Didot")
        XCTAssertEqual(t.path, .none)
        XCTAssertEqual(t.arc, 0)
        let (a, padA) = try XCTUnwrap(TextRenderer.render(t, box: box, canvasHeight: 1000))
        let (b, padB) = try XCTUnwrap(TextRenderer.render(t, box: box, canvasHeight: 1000))
        XCTAssertEqual(padA, padB)
        XCTAssertEqual(alpha(a).data, alpha(b).data, "the straight renderer is deterministic")

        // A document saved before paths existed has no path keys at all.
        let data = try JSONEncoder().encode(t)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["path"])
        json["path"] = nil
        json["pathAmount"] = nil
        json["pathPhase"] = nil
        let old = try JSONDecoder().decode(TextContent.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.path, .none)
        XCTAssertEqual(old.pathAmount, 0.5)
        XCTAssertEqual(old.pathPhase, 0)
        XCTAssertEqual(old, t)
        let (c, padC) = try XCTUnwrap(TextRenderer.render(old, box: box, canvasHeight: 1000))
        XCTAssertEqual(padA, padC)
        XCTAssertEqual(alpha(a).data, alpha(c).data, "an old document renders pixel for pixel as before")
        XCTAssertEqual(TextRenderer.fittedSize(old, box: box), TextRenderer.fittedSize(t, box: box))
    }

    func testPathFieldsRoundTripThroughJSON() throws {
        var t = content(.flag, amount: 0.7)
        t.pathPhase = 0.25
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(TextContent.self, from: data)
        XCTAssertEqual(back, t)
        XCTAssertEqual(back.path, .flag)
        XCTAssertEqual(back.pathAmount, 0.7)
        XCTAssertEqual(back.pathPhase, 0.25)
        for p in TextPath.allCases {
            XCTAssertEqual(try JSONDecoder().decode(TextPath.self, from: try JSONEncoder().encode(p)), p)
            XCTAssertFalse(p.label.isEmpty)
        }
        XCTAssertEqual(TextPath.allCases.count, 9)
    }
}
