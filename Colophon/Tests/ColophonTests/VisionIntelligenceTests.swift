import CoreGraphics
import CoreText
import Foundation
import Vision
import XCTest
@testable import Colophon

final class VisionIntelligenceTests: XCTestCase {
    /// 300x400 white with big black "HELLO" (Helvetica Bold 72) across the vertical middle.
    private func helloImage() throws -> CGImage {
        let w = 300, h = 400
        let ctx = try XCTUnwrap(Gfx.context(w, h))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 72, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "HELLO", attributes: attrs))
        let bounds = CTLineGetBoundsWithOptions(line, [])
        // Bottom-left context: baseline at y = 180 puts the caps roughly in top-left y 0.42...0.55.
        ctx.textPosition = CGPoint(x: (CGFloat(w) - bounds.width) / 2, y: 180)
        CTLineDraw(line, ctx)
        return try XCTUnwrap(ctx.makeImage())
    }

    /// A smooth colored gradient with no text: very different from `helloImage`.
    private func gradientImage() throws -> CGImage {
        let w = 300, h = 400
        let ctx = try XCTUnwrap(Gfx.context(w, h))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: w, height: h), [RGBA(hex: "13404A"), RGBA(hex: "F2A541"), RGBA(hex: "D7263D")], angle: 30)
        ctx.setFillColor(RGBA(hex: "0B1026").cgColor)
        ctx.fillEllipse(in: CGRect(x: 40, y: 60, width: 160, height: 220))
        return try XCTUnwrap(ctx.makeImage())
    }

    // MARK: Vision

    func testTextRegionsFindPrintedWord() throws {
        let img = try helloImage()
        let rects = VisionIntelligence.textRegions(img)
        XCTAssertFalse(rects.isEmpty, "Vision OCR must find big printed Helvetica")
        // The word sits across the middle of the picture, well inside the frame.
        let band = NRect(0.02, 0.25, 0.96, 0.5)
        let hit = rects.first { $0.intersectionArea(band) > $0.area * 0.5 }
        XCTAssertNotNil(hit, "expected a text rect in the middle band, got \(rects)")
        if let hit {
            XCTAssertGreaterThan(hit.w, 0.3)
            XCTAssertLessThan(hit.h, 0.4)
            XCTAssertGreaterThanOrEqual(hit.x, 0)
            XCTAssertLessThanOrEqual(hit.maxY, 1)
        }
    }

    func testTextRegionsEmptyOnPlainGradient() throws {
        let img = try gradientImage()
        XCTAssertTrue(VisionIntelligence.textRegions(img).isEmpty)
    }

    func testAestheticsScoreAvailable() throws {
        guard #available(macOS 15, *) else { throw XCTSkip("Aesthetics scoring needs macOS 15") }
        let img = try gradientImage()
        let a = try XCTUnwrap(VisionIntelligence.aesthetics(img))
        XCTAssertGreaterThanOrEqual(a.score, -1)
        XCTAssertLessThanOrEqual(a.score, 1)
        XCTAssertTrue(a.isUtility == true || a.isUtility == false)
    }

    func testFeaturePrintDistances() throws {
        let helloImg = try helloImage()
        let otherImg = try gradientImage()
        let hello = try XCTUnwrap(VisionIntelligence.featurePrint(helloImg))
        let helloAgain = try XCTUnwrap(VisionIntelligence.featurePrint(helloImg))
        let other = try XCTUnwrap(VisionIntelligence.featurePrint(otherImg))
        let same = try XCTUnwrap(VisionIntelligence.distance(hello, helloAgain))
        let diff = try XCTUnwrap(VisionIntelligence.distance(hello, other))
        XCTAssertLessThan(same, 0.05)
        XCTAssertGreaterThan(diff, 0)
        XCTAssertGreaterThan(diff, same)
    }

    func testClassifyRuns() throws {
        let img = try gradientImage()
        let labels = VisionIntelligence.classify(img, limit: 5)
        XCTAssertLessThanOrEqual(labels.count, 5)
        for l in labels {
            XCTAssertFalse(l.label.isEmpty)
            XCTAssertGreaterThanOrEqual(l.confidence, 0.2)
        }
    }

    // MARK: AssetStore and ImageInsight

    func testAssetStoreCachesIntelligence() throws {
        let img = try helloImage()
        let data = try XCTUnwrap(AssetStore.encode(img))
        var doc = CoverDocument()
        let id = doc.addAsset(data)
        let store = AssetStore.shared
        let regions = store.textRegions(id, data: doc.assetData(id))
        XCTAssertFalse(regions.isEmpty)
        XCTAssertEqual(store.textRegions(id, data: nil).count, regions.count, "second call is served from the cache")
        _ = store.labels(id, data: doc.assetData(id))
        _ = store.aesthetics(id, data: doc.assetData(id))
        _ = store.featurePrint(id, data: doc.assetData(id))
        let insight = store.insight(id, data: doc.assetData(id))
        XCTAssertEqual(insight.textRegions.count, regions.count)
        XCTAssertNotNil(insight.photoNote)
        XCTAssertEqual(insight.darkRegions.count, 12, "analyze still fills the grid")
    }

    func testPhotoNotes() {
        var i = ImageInsight()
        XCTAssertNil(i.photoNote)
        i.textRegions = [NRect(0.1, 0.4, 0.8, 0.1)]
        XCTAssertTrue(i.photoNote?.lowercased().contains("words") == true)
        XCTAssertTrue(i.textOverlaps(NRect(0, 0.35, 1, 0.2)))
        XCTAssertFalse(i.textOverlaps(NRect(0, 0.8, 1, 0.2)))
        i.aesthetic = -0.6
        XCTAssertTrue(i.photoNote?.contains("weak") == true)
        i.isUtility = true
        XCTAssertTrue(i.photoNote?.contains("screenshot") == true)
    }

    // MARK: BriefMood

    func testDarkBriefReadsAsThrillerOrHorror() {
        let mood = BriefMood.analyze(title: "The Blood Orchard", subtitle: "", tagline: "some debts are paid in knives")
        XCTAssertTrue(mood.tags.contains("dark") || mood.tags.contains("tense"), "\(mood.tags)")
        let g = BriefMood.genreHint(for: mood)
        XCTAssertTrue(g == .thriller || g == .horror, "\(String(describing: g))")
        XCTAssertFalse(mood.keywords.isEmpty)
        XCTAssertLessThanOrEqual(mood.tags.count, 5)
        XCTAssertLessThanOrEqual(mood.keywords.count, 12)
    }

    func testCozyBrief() {
        let mood = BriefMood.analyze(title: "Tea and Trouble at Thistledown", subtitle: "", tagline: "")
        XCTAssertTrue(mood.tags.contains("cozy"), "\(mood.tags)")
        XCTAssertEqual(BriefMood.genreHint(for: mood), .cozy)
    }

    func testPalettesForMood() {
        let mood = BriefMood.analyze(title: "Winter on the Ice", subtitle: "", tagline: "a quiet year in the far north")
        XCTAssertTrue(mood.tags.contains("cold"), "\(mood.tags)")
        let pals = BriefMood.palettes(for: mood)
        XCTAssertGreaterThanOrEqual(pals.count, 3)
        XCTAssertEqual(pals.count, TemplateLibrary.palettes.count)
        XCTAssertTrue(["Arctic", "Glacier", "Storm", "Slate Blue", "Ocean Deep"].contains(pals[0].name), pals[0].name)
        XCTAssertNil(BriefMood.genreHint(for: BriefMood.Mood(sentiment: 0, tags: [], keywords: [])))
        XCTAssertGreaterThanOrEqual(BriefMood.palettes(for: BriefMood.Mood(sentiment: 0, tags: [], keywords: [])).count, 3)
    }

    func testLexiconIsBig() {
        XCTAssertGreaterThanOrEqual(BriefMood.lexicon.count, 120)
        for tags in BriefMood.lexicon.values {
            for t in tags { XCTAssertTrue(BriefMood.vocabulary.contains(t), t) }
        }
    }
}
