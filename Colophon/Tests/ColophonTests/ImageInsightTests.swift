import CoreGraphics
import CoreImage
import Foundation
import XCTest
@testable import Colophon

final class ImageInsightTests: XCTestCase {
    /// A light ground with a dark ellipse "head" in the upper half (top-left coordinates: y 0.08...0.45).
    private func headImage() throws -> CGImage {
        let w = 200, h = 300
        let ctx = try XCTUnwrap(Gfx.context(w, h))
        ctx.setFillColor(RGBA(hex: "F2ECDF").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(RGBA(hex: "121417").cgColor)
        // Bottom-left context: top-left y 0.08...0.45 is bottom-left y 0.55...0.92.
        ctx.fillEllipse(in: CGRect(x: 60, y: 165, width: 80, height: 111))
        return try XCTUnwrap(ctx.makeImage())
    }

    private func gradientImage(_ w: Int, _ h: Int) throws -> CGImage {
        let ctx = try XCTUnwrap(Gfx.context(w, h))
        Gfx.linearGradient(ctx, CGRect(x: 0, y: 0, width: w, height: h), [RGBA(hex: "13404A"), RGBA(hex: "F2A541"), RGBA(hex: "F2ECDF")], angle: 60)
        ctx.setFillColor(RGBA(hex: "D7263D").cgColor)
        ctx.fillEllipse(in: CGRect(x: w / 4, y: h / 4, width: w / 2, height: h / 3))
        return try XCTUnwrap(ctx.makeImage())
    }

    // MARK: Insight

    func testInsightFindsQuietBandUnderTheHead() throws {
        let data = try XCTUnwrap(AssetStore.encode(try headImage()))
        var doc = CoverDocument()
        let id = doc.addAsset(data)
        let insight = AssetStore.shared.insight(id, data: doc.assetData(id))

        XCTAssertEqual(insight.darkRegions.count, 12)
        XCTAssertEqual(insight.quietRegions.count, 12)
        XCTAssertGreaterThan(insight.brightness, 0.4)
        XCTAssertGreaterThan(insight.busyness, 0.05)
        // Rows 0 and 1 hold the head's edges; rows 2 and 3 are flat paper.
        XCTAssertGreaterThan(insight.rowBusyness(1), insight.rowBusyness(3))
        XCTAssertEqual(insight.quietestBand(rows: 2), 2)
        XCTAssertEqual(insight.quietestBand(rows: 1), 3)
        XCTAssertLessThan(insight.rowLuminance(1), insight.rowLuminance(3))
        // Light photo wants dark type.
        let roles = PaletteRoles(insight.palette)
        XCTAssertEqual(insight.textColorSuggestion(palette: roles).hex, roles.dark.hex)

        XCTAssertNotNil(AssetStore.shared.imageSize(id, data: doc.assetData(id)))
        let size = try XCTUnwrap(AssetStore.shared.imageSize(id, data: doc.assetData(id)))
        XCTAssertEqual(Double(size.width / size.height), 200.0 / 300.0, accuracy: 0.02)

        let f = insight.smartFocus(frame: NRect(0, 0, 1, 0.5), canvas: CGSize(width: 600, height: 900), imageSize: size, zoom: 1.3)
        XCTAssertTrue((0...1).contains(f.focusX))
        XCTAssertTrue((0...1).contains(f.focusY))
        // The same asset is cached: a second call must agree.
        let again = AssetStore.shared.insight(id, data: doc.assetData(id))
        XCTAssertEqual(again.brightness, insight.brightness)
    }

    func testQuietestBandPicksLowestVariance() {
        var i = ImageInsight()
        // Row 0 busy, row 1 busy, row 2 quiet, row 3 medium.
        i.quietRegions = [0.3, 0.3, 0.3, 0.25, 0.25, 0.25, 0.01, 0.01, 0.01, 0.1, 0.1, 0.1]
        XCTAssertEqual(i.quietestBand(rows: 1), 2)
        XCTAssertEqual(i.quietestBand(rows: 2), 2)
        XCTAssertEqual(i.quietestBand(rows: 4), 0)
        i.quietRegions = Array(repeating: 0, count: 12)
        XCTAssertEqual(i.quietestBand(rows: 2), 2, "ties go to the lower band")
        let band = ImageInsight.bandRect(start: 2, rows: 2)
        XCTAssertEqual(band.y, 0.5, accuracy: 1e-9)
        XCTAssertEqual(band.maxY, 1, accuracy: 1e-9)
    }

    func testSmartFocusKeepsFaceInUpperThird() {
        var i = ImageInsight()
        // A face in the lower-right of a tall photo.
        i.faces = [NRect(0.6, 0.6, 0.15, 0.12)]
        let imageSize = CGSize(width: 1000, height: 1500)
        let frame = NRect(0, 0, 1, 0.5)
        let canvas = CGSize(width: 600, height: 900)
        let f = i.smartFocus(frame: frame, canvas: canvas, imageSize: imageSize, zoom: 1.4)
        var ic = ImageContent(assetID: UUID())
        ic.zoom = 1.4
        ic.focusX = f.focusX
        ic.focusY = f.focusY
        let onCanvas = PhotoGeometry.imageToCanvas(i.faces[0], image: ic, imageSize: imageSize, frame: frame, canvas: canvas)
        // Fully visible inside the frame...
        XCTAssertGreaterThanOrEqual(onCanvas.x, frame.x - 1e-6)
        XCTAssertLessThanOrEqual(onCanvas.maxX, frame.maxX + 1e-6)
        XCTAssertGreaterThanOrEqual(onCanvas.y, frame.y - 1e-6)
        XCTAssertLessThanOrEqual(onCanvas.maxY, frame.maxY + 1e-6)
        // ...and in the upper half of it.
        XCTAssertLessThan(onCanvas.midY, frame.midY)
        // No insight at all: dead center.
        let plain = ImageInsight.empty.smartFocus(frame: frame, canvas: canvas, imageSize: imageSize, zoom: 1)
        XCTAssertEqual(plain.focusX, 0.5, accuracy: 1e-9)
        XCTAssertEqual(plain.focusY, 0.5, accuracy: 1e-9)
    }

    // MARK: Geometry

    func testImageToCanvasRoundTripsWithFocusToShow() {
        let imageSize = CGSize(width: 1000, height: 1500)
        let frame = NRect(0.1, 0.1, 0.8, 0.5)
        let canvas = CGSize(width: 600, height: 900)
        let r = NRect(0.6, 0.2, 0.1, 0.1)
        let f = PhotoGeometry.focusToShow(r, imageSize: imageSize, frame: frame, canvas: canvas, zoom: 1.5)
        var ic = ImageContent(assetID: UUID())
        ic.zoom = 1.5
        ic.focusX = f.focusX
        ic.focusY = f.focusY
        let mapped = PhotoGeometry.imageToCanvas(r, image: ic, imageSize: imageSize, frame: frame, canvas: canvas)
        XCTAssertEqual(mapped.midX, frame.midX, accuracy: 0.02)
        XCTAssertEqual(mapped.midY, frame.midY, accuracy: 0.02)
        XCTAssertGreaterThan(mapped.w, 0)
        XCTAssertGreaterThan(mapped.h, 0)
        // Flipping mirrors the rect about the frame's vertical center line.
        ic.flipped = true
        let flipped = PhotoGeometry.imageToCanvas(r, image: ic, imageSize: imageSize, frame: frame, canvas: canvas)
        XCTAssertEqual(flipped.midX, 2 * frame.midX - mapped.midX, accuracy: 1e-6)
        XCTAssertEqual(flipped.midY, mapped.midY, accuracy: 1e-6)
    }

    func testImageToCanvasAtZoomOneFillsTheFrame() {
        let imageSize = CGSize(width: 800, height: 400)
        let frame = NRect(0, 0, 1, 1)
        let canvas = CGSize(width: 400, height: 400)
        let ic = ImageContent(assetID: UUID())
        // The whole photo, aspect-filled: height matches the frame, width spills evenly either side.
        let whole = PhotoGeometry.imageToCanvas(.full, image: ic, imageSize: imageSize, frame: frame, canvas: canvas)
        XCTAssertEqual(whole.h, 1, accuracy: 1e-9)
        XCTAssertEqual(whole.w, 2, accuracy: 1e-9)
        XCTAssertEqual(whole.x, -0.5, accuracy: 1e-9)
    }

    // MARK: Grades

    func testEveryColorGradeRenders() throws {
        let data = try XCTUnwrap(AssetStore.encode(try gradientImage(120, 160)))
        var doc = CoverDocument()
        let id = doc.addAsset(data)
        var seen = Set<String>()
        XCTAssertGreaterThanOrEqual(ColorGrade.all.count, 24)
        for p in ColorGrade.all {
            XCTAssertTrue(seen.insert(p.id).inserted, "duplicate id \(p.id)")
            XCTAssertFalse(p.adjust.isIdentity, p.name)
            XCTAssertFalse(p.genres.isEmpty, p.name)
            var layer = Layer.image(id)
            layer.adjust = p.adjust
            doc.layers = [layer]
            let img = CoverRenderer.shared.render(doc, size: CGSize(width: 120, height: 192))
            XCTAssertNotNil(img, p.name)
            if let img {
                let s = PixelSampler.stats(img, region: .full)
                XCTAssertGreaterThan(s.mean.r + s.mean.g + s.mean.b, 0.05, "\(p.name) rendered black")
            }
        }
        for g in Genre.allCases {
            XCTAssertEqual(ColorGrade.suggested(for: g).count, ColorGrade.all.count)
            XCTAssertTrue(ColorGrade.suggested(for: g).first!.genres.contains(g), "\(g) has no tagged grade")
        }
    }

    func testAdjustmentFieldsChangePixels() throws {
        let data = try XCTUnwrap(AssetStore.encode(try gradientImage(120, 160)))
        var doc = CoverDocument()
        let id = doc.addAsset(data)
        doc.layers = [Layer.image(id)]
        let plain = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 120, height: 192)))
        let base = PixelSampler.stats(plain, region: .full)

        var lifted = Adjustments()
        lifted.fade = 1
        doc.layers[0].adjust = lifted
        let faded = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 120, height: 192)))
        // Fade lifts the darkest corner.
        let corner = NRect(0, 0, 0.15, 0.15)
        XCTAssertGreaterThan(PixelSampler.stats(faded, region: corner).mean.luminance,
                             PixelSampler.stats(plain, region: corner).mean.luminance)

        var vig = Adjustments()
        vig.vignette = 1
        doc.layers[0].adjust = vig
        let vignetted = try XCTUnwrap(CoverRenderer.shared.render(doc, size: CGSize(width: 120, height: 192)))
        XCTAssertLessThan(PixelSampler.stats(vignetted, region: .full).mean.luminance, base.mean.luminance)

        // Grain on a flat gray shows up as variance where there was none.
        let grayCtx = try XCTUnwrap(Gfx.context(120, 160))
        grayCtx.setFillColor(RGBA(0.5, 0.5, 0.5).cgColor)
        grayCtx.fill(CGRect(x: 0, y: 0, width: 120, height: 160))
        var grayDoc = CoverDocument()
        let grayID = grayDoc.addAsset(try XCTUnwrap(AssetStore.encode(try XCTUnwrap(grayCtx.makeImage()))))
        var grainy = Adjustments()
        grainy.grain = 1
        var grainLayer = Layer.image(grayID)
        grainLayer.adjust = grainy
        grayDoc.layers = [grainLayer]
        let grained = try XCTUnwrap(CoverRenderer.shared.render(grayDoc, size: CGSize(width: 120, height: 192)))
        XCTAssertGreaterThan(PixelSampler.stats(grained, region: .full).busyness, 0.005)
    }

    // MARK: Harmonizer

    func testHarmonizerMakesColorBlendClippedBelow() {
        let photo = Layer.image(UUID(), frame: NRect(0.1, 0.2, 0.8, 0.5))
        let palette = PaletteRoles([RGBA(hex: "1B2A4A"), RGBA(hex: "F2ECDF"), RGBA(hex: "E4572E")])
        let l = Harmonizer.layer(for: photo, palette: palette, strength: 1, mean: RGBA(hex: "C8553D"))
        XCTAssertEqual(l.name, "Harmony")
        XCTAssertEqual(l.blend, .color)
        XCTAssertTrue(l.clipToBelow)
        XCTAssertEqual(l.frame, photo.frame)
        XCTAssertEqual(l.fillContent?.style, .solid)
        XCTAssertEqual(l.fillContent?.colors.count, 1)
        XCTAssertEqual(l.opacity, 0.53, accuracy: 1e-9)
        XCTAssertEqual(Harmonizer.layer(for: photo, palette: palette, strength: 0).opacity, 0.18, accuracy: 1e-9)
        // A warm photo mean is closer to the vermilion accent than to the navy dominant.
        let ink = l.fillContent!.colors[0]
        XCTAssertLessThan(Harmonizer.hueDistance(ink, palette.accent), Harmonizer.hueDistance(ink, palette.dominant))
    }

    func testHueDistanceWraps() {
        XCTAssertEqual(Harmonizer.hueDistance(RGBA(h: 10, s: 1, l: 0.5), RGBA(h: 350, s: 1, l: 0.5)), 20, accuracy: 1)
        XCTAssertEqual(Harmonizer.hueDistance(RGBA(h: 0, s: 1, l: 0.5), RGBA(h: 180, s: 1, l: 0.5)), 180, accuracy: 1)
        XCTAssertEqual(Harmonizer.hueDistance(RGBA(h: 90, s: 1, l: 0.5), RGBA(h: 90, s: 1, l: 0.5)), 0, accuracy: 1e-6)
    }

    // MARK: Codable

    func testAdjustmentsRoundTripAndOldJSONDecodes() throws {
        var a = Adjustments()
        a.lift = 0.2; a.gamma = -0.1; a.gain = 0.3
        a.shadowTint = RGBA(hex: "0E5E6F"); a.highlightTint = RGBA(hex: "F2A541"); a.tintAmount = 0.7
        a.vibrance = 0.4; a.fade = 0.5; a.grain = 0.6; a.vignette = 0.8
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(Adjustments.self, from: data)
        XCTAssertEqual(back, a)
        XCTAssertFalse(back.isIdentity)

        let old = #"{"exposure":0.2,"contrast":0.1,"saturation":0,"warmth":0,"sharpness":0,"blur":0}"#
        let legacy = try JSONDecoder().decode(Adjustments.self, from: Data(old.utf8))
        XCTAssertEqual(legacy.exposure, 0.2)
        XCTAssertEqual(legacy.lift, 0)
        XCTAssertEqual(legacy.tintAmount, 0.5)
        XCTAssertNil(legacy.shadowTint)
        XCTAssertFalse(legacy.isIdentity)
        XCTAssertTrue(try JSONDecoder().decode(Adjustments.self, from: Data("{}".utf8)).isIdentity)
    }
}
