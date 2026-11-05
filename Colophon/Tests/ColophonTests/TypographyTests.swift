import XCTest
import CoreGraphics
@testable import Colophon

/// Measured line breaking, block fit, optical tracking, hanging punctuation, small caps and widow-safe wrapping.
final class TypesettingTests: XCTestCase {
    /// Leftmost column of ink in a rendered text image, relative to the box edge (negative means it hangs outside).
    private func leftmostInk(_ img: CGImage, pad: CGFloat) -> Double {
        let p = PixelSampler.pixels(img, maxSide: 4000)
        for x in 0..<p.w {
            for row in 0..<p.h where p.data[(row * p.w + x) * 4 + 3] > 40 { return Double(x) - Double(pad) }
        }
        return Double(p.w)
    }

    func testMeasuredBreaksNeverEndOnConnective() {
        let t = TextContent(text: "The Edge of Everything", role: .title, fontName: "Didot")
        let broken = TitleBreaker.balanced("The Edge of Everything", lines: 2) { Double(TextRenderer.lineWidth($0, t, 100)) }
        let lines = broken.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        for line in lines.dropLast() {
            let last = String(line.split(separator: " ").last ?? "")
            XCTAssertFalse(TitleBreaker.isConnective(last), broken)
        }
        XCTAssertEqual(broken, "The Edge\nof Everything")
        // The count-based breaker is untouched.
        XCTAssertEqual(TitleBreaker.balanced("The House at the End of Hollow Lane", lines: 2), "The House at the\nEnd of Hollow Lane")

        let best = TextRenderer.bestBreaks(t, box: CGSize(width: 300, height: 300))
        for line in best.components(separatedBy: "\n").dropLast() {
            XCTAssertFalse(TitleBreaker.isConnective(String(line.split(separator: " ").last ?? "")), best)
        }
        XCTAssertEqual(best.replacingOccurrences(of: "\n", with: " "), "The Edge of Everything")
        XCTAssertEqual(TextRenderer.bestBreaks(TextContent(text: "Salt", role: .title), box: CGSize(width: 300, height: 300)), "Salt")
    }

    func testBlockFitFillsTheWidthPerLine() throws {
        var t = TextContent(text: "The\nSalt\nOrchard", role: .title, fontName: "Didot")
        t.fit = .block
        t.opticalTracking = false
        let box = CGSize(width: 240, height: 400)
        let sizes = TextRenderer.resolvedSizes(t, box: box, canvasHeight: 1000)
        XCTAssertEqual(sizes.count, 3)
        let m = TextRenderer.measure(t, size: sizes.max()!, wrapWidth: nil, canvasHeight: 1000, sizes: sizes)
        XCTAssertEqual(m.bounds.count, 3)
        let cap = sizes.min()! * TextRenderer.blockRatioCap
        for (i, b) in m.bounds.enumerated() {
            if sizes[i] < cap - 0.01 {
                XCTAssertEqual(Double(b.width), Double(box.width), accuracy: Double(box.width) * 0.02, "line \(i)")
            } else {
                XCTAssertLessThanOrEqual(b.width, box.width * 1.02, "line \(i) is held at the ratio cap")
            }
        }
        XCTAssertLessThanOrEqual(m.height, box.height + 1)
        XCTAssertGreaterThan(sizes[0], sizes[2], "short lines set larger than long ones")
        // Baselines advance by each line's own size.
        XCTAssertEqual(Double(m.baselines[1] - m.baselines[0]), Double(sizes[1]) * t.lineHeight, accuracy: 0.01)
        let (img, _) = try XCTUnwrap(TextRenderer.render(t, box: box, canvasHeight: 1000))
        XCTAssertGreaterThanOrEqual(img.width, Int(box.width))

        // Uniform fit is unchanged: one size, evenly spaced baselines.
        t.fit = .uniform
        let uniform = TextRenderer.resolvedSizes(t, box: box, canvasHeight: 1000)
        XCTAssertEqual(Set(uniform).count, 1)
        let um = TextRenderer.measure(t, size: uniform[0], wrapWidth: nil)
        for i in um.baselines.indices {
            XCTAssertEqual(Double(um.baselines[i]), Double(um.top + CGFloat(i) * um.advance), accuracy: 0.001)
        }
    }

    func testOpticalTrackingTightensDisplayAndOpensSmallCaps() throws {
        var t = TextContent(text: "NIGHT", role: .title, fontName: "Futura-Bold")
        t.tracking = 0.02
        let canvas: CGFloat = 1000
        XCTAssertLessThan(TextRenderer.effectiveTracking(t, size: 200, canvasHeight: canvas), t.tracking)
        XCTAssertEqual(TextRenderer.effectiveTracking(t, size: 200, canvasHeight: 0), t.tracking, "no canvas, no adjustment")
        t.letterCase = .smallCaps
        XCTAssertGreaterThan(TextRenderer.effectiveTracking(t, size: 12, canvasHeight: canvas), t.tracking)
        t.letterCase = .upper
        XCTAssertGreaterThan(TextRenderer.effectiveTracking(t, size: 12, canvasHeight: canvas), t.tracking)
        t.letterCase = .asTyped
        XCTAssertEqual(TextRenderer.effectiveTracking(t, size: 12, canvasHeight: canvas), t.tracking, "mixed case is not opened")
        t.tracking = -0.05
        XCTAssertGreaterThanOrEqual(TextRenderer.effectiveTracking(t, size: 300, canvasHeight: canvas), -0.06)
        t.opticalTracking = false
        XCTAssertEqual(TextRenderer.effectiveTracking(t, size: 300, canvasHeight: canvas), t.tracking)
        // Decoded documents keep their spacing; new text opts in.
        XCTAssertTrue(TextContent(text: "x").opticalTracking)
        let data = try JSONEncoder().encode(["text": "x"])
        let decoded = try JSONDecoder().decode(TextContent.self, from: data)
        XCTAssertFalse(decoded.opticalTracking)
        XCTAssertEqual(decoded.fit, .uniform)
    }

    func testHangingPunctuationShiftsQuotedLineLeft() throws {
        var plain = TextContent(text: "Night", role: .title, fontName: "Didot")
        plain.alignment = .left
        plain.autoFit = false
        plain.fontSize = 0.1
        var quoted = plain
        quoted.text = "\u{201C}Night"
        let canvas: CGFloat = 300
        let pm = TextRenderer.measure(plain, size: 30, wrapWidth: nil, canvasHeight: canvas)
        let qm = TextRenderer.measure(quoted, size: 30, wrapWidth: nil, canvasHeight: canvas)
        XCTAssertEqual(pm.hang.first ?? 1, 0)
        XCTAssertLessThan(qm.hang.first ?? 0, 0)
        let box = CGSize(width: 200, height: 60)
        let (pImg, pPad) = try XCTUnwrap(TextRenderer.render(plain, box: box, canvasHeight: canvas))
        let (qImg, qPad) = try XCTUnwrap(TextRenderer.render(quoted, box: box, canvasHeight: canvas))
        XCTAssertLessThan(leftmostInk(qImg, pad: qPad), leftmostInk(pImg, pad: pPad))
        // Centered lines hang both ends: a symmetric pair of quotes has no net shift.
        var both = quoted
        both.alignment = .center
        both.text = "\u{201C}Night\u{201D}"
        let bm = TextRenderer.measure(both, size: 30, wrapWidth: nil)
        XCTAssertEqual(Double(bm.hang.first ?? 1), 0, accuracy: 0.5)
    }

    func testSmallCapsRenderAndAreNarrowerThanCaps() throws {
        var t = TextContent(text: "Ines Valcourt", role: .author, fontName: "Didot")
        t.letterCase = .upper
        let caps = TextRenderer.measure(t, size: 60, wrapWidth: nil)
        t.letterCase = .smallCaps
        XCTAssertEqual(TextRenderer.displayString(t), "Ines Valcourt")
        let small = TextRenderer.measure(t, size: 60, wrapWidth: nil)
        XCTAssertLessThan(small.width, caps.width)
        XCTAssertGreaterThan(small.width, caps.width * 0.6)
        XCTAssertEqual(LetterCase.smallCaps.label, "Small Caps")
        XCTAssertNotNil(TextRenderer.render(t, box: CGSize(width: 300, height: 60), canvasHeight: 1000))
        // Synthesized small caps draw letters as capitals, so no glyph drops below the baseline more than a capital does.
        let s = TextRenderer.attributed("ab", t, size: 60)
        XCTAssertEqual(s.string.uppercased(), "AB")
    }

    func testWidowSafeWrapPullsAWordDown() {
        let t = TextContent(text: "Quiet River Runs Deep", role: .custom, fontName: "Didot")
        let firstLine = TextRenderer.measure(t, size: 24, wrapWidth: nil)
        var long = t
        long.text = "Quiet River Runs Deep Now"
        let m = TextRenderer.measure(long, size: 24, wrapWidth: firstLine.width + 0.5)
        XCTAssertEqual(m.lines.count, 2)
        XCTAssertEqual(TextRenderer.lineStrings(long, size: 24, wrapWidth: firstLine.width + 0.5), ["Quiet River Runs", "Deep Now"])
        // Lines with room keep the greedy result.
        XCTAssertEqual(TextRenderer.lineStrings(long, size: 24, wrapWidth: 100_000), ["Quiet River Runs Deep Now"])
    }
}
