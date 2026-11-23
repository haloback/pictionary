import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

final class UpscalerTests: XCTestCase {
    // MARK: Constants

    func testConstants() {
        XCTAssertEqual(Upscaler.scale, 4)
        XCTAssertEqual(Upscaler.tile, 256)
        XCTAssertEqual(Upscaler.overlap, 16)
        XCTAssertEqual(Upscaler.maxInputSide * Upscaler.scale, 6400)
    }

    // MARK: Weights

    func testStitchWeightsRampThenFlat() {
        let w = Upscaler.stitchWeights(tileSize: 1024, overlap: 64)
        XCTAssertEqual(w.count, 1024)
        // Starts near zero, never exactly zero, and reaches 1 right after the overlap.
        XCTAssertGreaterThan(w[0], 0)
        XCTAssertLessThan(w[0], 0.05)
        XCTAssertLessThan(w[63], 1)
        XCTAssertEqual(w[64], 1)
        XCTAssertEqual(w[512], 1)
        XCTAssertEqual(w[1024 - 65], 1)
        // Monotonic over the ramp and symmetric at both ends.
        for i in 1..<64 {
            XCTAssertGreaterThan(w[i], w[i - 1])
            XCTAssertEqual(w[i], w[1023 - i], accuracy: 1e-6)
        }
    }

    func testStitchWeightsWithNoOverlapIsAllOnes() {
        let w = Upscaler.stitchWeights(tileSize: 8, overlap: 0)
        XCTAssertEqual(w, Array(repeating: Float(1), count: 8))
    }

    // MARK: Tiling

    func testTileOriginsCoverAndOverlap() {
        let tile = Upscaler.tile, overlap = Upscaler.overlap
        for length in [100, 256, 257, 500, 600, 1000, 1600] {
            let xs = Upscaler.tileOrigins(length: length)
            XCTAssertEqual(xs.first, 0, "length \(length)")
            if length <= tile {
                XCTAssertEqual(xs, [0])
                continue
            }
            // Last tile ends exactly on the edge; count matches the stride formula.
            XCTAssertEqual(xs.last, length - tile, "length \(length)")
            let stride = tile - overlap
            let expected = Int((Double(length - tile) / Double(stride)).rounded(.up)) + 1
            XCTAssertEqual(xs.count, expected, "length \(length)")
            // Consecutive tiles overlap by at least `overlap`, never more than a whole tile.
            for i in 1..<xs.count {
                let ov = xs[i - 1] + tile - xs[i]
                XCTAssertGreaterThanOrEqual(ov, overlap, "length \(length) tile \(i)")
                XCTAssertLessThan(ov, tile, "length \(length) tile \(i)")
            }
            // Every pixel is covered.
            var covered = Array(repeating: false, count: length)
            for x in xs { for p in x..<(x + tile) where p < length { covered[p] = true } }
            XCTAssertFalse(covered.contains(false), "length \(length)")
        }
    }

    func testTilesForCountsAndOrder() {
        let tiles = Upscaler.tilesFor(width: 600, height: 300)
        XCTAssertEqual(tiles.count, 3 * 2)
        XCTAssertEqual(tiles[0].x, 0); XCTAssertEqual(tiles[0].y, 0)
        XCTAssertEqual(tiles[1].x, 240); XCTAssertEqual(tiles[1].y, 0)
        XCTAssertEqual(tiles[2].x, 344); XCTAssertEqual(tiles[2].y, 0)
        XCTAssertEqual(tiles[3].x, 0); XCTAssertEqual(tiles[3].y, 44)
        XCTAssertEqual(Upscaler.tilesFor(width: 100, height: 100).count, 1)
        XCTAssertEqual(Upscaler.tilesFor(width: 1600, height: 1600).count, 7 * 7)
    }

    // MARK: Stitching

    /// CHW float pixels of a `side` x `side` tile cut from a `w` x `h` RGB float picture at (`x`, `y`), clamped at the edges.
    private func cut(from picture: [Float], w: Int, h: Int, x: Int, y: Int, side: Int) -> [Float] {
        var out = Array(repeating: Float(0), count: 3 * side * side)
        for c in 0..<3 {
            for ty in 0..<side {
                let sy = min(h - 1, y + ty)
                for tx in 0..<side {
                    let sx = min(w - 1, x + tx)
                    out[c * side * side + ty * side + tx] = picture[(sy * w + sx) * 3 + c]
                }
            }
        }
        return out
    }

    private func stitched(picture: [Float], w: Int, h: Int, tile: Int, overlap: Int) -> [UInt8] {
        var tiles: [(x: Int, y: Int, pixels: [Float])] = []
        for y in Upscaler.tileOrigins(length: h, tileSize: tile, overlap: overlap) {
            for x in Upscaler.tileOrigins(length: w, tileSize: tile, overlap: overlap) {
                tiles.append((x: x, y: y, pixels: cut(from: picture, w: w, h: h, x: x, y: y, side: tile)))
            }
        }
        return Upscaler.stitch(tileOutputs: tiles, tileOut: tile, overlapOut: overlap, outW: w, outH: h)
    }

    func testStitchReconstructsFlatColorExactly() {
        let w = 150, h = 90
        var picture = Array(repeating: Float(0), count: w * h * 3)
        for i in 0..<(w * h) {
            picture[i * 3] = 0.2
            picture[i * 3 + 1] = 0.6
            picture[i * 3 + 2] = 0.8
        }
        let out = stitched(picture: picture, w: w, h: h, tile: 64, overlap: 16)
        XCTAssertEqual(out.count, w * h * 4)
        let r = UInt8((Float(0.2) * 255).rounded()), g = UInt8((Float(0.6) * 255).rounded()), b = UInt8((Float(0.8) * 255).rounded())
        for i in 0..<(w * h) {
            XCTAssertEqual(out[i * 4], r)
            XCTAssertEqual(out[i * 4 + 1], g)
            XCTAssertEqual(out[i * 4 + 2], b)
            XCTAssertEqual(out[i * 4 + 3], 255)
        }
    }

    func testStitchReconstructsGradientWithinTwoLevels() {
        let w = 200, h = 70
        var picture = Array(repeating: Float(0), count: w * h * 3)
        for y in 0..<h {
            for x in 0..<w {
                let v = Float(x) / Float(w - 1)
                let i = (y * w + x) * 3
                picture[i] = v
                picture[i + 1] = 1 - v
                picture[i + 2] = 0.5
            }
        }
        let out = stitched(picture: picture, w: w, h: h, tile: 64, overlap: 16)
        var worst = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                for c in 0..<3 {
                    let want = Int((picture[i * 3 + c] * 255).rounded())
                    worst = max(worst, abs(Int(out[i * 4 + c]) - want))
                }
            }
        }
        XCTAssertLessThanOrEqual(worst, 2)
    }

    func testStitchCropsTilesThatOverhang() {
        // One 64-px tile placed on a 40 x 30 output: only the visible part is written, nothing crashes.
        let tile = Array(repeating: Float(1), count: 3 * 64 * 64)
        let out = Upscaler.stitch(tileOutputs: [(x: 0, y: 0, pixels: tile)], tileOut: 64, overlapOut: 16, outW: 40, outH: 30)
        XCTAssertEqual(out.count, 40 * 30 * 4)
        XCTAssertEqual(out[0], 255)
        XCTAssertEqual(out[(29 * 40 + 39) * 4 + 2], 255)
    }

    // MARK: Pixels

    func testBGRAPixelsCapsLongSide() {
        let ctx = CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: Gfx.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        let img = ctx.makeImage()!
        let p = Upscaler.bgraPixels(img, maxSide: 100)!
        XCTAssertEqual(p.width, 100)
        XCTAssertEqual(p.height, 50)
        XCTAssertEqual(p.pixels.count, 100 * 50 * 4)
        // BGRA order: red lands in the third byte.
        XCTAssertEqual(p.pixels[2], 255)
        XCTAssertEqual(p.pixels[0], 0)
        let full = Upscaler.bgraPixels(img, maxSide: 1600)!
        XCTAssertEqual(full.width, 400)
    }

    func testImageFromRGBARoundTrips() {
        let w = 8, h = 4
        var rgba = Array(repeating: UInt8(0), count: w * h * 4)
        for i in 0..<(w * h) { rgba[i * 4] = 10; rgba[i * 4 + 1] = 200; rgba[i * 4 + 2] = 30; rgba[i * 4 + 3] = 255 }
        let img = Upscaler.image(fromRGBA: rgba, width: w, height: h)
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.width, w)
        XCTAssertEqual(img?.height, h)
        XCTAssertEqual(img?.alphaInfo, .noneSkipLast)
        XCTAssertNotNil(AssetStore.encode(img!, quality: 0.95))
    }

    // MARK: Status without the model

    func testNotReadyWithoutModelOnDisk() {
        let u = Upscaler.shared
        let installed = FileManager.default.fileExists(atPath: u.modelsDirectory.appendingPathComponent(Upscaler.compiledName).path)
        guard !installed else { return }
        XCTAssertFalse(u.isReady)
        XCTAssertEqual(u.status, .notInstalled)
        let ctx = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                            space: Gfx.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let img = ctx.makeImage()!
        var calls = 0
        XCTAssertNil(u.upscale(img, progress: { _ in calls += 1 }))
        XCTAssertEqual(calls, 0)
    }

    func testNotPublishedErrorMessage() {
        XCTAssertTrue(UpscalerError.notPublished.localizedDescription.contains("not published yet"))
        XCTAssertTrue(Upscaler.message(for: UpscalerError.notPublished).contains("not published yet"))
    }
}
