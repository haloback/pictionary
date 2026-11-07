import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

final class PhysicalMockupTests: XCTestCase {
    private func sample() -> CoverDocument {
        var d = CoverDocument()
        d.book = BookInfo(title: "The Salt Orchard", subtitle: "A Novel", author: "Ines Valcourt", tagline: "Some debts are paid in water.", genre: .literary)
        d.palette = [RGBA(hex: "121212"), RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
        d.background = RGBA(hex: "F1EBDD")
        d.layers = [Layer.fill(.solid, colors: [RGBA(hex: "F1EBDD")], frame: .full),
                    Layer.text("The Salt\nOrchard", role: .title, frame: NRect(0.08, 0.12, 0.84, 0.4), font: "PlayfairDisplay-Black", color: RGBA(hex: "121212")),
                    Layer.text("Ines Valcourt", role: .author, frame: NRect(0.15, 0.85, 0.7, 0.04), font: "Montserrat-Black", color: RGBA(hex: "121212"))]
        d.paperback.pageCount = 320
        d.paperback.blurb = "A quiet orchard, a debt that was never written down, and the summer the water stopped coming."
        return d
    }

    /// Largest channel spread across the image: zero for a single flat color.
    private func spread(_ img: CGImage) -> Int {
        let p = PixelSampler.pixels(img, maxSide: 96)
        var lo = [255, 255, 255], hi = [0, 0, 0]
        var i = 0
        while i + 3 < p.data.count {
            for c in 0..<3 {
                lo[c] = min(lo[c], Int(p.data[i + c]))
                hi[c] = max(hi[c], Int(p.data[i + c]))
            }
            i += 4
        }
        return (0..<3).map { hi[$0] - lo[$0] }.max() ?? 0
    }

    func testWrapPartsAreTrimSpineTrim() throws {
        let doc = sample()
        let dpi = 60.0
        let parts = try XCTUnwrap(MockupRenderer.wrapParts(doc, dpi: dpi))
        let trim = doc.paperback.trimWidth * dpi
        let spine = doc.paperback.spineWidth * dpi
        XCTAssertEqual(Double(parts.front.width), trim, accuracy: 2)
        XCTAssertEqual(Double(parts.back.width), trim, accuracy: 2)
        XCTAssertEqual(Double(parts.spine.width), spine, accuracy: 2)
        XCTAssertLessThanOrEqual(abs(parts.front.width - parts.back.width), 2)
        // Trim height only: the bleed is cut away.
        let h = doc.paperback.trimHeight * dpi
        XCTAssertEqual(Double(parts.front.height), h, accuracy: 2)
        XCTAssertEqual(Double(parts.spine.height), h, accuracy: 2)
        XCTAssertEqual(Double(parts.back.height), h, accuracy: 2)
    }

    func testPhysicalMockupsRenderWithContent() throws {
        let doc = sample()
        let size = CGSize(width: 300, height: 300)
        let renders: [(String, CGImage?)] = [
            ("front", MockupRenderer.physicalFront(doc, size: size)),
            ("back", MockupRenderer.physicalBack(doc, size: size)),
            ("flat", MockupRenderer.physicalFlat(doc, size: size)),
            ("stack", MockupRenderer.physicalStack(doc, size: size))
        ]
        for (name, img) in renders {
            let i = try XCTUnwrap(img, name)
            XCTAssertEqual(i.width, 300, name)
            XCTAssertEqual(i.height, 300, name)
            XCTAssertGreaterThan(spread(i), 40, "\(name) rendered as a flat color")
        }
    }

    func testMockupKindListsAndRendersThePhysicalCases() {
        let kinds: [MockupKind] = [.physicalFront, .physicalBack, .physicalFlat, .physicalStack]
        for k in kinds {
            XCTAssertTrue(MockupKind.allCases.contains(k), k.rawValue)
            XCTAssertFalse(k.label.isEmpty, k.rawValue)
            XCTAssertFalse(k.needsAlpha, k.rawValue)
        }
        XCTAssertEqual(MockupKind.physicalFront.label, "Paperback, front")
        XCTAssertEqual(MockupKind.physicalBack.label, "Paperback, back")
        XCTAssertEqual(MockupKind.physicalFlat.label, "Cover wrap, flat")
        XCTAssertEqual(MockupKind.physicalStack.label, "Stack of three")
        // One full-size render through the router, to prove the switch handles the new cases.
        var doc = sample()
        doc.paperback.pageCount = 120
        let img = MockupRenderer.render(.physicalFront, doc: doc)
        XCTAssertEqual(img?.width, Int(MockupKind.physicalFront.pixelSize.width))
        XCTAssertEqual(img?.height, Int(MockupKind.physicalFront.pixelSize.height))
    }

    func testThickerBooksShowAWiderSpine() throws {
        var thin = sample(); thin.paperback.pageCount = 100
        var thick = sample(); thick.paperback.pageCount = 700
        let a = try XCTUnwrap(MockupRenderer.wrapParts(thin, dpi: 60))
        let b = try XCTUnwrap(MockupRenderer.wrapParts(thick, dpi: 60))
        XCTAssertGreaterThan(b.spine.width, a.spine.width * 4)
        XCTAssertEqual(a.front.width, b.front.width)
    }
}
