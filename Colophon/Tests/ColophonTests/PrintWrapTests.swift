import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

/// ISBN handling, EAN-13 / EAN-5 encoding, spine and wrap geometry, back layouts, PDF export and print checks.
final class PrintWrapTests: XCTestCase {
    private func doc(binding: PrintSettings.Binding = .paperback, layout: PrintSettings.BackLayout = .classic) -> CoverDocument {
        var d = CoverDocument()
        d.canvas = CanvasSpec(width: 100, height: 160)
        d.book.title = "The Salt Orchard"
        d.book.author = "Ines Valcourt"
        d.book.blurb = "A quiet town, a drowned orchard, and the one woman who remembers why the water rose. Ines Valcourt's debut is a slow-burning story of grief and salt."
        let ground = RGBA(hex: "1A2B4C")
        d.background = ground
        d.palette = [ground, RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
        d.layers = [Layer.fill(.solid, colors: [ground], frame: .full)]
        d.paperback.trimWidth = 5
        d.paperback.trimHeight = 8
        d.paperback.pageCount = 200
        d.paperback.binding = binding
        d.paperback.backLayout = layout
        d.paperback.quote = "\"Luminous and unsettling.\" A reviewer"
        d.paperback.authorBio = "Ines Valcourt grew up on the Gironde estuary and now lives in Lisbon."
        d.paperback.publisher = "Tidewater Press"
        d.paperback.category = "FICTION / LITERARY"
        d.paperback.isbn = "0-306-40615-2"
        d.paperback.priceCode = "51499"
        return d
    }

    // MARK: ISBN

    func testISBN10ConvertsTo13() {
        XCTAssertEqual(Barcode.isbn13(from: "0-306-40615-2"), "9780306406157")
        XCTAssertEqual(Barcode.isbn13(from: "978 0 306 40615 7"), "9780306406157")
        XCTAssertEqual(Barcode.isbn13(from: "9780306406157"), "9780306406157")
        XCTAssertEqual(Barcode.formatted("9780306406157", hint: "0-306-40615-2"), "978-0-306-40615-7")
    }

    func testWrongCheckDigitIsRejected() {
        XCTAssertNil(Barcode.isbn13(from: "0-306-40615-3"))
        XCTAssertNil(Barcode.isbn13(from: "9780306406158"))
        XCTAssertNil(Barcode.isbn13(from: "12345"))
        XCTAssertNil(Barcode.isbn13(from: ""))
    }

    // MARK: Patterns

    func testEAN13PatternStructure() {
        let p = Barcode.ean13Pattern("9780306406157")
        XCTAssertEqual(p.count, 95)
        // Guard bars: start 101, center 01010, end 101.
        XCTAssertEqual(Array(p[0..<3]), [true, false, true])
        XCTAssertEqual(Array(p[45..<50]), [false, true, false, true, false])
        XCTAssertEqual(Array(p[92..<95]), [true, false, true])
        // First digit 9 selects parity LGGLGL for the left six digits (7,8,0,3,0,6).
        func bits(_ s: String) -> [Bool] { s.map { $0 == "1" } }
        XCTAssertEqual(Array(p[3..<10]), bits("0111011"))     // 7 in L
        XCTAssertEqual(Array(p[10..<17]), bits("0001001"))    // 8 in G
        XCTAssertEqual(Array(p[17..<24]), bits("0100111"))    // 0 in G
        XCTAssertEqual(Array(p[24..<31]), bits("0111101"))    // 3 in L
        XCTAssertEqual(Array(p[31..<38]), bits("0100111"))    // 0 in G
        XCTAssertEqual(Array(p[38..<45]), bits("0101111"))    // 6 in L
        // Right half is all R codes: 4,0,6,1,5,7.
        XCTAssertEqual(Array(p[50..<57]), bits("1011100"))    // 4 in R
        XCTAssertEqual(Array(p[85..<92]), bits("1000100"))    // 7 in R
        // Every digit code has an odd count of bars on the left and even on the right... not required by
        // the spec, but each 7-module code must start with a space and end with a bar (L/G) or vice versa (R).
        for i in 0..<6 {
            XCTAssertFalse(p[3 + 7 * i]); XCTAssertTrue(p[3 + 7 * i + 6])
            XCTAssertTrue(p[50 + 7 * i]); XCTAssertFalse(p[50 + 7 * i + 6])
        }
        XCTAssertEqual(Barcode.ean13Pattern("123").count, 0)
    }

    func testAddOnPattern() {
        let p = Barcode.addOnPattern("51499")
        XCTAssertEqual(p.count, 47)
        XCTAssertEqual(Array(p[0..<4]), [true, false, true, true])
        // Separators 01 between the five digit codes.
        for k in 1..<5 {
            let sep = 4 + 7 * k + 2 * (k - 1)
            XCTAssertFalse(p[sep]); XCTAssertTrue(p[sep + 1])
        }
        XCTAssertEqual(Barcode.addOnPattern("1234").count, 0)
        XCTAssertTrue(Barcode.isValidAddOn("90000"))
        XCTAssertFalse(Barcode.isValidAddOn("9000"))
    }

    // MARK: Geometry

    func testSpineWidth() {
        let kdp = PrintSettings.spineWidth(pages: 300, paper: .cream, printer: .kdp, binding: .paperback)
        XCTAssertEqual(kdp, 0.75, accuracy: 0.0001)
        let ingram = PrintSettings.spineWidth(pages: 300, paper: .cream, printer: .ingramSpark, binding: .paperback)
        XCTAssertEqual(ingram, 300.0 / 426.0, accuracy: 0.0001)
        XCTAssertNotEqual(kdp, ingram, accuracy: 0.001)
        let hard = PrintSettings.spineWidth(pages: 300, paper: .cream, printer: .kdp, binding: .hardcover)
        XCTAssertEqual(hard, 0.875, accuracy: 0.0001)
    }

    func testHardcoverWrapGeometry() {
        var s = PrintSettings()
        s.trimWidth = 6; s.trimHeight = 9; s.pageCount = 300; s.paper = .cream
        let paperbackWidth = s.fullWidth
        XCTAssertEqual(s.wrapMargin, 0)
        XCTAssertEqual(paperbackWidth, 12 + 0.75 + 0.25, accuracy: 0.0001)
        s.binding = .hardcover
        XCTAssertEqual(s.wrapMargin, 0.75)
        XCTAssertEqual(s.panelWidth, 6.125, accuracy: 0.0001)
        XCTAssertEqual(s.fullWidth, 2 * 6.125 + 0.875 + 1.5, accuracy: 0.0001)
        XCTAssertEqual(s.fullHeight, 9.25 + 1.5, accuracy: 0.0001)
        XCTAssertGreaterThan(s.fullWidth, paperbackWidth + 1)
        let g = PrintWrap.Geometry(settings: s, dpi: 72)
        XCTAssertEqual(g.hingeLines.count, 2)
        XCTAssertEqual(g.hingeLines[0], g.spineRect.minX - 36)
        XCTAssertEqual(g.trimRect.minX, 54)
    }

    func testSettingsDecodeWithDefaults() throws {
        let json = #"{"trimWidth":5.5,"trimHeight":8.5,"pageCount":120,"paper":"white","blurb":"","quote":"","keepBarcodeArea":true}"#
        let s = try JSONDecoder().decode(PrintSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.pageCount, 120)
        XCTAssertEqual(s.printer, .kdp)
        XCTAssertEqual(s.binding, .paperback)
        XCTAssertEqual(s.backLayout, .classic)
        XCTAssertTrue(s.cmykExport)
        XCTAssertEqual(s.isbn, "")
        let round = try JSONDecoder().decode(PrintSettings.self, from: JSONEncoder().encode(doc(binding: .hardcover).paperback))
        XCTAssertEqual(round.binding, .hardcover)
        XCTAssertEqual(round.isbn, "0-306-40615-2")
    }

    // MARK: Rendering

    func testRenderMatchesGeometryForEveryLayoutAndBinding() {
        for binding in PrintSettings.Binding.allCases {
            for layout in PrintSettings.BackLayout.allCases {
                let d = doc(binding: binding, layout: layout)
                let g = PrintWrap.Geometry(settings: d.paperback, dpi: 36)
                let img = PrintWrap.render(d, dpi: 36, guides: true)
                XCTAssertNotNil(img, "\(binding) \(layout)")
                XCTAssertEqual(img?.width, Int(g.size.width), "\(binding) \(layout)")
                XCTAssertEqual(img?.height, Int(g.size.height), "\(binding) \(layout)")
            }
        }
    }

    func testBarcodeDrawsIntoContext() throws {
        let ctx = try XCTUnwrap(Gfx.context(240, 120))
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 240, height: 120))
        Barcode.draw(isbn13: "9780306406157", addOn: "51499", in: CGRect(x: 10, y: 10, width: 220, height: 100), ctx: ctx, dpi: 100)
        let img = try XCTUnwrap(ctx.makeImage())
        let p = PixelSampler.pixels(img, maxSide: 400)
        var black = 0, white = 0
        for i in stride(from: 0, to: p.data.count, by: 4) {
            if p.data[i] < 40 { black += 1 } else if p.data[i] > 240 { white += 1 }
        }
        XCTAssertGreaterThan(black, 500)
        XCTAssertGreaterThan(white, 5000)
    }

    // MARK: Export

    func testExportPDFWritesFileWithAndWithoutCMYK() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PrintWrapTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for cmyk in [true, false] {
            var d = doc()
            d.paperback.cmykExport = cmyk
            let url = dir.appendingPathComponent("wrap-\(cmyk).pdf")
            XCTAssertTrue(PrintWrap.exportPDF(d, to: url, dpi: 72), "cmyk \(cmyk)")
            let size = try XCTUnwrap((try FileManager.default.attributesOfItem(atPath: url.path))[.size] as? Int)
            XCTAssertGreaterThan(size, 10_000, "cmyk \(cmyk)")
            let data = try Data(contentsOf: url)
            XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "%PDF")
        }
        let png = dir.appendingPathComponent("wrap.png")
        XCTAssertTrue(PrintWrap.exportPNG(doc(), to: png, dpi: 36))
        XCTAssertTrue(FileManager.default.fileExists(atPath: png.path))
    }

    func testCMYKConversion() throws {
        let ctx = try XCTUnwrap(Gfx.context(8, 8))
        ctx.setFillColor(RGBA(hex: "E8562A").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let rgb = try XCTUnwrap(ctx.makeImage())
        let cmyk = try XCTUnwrap(PrintWrap.cmykImage(rgb))
        XCTAssertEqual(cmyk.colorSpace?.model, .cmyk)
        XCTAssertEqual(cmyk.bitsPerPixel, 32)
        XCTAssertEqual(cmyk.alphaInfo, CGImageAlphaInfo.none)
    }

    // MARK: Checks

    func testPrintChecksFlagISBN() {
        var d = doc()
        d.paperback.isbn = "9780306406158"
        let bad = PrintWrap.printChecks(d)
        XCTAssertTrue(bad.contains { $0.contains("ISBN isn't valid") }, bad.joined(separator: "\n"))

        d.paperback.isbn = "978-0-306-40615-7"
        let good = PrintWrap.printChecks(d)
        XCTAssertFalse(good.contains { $0.contains("ISBN") }, good.joined(separator: "\n"))

        d.paperback.binding = .hardcover
        XCTAssertTrue(PrintWrap.printChecks(d).contains { $0.contains("approximation") })

        d.paperback.isbn = ""
        d.paperback.category = ""
        let info = PrintWrap.printChecks(d)
        XCTAssertTrue(info.contains { $0.hasPrefix("No ISBN") })
        XCTAssertTrue(info.contains { $0.contains("category") })
    }

    func testBlurbFitWarnsOnLongCopy() {
        var d = doc()
        XCTAssertTrue(PrintWrap.blurbFits(d))
        d.paperback.blurb = String(repeating: "A long sentence that keeps going about the drowned orchard and its many secrets. ", count: 60)
        XCTAssertFalse(PrintWrap.blurbFits(d))
        XCTAssertTrue(PrintWrap.printChecks(d).contains { $0.contains("doesn't fit") })
    }
}
