import CoreGraphics
import Foundation
import XCTest
@testable import Colophon

final class CriticTests: XCTestCase {
    private func cover(ground: RGBA, title: RGBA) -> CoverDocument {
        var d = CoverDocument()
        d.book = BookInfo(title: "The Salt Orchard", subtitle: "A Novel", author: "Ines Valcourt", tagline: "Some debts are paid in water.", genre: .literary)
        d.palette = [RGBA(hex: "121212"), RGBA(hex: "E8562A"), RGBA(hex: "F1EBDD")]
        d.background = ground
        d.layers = [Layer.fill(.solid, colors: [ground], frame: .full),
                    Layer.text("The Salt\nOrchard", role: .title, frame: NRect(0.08, 0.12, 0.84, 0.4), font: "PlayfairDisplay-Black", color: title),
                    Layer.text("Ines Valcourt", role: .author, frame: NRect(0.15, 0.85, 0.7, 0.04), font: "Montserrat-Black", color: title)]
        return d
    }

    func testCleanCoverScoresHigh() {
        let r = Critic.review(cover(ground: RGBA(hex: "F1EBDD"), title: RGBA(hex: "121212")))
        XCTAssertGreaterThanOrEqual(r.score, 90, r.issues.map(\.message).joined(separator: "; "))
        XCTAssertFalse(r.issues.contains { $0.kind == .legibility })
    }

    func testLowContrastIsCaughtAndRepaired() {
        var d = cover(ground: RGBA(hex: "D9D4C7"), title: RGBA(hex: "E6E0D2"))
        let before = Critic.review(d)
        XCTAssertTrue(before.issues.contains { $0.kind == .legibility && $0.layerID == d.layers[1].id })
        XCTAssertLessThan(before.score, 70)
        let after = Critic.repair(&d)
        XCTAssertGreaterThan(after.score, before.score + 20)
        let title = d.textLayer(role: .title)!.textContent!
        XCTAssertGreaterThanOrEqual(title.color.contrast(with: RGBA(hex: "D9D4C7")), 3)
    }

    func testCollisionsAndTrimAreFixedByMovingSupportingType() {
        var d = cover(ground: RGBA(hex: "F1EBDD"), title: RGBA(hex: "121212"))
        // The author runs into the title and the tagline hangs off the bottom edge.
        d.layers[2].frame = NRect(0.1, 0.3, 0.8, 0.05)
        d.layers.append(Layer.text("Some debts are paid in water.", role: .tagline, frame: NRect(0.1, 0.985, 0.8, 0.03), font: "Montserrat-Black", color: RGBA(hex: "121212")))
        let before = Critic.review(d)
        XCTAssertTrue(before.issues.contains { $0.kind == .collision })
        XCTAssertTrue(before.issues.contains { $0.kind == .margin })
        let after = Critic.repair(&d)
        XCTAssertFalse(after.issues.contains { $0.kind == .collision }, after.issues.map(\.message).joined(separator: "; "))
        XCTAssertLessThanOrEqual(d.layers.last!.frame.maxY, 1 - Critic.safeInset + 0.001)
        XCTAssertEqual(d.textLayer(role: .title)!.frame, NRect(0.08, 0.12, 0.84, 0.4), "the title stays put")
    }

    func testTinyTitleIsFlagged() {
        var d = cover(ground: RGBA(hex: "F1EBDD"), title: RGBA(hex: "121212"))
        d.layers[1].frame = NRect(0.3, 0.45, 0.4, 0.04)
        let r = Critic.review(d)
        XCTAssertTrue(r.issues.contains { $0.kind == .prominence })
    }

    func testBusyGroundGetsABackingWhenColorsCannotSaveIt() {
        var d = cover(ground: RGBA(hex: "808080"), title: RGBA(hex: "7A7A7A"))
        // Mid-gray noise behind mid-gray type: no palette color reaches 3:1 comfortably against a busy ground.
        d.layers[0] = Layer.fill(.starfield, colors: [RGBA(hex: "6E6E6E"), RGBA(hex: "9A9A9A"), RGBA(hex: "8C8C8C")], frame: .full, seed: 3, intensity: 0.9)
        d.palette = [RGBA(hex: "6E6E6E"), RGBA(hex: "9A9A9A"), RGBA(hex: "8C8C8C")]
        _ = Critic.repair(&d)
        let title = d.textLayer(role: .title)!
        let bg = Polisher.backgroundSample(d)!
        let stats = PixelSampler.stats(bg, region: title.frame)
        XCTAssertGreaterThanOrEqual(title.textContent!.color.contrast(with: stats.mean) + (title.shadow != nil ? 1.5 : 0), 3, "title ends up legible one way or another")
    }

    func testBestPicksTheHigherScore() {
        let good = cover(ground: RGBA(hex: "F1EBDD"), title: RGBA(hex: "121212"))
        let bad = cover(ground: RGBA(hex: "D9D4C7"), title: RGBA(hex: "E6E0D2"))
        let w = Critic.best([bad, good])!
        XCTAssertEqual(w.0.layers[1].textContent?.color, RGBA(hex: "121212"))
    }

    func testRandomizerReturnsRepairedCovers() {
        var base = CoverDocument()
        base.book = BookInfo(title: "The Long Quiet", author: "Ada Merrow", genre: .thriller)
        for s in 1...4 {
            let out = SmartRandomizer.randomize(base, options: .init(), recent: [], seed: s)
            let r = Critic.review(out)
            XCTAssertGreaterThanOrEqual(r.score, 60, "seed \(s): " + r.issues.map(\.message).joined(separator: "; "))
        }
    }

    func testSignatureDesignsPassTheCritic() {
        var weakOnes: [String] = []
        for d in SignatureLibrary.all {
            let doc = SignatureLibrary.build(d, palette: 0, base: SignatureLibrary.sampleDocument(d))
            let r = Critic.review(doc)
            if r.score < 60 {
                let notes = r.issues.prefix(2).map { $0.message }.joined(separator: " | ")
                weakOnes.append(d.id + " " + String(Int(r.score)) + ": " + notes)
            }
        }
        XCTAssertTrue(weakOnes.isEmpty, weakOnes.joined(separator: "\n"))
    }
}
